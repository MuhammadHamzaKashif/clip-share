import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../crypto/identity_service.dart';
import '../discovery/discovery_service.dart';
import '../models/app_constants.dart';
import '../models/clipboard_item.dart';
import '../models/settings.dart';
import '../pairing/pairing_service.dart';
import '../platform/clipboard_watcher.dart';
import '../platform/trust_store.dart';
import 'sync_client.dart';
import 'sync_server.dart';

class SyncEngine {
  SyncEngine({
    required this.identity,
    required this.settings,
    required this.trustStore,
    required this.pairingService,
    required this.discovery,
    ClipboardWatcher? clipboard,
  }) : clipboard = clipboard ?? ClipboardWatcher();

  final Identity identity;
  Settings settings;
  final TrustStore trustStore;
  final PairingService pairingService;
  final DiscoveryService discovery;
  final ClipboardWatcher clipboard;

  late final SyncServer _server = SyncServer(
    identity: identity,
    deviceName: settings.deviceName,
    trustStore: trustStore,
    pairingService: pairingService,
    onPeerConnected: (session) => _onPeerConnected(session),
    onPeerDisconnected: (id) => _onPeerDisconnected(id),
    onClipboardUpdate: (session, item) => _onIncomingItem(session.deviceId, item),
  );

  final Map<String, SyncClient> _clients = {};
  final Map<String, String> _connectedNames = {};
  final List<ClipboardItem> _history = [];
  final Set<String> _seenItems = {};

  final StreamController<List<ClipboardItem>> _historyController =
      StreamController.broadcast();
  final StreamController<Set<String>> _peersController =
      StreamController.broadcast();
  final StreamController<bool> _stateController = StreamController.broadcast();
  final StreamController<String> _pairingController =
      StreamController.broadcast();

  bool _syncing = false;
  bool _running = false;
  String? _pairingCode;

  List<ClipboardItem> get history => List.unmodifiable(_history);
  Set<String> get connectedPeerIds => _clients.keys.toSet();
  bool get syncing => _syncing;
  String? get pairingCode => _pairingCode;

  Stream<List<ClipboardItem>> get historyStream => _historyController.stream;
  Stream<Set<String>> get peersStream => _peersController.stream;
  Stream<bool> get stateStream => _stateController.stream;
  Stream<String> get pairingEvents => _pairingController.stream;

  Future<void> start() async {
    if (_running) return;
    _running = true;
    await _server.start(port: kClipsharePort);
    await clipboard.start();
    clipboard.changes.listen(_onLocalClipboardChange);
    _emitState();
  }

  Future<void> beginPairing() async {
    _pairingCode = PairingService.generateCode();
    await _server.start(port: kClipsharePort, pairingCode: _pairingCode);
    _emitState();
  }

  Future<void> cancelPairing() async {
    _pairingCode = null;
    await _server.start(port: kClipsharePort);
  }

  Future<void> setPairingCode(String? code) async {
    _pairingCode = code;
    if (_running) {
      await _server.start(port: kClipsharePort, pairingCode: code);
    }
  }

  Future<void> pairWith(DiscoveredDevice device, String code) async {
    late final SyncClient client;
    client = SyncClient(
      identity: identity,
      deviceName: settings.deviceName,
      trustStore: trustStore,
      pairingService: pairingService,
      onConnected: (id, name) => _onPeerConnectedName(id, name),
      onClosed: (id) => _onPeerClosed(id),
      onClipboardUpdate: (item) => _onIncomingItem(client.peerId ?? device.id, item),
    );
    await client.connect(device.address.address, device.port, pairingCode: code);
    if (_syncing) {
      _clients[client.peerId!] = client;
    }
  }

  Future<void> startSync() async {
    if (_syncing) return;
    _syncing = true;
    _emitState();
    final peers = await trustStore.all();
    for (final device in peers) {
      final discovered = discovery.devices
          .where((d) => d.keyHash.isNotEmpty && d.keyHash == device.keyHash);
      for (final target in discovered) {
        await connectTo(target);
      }
    }
  }

  Future<void> connectTo(DiscoveredDevice device) async {
    if (_clients.containsKey(device.id)) return;
    final known = await trustStore.findByKeyHash(device.keyHash);
    if (known == null) return;
    final client = SyncClient(
      identity: identity,
      deviceName: settings.deviceName,
      trustStore: trustStore,
      pairingService: pairingService,
      onConnected: (id, name) => _onPeerConnectedName(id, name),
      onClosed: (id) => _onPeerClosed(id),
      onClipboardUpdate: (item) => _onIncomingItem(device.id, item),
    );
    try {
      await client.connect(device.address.address, device.port);
      _clients[client.peerId!] = client;
    } catch (_) {
      await client.close();
    }
  }

  Future<void> stopSync() async {
    _syncing = false;
    for (final client in _clients.values) {
      await client.close();
    }
    _clients.clear();
    _connectedNames.clear();
    _emitPeers();
    _emitState();
  }

  void _onLocalClipboardChange(String text) {
    if (text.isEmpty) return;
    final itemId = sha256.convert(utf8.encode(text)).toString();
    if (!_seenItems.add(itemId)) return;
    if (_seenItems.length > 500) {
      _seenItems.remove(_seenItems.first);
    }
    final item = ClipboardItem(
      itemId: itemId,
      kind: ItemKind.text,
      text: text,
      source: 'this device',
      timestamp: DateTime.now(),
    );
    _addToHistory(item);
    final wireItem = {
      'itemId': itemId,
      'kind': 'text',
      'payload': text,
      'ts': item.timestamp.millisecondsSinceEpoch,
    };
    for (final client in _clients.values) {
      client.sendClipboardUpdate(wireItem);
    }
  }

  Future<void> _onIncomingItem(String fromDeviceId, Map<String, dynamic> item) async {
    final itemId = item['itemId'] as String?;
    if (itemId == null || !_seenItems.add(itemId)) return;
    if (_seenItems.length > 500) {
      _seenItems.remove(_seenItems.first);
    }
    final payload = item['payload'] as String? ?? '';
    final ts = DateTime.fromMillisecondsSinceEpoch(item['ts'] as int? ?? 0);
    _addToHistory(ClipboardItem(
      itemId: itemId,
      kind: ItemKind.text,
      text: payload,
      source: _connectedNames[fromDeviceId] ?? fromDeviceId,
      timestamp: ts,
    ));
    if (settings.applyOnReceive) {
      await clipboard.setText(payload);
    }
  }

  void _addToHistory(ClipboardItem item) {
    _history.insert(0, item);
    final limit = settings.historySize;
    if (limit > 0 && _history.length > limit) {
      _history.removeRange(limit, _history.length);
    }
    if (!_historyController.isClosed) {
      _historyController.add(List.unmodifiable(_history));
    }
  }

  void _onPeerConnected(PeerSession session) {
    _onPeerConnectedName(session.deviceId, session.name);
    if (_pairingCode != null) {
      _pairingCode = null;
      if (!_pairingController.isClosed) {
        _pairingController.add(session.deviceId);
      }
      _server.start(port: kClipsharePort);
    }
  }

  void _onPeerConnectedName(String id, String name) {
    _connectedNames[id] = name;
    _emitPeers();
  }

  void _onPeerDisconnected(String id) {
    _onPeerClosed(id);
  }

  void _onPeerClosed(String id) {
    _clients.remove(id);
    _connectedNames.remove(id);
    _emitPeers();
  }

  void _emitPeers() {
    if (!_peersController.isClosed) {
      _peersController.add(Set.unmodifiable(_connectedNames.keys));
    }
  }

  void _emitState() {
    if (!_stateController.isClosed) {
      _stateController.add(_syncing);
    }
  }

  Future<void> dispose() async {
    await stopSync();
    _running = false;
    await _server.stop();
    await clipboard.dispose();
    await _historyController.close();
    await _peersController.close();
    await _stateController.close();
    await _pairingController.close();
  }
}
