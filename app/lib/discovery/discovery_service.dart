import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:multicast_dns/multicast_dns.dart';

import '../models/app_constants.dart';

class DiscoveredDevice {
  const DiscoveredDevice({
    required this.id,
    required this.name,
    required this.address,
    required this.port,
    required this.keyHash,
  });

  final String id;
  final String name;
  final InternetAddress address;
  final int port;
  final String keyHash;
}

Map<String, String> parseTxt(String text) {
  final map = <String, String>{};
  for (final entry in text.split('\n')) {
    final i = entry.indexOf('=');
    if (i > 0) {
      map[entry.substring(0, i)] = entry.substring(i + 1);
    }
  }
  return map;
}

String instanceFromPtr(String domainName) {
  final idx = domainName.indexOf('.$kClipshareServiceType');
  if (idx > 0) {
    return domainName.substring(0, idx);
  }
  return domainName;
}

class MDnsAnnouncer {
  RawDatagramSocket? _socket;
  Uint8List? _packet;
  static final _group = InternetAddress('224.0.0.251');
  static const _port = 5353;

  Future<void> start({
    required String instance,
    required Map<String, String> txt,
    required int servicePort,
  }) async {
    final addr = await _lanAddress();
    _packet = _buildPacket(instance, txt, servicePort, addr);
    _socket = await _mDnsSocketFactory(
        InternetAddress.anyIPv4, _port, reuseAddress: true);
    _socket!.broadcastEnabled = true;
    await announce();
  }

  Future<void> announce() async {
    _socket?.send(_packet!, _group, _port);
  }

  Future<void> stop() async {
    _socket?.close();
  }

  Future<InternetAddress> _lanAddress() async {
    final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        if (!addr.isLoopback) {
          return addr;
        }
      }
    }
    return InternetAddress('127.0.0.1');
  }

  Uint8List _buildPacket(
      String instance, Map<String, String> txt, int servicePort, InternetAddress addr) {
    final instanceName = '$instance.$kClipshareServiceType.local';
    final serviceName = '$kClipshareServiceType.local';
    final hostName = '$instance.local';
    final records = <List<int>>[
      _record(serviceName, 12, 4500, _encodeName(instanceName)),
      _record(instanceName, 33, 120,
          _u16(0) + _u16(0) + _u16(servicePort) + _encodeName(hostName)),
      _record(instanceName, 16, 4500, _encodeTxt(txt)),
      _record(hostName, 1, 120, addr.rawAddress),
    ];
    final buf = BytesBuilder();
    buf.add(_u16(0));
    buf.add(_u16(0x8400));
    buf.add(_u16(0));
    buf.add(_u16(records.length));
    buf.add(_u16(0));
    buf.add(_u16(0));
    for (final record in records) {
      buf.add(record);
    }
    return buf.toBytes();
  }

  List<int> _record(String name, int type, int ttl, List<int> rdata) {
    return _encodeName(name) +
        _u16(type) +
        _u16(1) +
        _u32(ttl) +
        _u16(rdata.length) +
        rdata;
  }

  List<int> _encodeName(String name) {
    final bytes = <int>[];
    for (final part in name.split('.')) {
      final encoded = utf8.encode(part);
      if (encoded.isEmpty) continue;
      bytes.add(encoded.length);
      bytes.addAll(encoded);
    }
    bytes.add(0);
    return bytes;
  }

  List<int> _encodeTxt(Map<String, String> txt) {
    final bytes = <int>[];
    for (final entry in txt.entries) {
      final encoded = utf8.encode('${entry.key}=${entry.value}');
      bytes.add(encoded.length);
      bytes.addAll(encoded);
    }
    return bytes;
  }

  List<int> _u16(int v) => [(v >> 8) & 0xff, v & 0xff];

  List<int> _u32(int v) =>
      [(v >> 24) & 0xff, (v >> 16) & 0xff, (v >> 8) & 0xff, v & 0xff];
}

Future<RawDatagramSocket> _mDnsSocketFactory(
  dynamic address,
  int port, {
  bool reuseAddress = false,
  bool reusePort = false,
  int ttl = 0,
}) {
  final bindAddress =
      address is InternetAddress ? address : InternetAddress(address as String);
  return RawDatagramSocket.bind(bindAddress, port,
      reuseAddress: reuseAddress,
      reusePort: Platform.isWindows ? false : reusePort,
      ttl: ttl <= 0 ? 1 : ttl);
}

Future<Iterable<NetworkInterface>> _mDnsInterfacesFactory(
    InternetAddressType type) async {
  final interfaces = await NetworkInterface.list(
      includeLinkLocal: true, type: type, includeLoopback: true);
  final group =
      type == InternetAddressType.IPv6 ? 'FF02::FB' : '224.0.0.251';
  final usable = <NetworkInterface>[];
  for (final iface in interfaces) {
    try {
      final socket = await RawDatagramSocket.bind(
          type == InternetAddressType.IPv6
              ? InternetAddress.anyIPv6
              : InternetAddress.anyIPv4,
          0,
          ttl: 255);
      socket.joinMulticast(InternetAddress(group), iface);
      socket.close();
      usable.add(iface);
    } catch (_) {}
  }
  return usable;
}

class DiscoveryService {
  final MDnsClient _client = MDnsClient(rawDatagramSocketFactory: _mDnsSocketFactory);
  final MDnsAnnouncer _announcer = MDnsAnnouncer();
  final Map<String, DiscoveredDevice> _devices = {};
  final StreamController<List<DiscoveredDevice>> _updates =
      StreamController.broadcast();

  StreamSubscription<PtrResourceRecord>? _subscription;
  Timer? _announceTimer;
  Timer? _browseTimer;
  String? _ownId;

  List<DiscoveredDevice> get devices => List.unmodifiable(_devices.values);

  Stream<List<DiscoveredDevice>> get updates => _updates.stream;

  Future<void> start({
    required String deviceId,
    required String deviceName,
    required String publicKey,
    required int port,
  }) async {
    _ownId = deviceId;
    final ownKeyHash = sha256.convert(base64Decode(publicKey)).toString();
    await _announcer.start(
      instance: deviceId,
      txt: {'name': deviceName, 'ver': '0', 'key': ownKeyHash},
      servicePort: port,
    );
    _announceTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _announcer.announce();
    });
    await _client.start(interfacesFactory: _mDnsInterfacesFactory);
    _browse();
    _browseTimer = Timer.periodic(const Duration(seconds: 30), (_) => _browse());
  }

  void _browse() {
    _subscription?.cancel();
    _subscription = _client
        .lookup<PtrResourceRecord>(
          ResourceRecordQuery.serverPointer(kClipshareServiceType),
          timeout: const Duration(seconds: 10),
        )
        .listen(_onPtr);
  }

  Future<void> _onPtr(PtrResourceRecord ptr) async {
    final instance = instanceFromPtr(ptr.domainName);
    if (instance == _ownId) {
      return;
    }
    try {
      final fqdn = '$instance.$kClipshareServiceType.local';
      final srv = await _client
          .lookup<SrvResourceRecord>(ResourceRecordQuery.service(fqdn))
          .first;
      final txt = await _client
          .lookup<TxtResourceRecord>(ResourceRecordQuery.text(fqdn))
          .first;
      final addr = await _client
          .lookup<IPAddressResourceRecord>(
              ResourceRecordQuery.addressIPv4(srv.target))
          .first;
      final meta = parseTxt(txt.text);
      final device = DiscoveredDevice(
        id: instance,
        name: meta['name'] ?? instance,
        address: addr.address,
        port: srv.port,
        keyHash: meta['key'] ?? '',
      );
      if (_devices[instance] == null ||
          _devices[instance]!.address != device.address) {
        _devices[instance] = device;
        _emit();
      }
    } catch (_) {}
  }

  Future<void> stop() async {
    _announceTimer?.cancel();
    _browseTimer?.cancel();
    await _subscription?.cancel();
    await _announcer.stop();
    _client.stop();
  }

  void _emit() {
    if (!_updates.isClosed) {
      _updates.add(List.unmodifiable(_devices.values));
    }
  }

  Future<void> dispose() async {
    await stop();
    await _updates.close();
  }
}
