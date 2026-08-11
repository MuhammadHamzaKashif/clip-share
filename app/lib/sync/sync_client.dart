import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../crypto/identity_service.dart';
import '../models/paired_device.dart';
import '../pairing/pairing_service.dart';
import '../platform/trust_store.dart';
import 'sync_messages.dart';

class SyncClient {
  SyncClient({
    required this.identity,
    required this.deviceName,
    required this.trustStore,
    required this.pairingService,
    this.onConnected,
    this.onClosed,
    this.onClipboardUpdate,
    this.onPairRejected,
  });

  final Identity identity;
  final String deviceName;
  final TrustStore trustStore;
  final PairingService pairingService;
  final void Function(String deviceId, String name)? onConnected;
  final void Function(String deviceId)? onClosed;
  final Future<void> Function(Map<String, dynamic> item)? onClipboardUpdate;
  final void Function(String reason)? onPairRejected;

  WebSocket? _ws;
  SessionCrypto? _crypto;
  String? _peerId;
  String? _peerName;
  Uint8List? _pairKey;
  final Set<String> _seenItems = {};
  bool _open = false;
  Completer<void>? _helloWaiter;
  Completer<void>? _pairWaiter;
  String? _pairError;

  bool get isOpen => _open;
  String? get peerId => _peerId;
  String? get peerName => _peerName;

  Future<void> connect(String host, int port, {String? pairingCode}) async {
    if (pairingCode != null) {
      await _pair(host, port, pairingCode);
      return;
    }
    final keyResponse = await _fetchKey(host, port);
    final peerPublicKey = keyResponse['publicKey'] as String;
    final known = await trustStore.findByKeyHash(
        sha256.convert(base64Decode(peerPublicKey)).toString());
    if (known == null) {
      throw StateError('not paired with $host');
    }
    await _openWs(host, port);
    if (_ws == null || _ws!.readyState != WebSocket.open) {
      throw const SocketException('connection closed during handshake');
    }
    _helloWaiter = Completer<void>();
    _crypto = SessionCrypto(pairingService.deriveSessionKey(
      myPrivateKey: identity.privateKey,
      peerPublicKey: peerPublicKey,
    ));
    await _send(_crypto!.seal('hello', identity.deviceId, {'name': deviceName}));
    await _helloWaiter!.future.timeout(const Duration(seconds: 10));
  }

  Future<Map<String, dynamic>> _fetchKey(String host, int port) async {
    final request = await HttpClient().getUrl(Uri.parse('http://$host:$port/key'));
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != 200) {
      throw const SocketException('key endpoint unavailable');
    }
    return jsonDecode(body) as Map<String, dynamic>;
  }

  Future<void> _pair(String host, int port, String code) async {
    final keyResponse = await _fetchKey(host, port);
    final peerPublicKey = keyResponse['publicKey'] as String;
    _pairKey = pairingService.derivePairKey(
      myPrivateKey: identity.privateKey,
      peerPublicKey: peerPublicKey,
      code: code,
    );
    await _openWs(host, port);
    if (_ws == null || _ws!.readyState != WebSocket.open) {
      throw const SocketException('connection closed during handshake');
    }
    _pairWaiter = Completer<void>();
    await _send(WireMessage(
      type: 'pair_request',
      deviceId: identity.deviceId,
      clear: {
        'name': deviceName,
        'publicKey': identity.publicKey,
        'keyHash': sha256.convert(base64Decode(identity.publicKey)).toString(),
        'proof': base64Encode(pairingService.proofOf(_pairKey!)),
      },
    ));
    await _pairWaiter!.future.timeout(const Duration(seconds: 10));
    if (_pairError != null) {
      throw StateError(_pairError!);
    }
    final helloWaiter = _helloWaiter;
    if (helloWaiter != null) {
      await helloWaiter.future.timeout(const Duration(seconds: 10));
    }
  }

  Future<void> _openWs(String host, int port) async {
    final ws = await WebSocket.connect('ws://$host:$port');
    _ws = ws;
    ws.listen(
      (data) => _onData(data),
      onDone: () => _onDone(),
      onError: (_) => _onDone(),
    );
  }

  Future<void> _onData(dynamic data) async {
    WireMessage message;
    try {
      message = WireMessage.fromJson(
          jsonDecode(data as String) as Map<String, dynamic>);
    } catch (_) {
      return;
    }
    switch (message.type) {
      case 'pair_confirm':
        await _onPairConfirm(message);
        break;
      case 'pair_reject':
        _pairError = message.clear?['reason'] as String? ?? 'rejected';
        _pairWaiter?.complete();
        onPairRejected?.call(_pairError!);
        await _ws?.close();
        break;
      case 'hello':
        await _onHello(message);
        break;
      case 'clipboard_update':
        await _onClipboardUpdate(message);
        break;
    }
  }

  Future<void> _onPairConfirm(WireMessage message) async {
    final data = message.clear;
    final pairKey = _pairKey;
    if (data == null || pairKey == null) return;
    final peerPublicKey = data['publicKey'] as String?;
    final proof = data['proof'] as String?;
    if (peerPublicKey == null || proof == null) return;
    if (!pairingService.verifyProof(pairKey, base64Decode(proof))) {
      _pairError = 'bad_confirm_proof';
      _pairWaiter?.complete();
      await _ws?.close();
      return;
    }
    await trustStore.add(PairedDevice(
      deviceId: message.deviceId,
      name: (data['name'] as String?) ?? message.deviceId,
      publicKey: peerPublicKey,
      keyHash: sha256.convert(base64Decode(peerPublicKey)).toString(),
      pairedAt: DateTime.now(),
    ));
    _crypto = SessionCrypto(pairingService.deriveSessionKey(
      myPrivateKey: identity.privateKey,
      peerPublicKey: peerPublicKey,
    ));
    _pairWaiter?.complete();
    _helloWaiter = Completer<void>();
    await _send(_crypto!.seal('hello', identity.deviceId, {'name': deviceName}));
    await _helloWaiter!.future.timeout(const Duration(seconds: 10));
  }

  Future<void> _onHello(WireMessage message) async {
    final crypto = _crypto;
    if (crypto == null) return;
    Map<String, dynamic>? payload;
    try {
      payload = crypto.open(message);
    } catch (_) {
      return;
    }
    _peerId = message.deviceId;
    _peerName = payload['name'] as String? ?? message.deviceId;
    _open = true;
    _helloWaiter?.complete();
    onConnected?.call(_peerId!, _peerName!);
  }

  Future<void> _onClipboardUpdate(WireMessage message) async {
    final crypto = _crypto;
    if (crypto == null) return;
    Map<String, dynamic> item;
    try {
      item = crypto.open(message);
    } catch (_) {
      return;
    }
    final itemId = item['itemId'] as String?;
    if (itemId == null || !_seenItems.add(itemId)) return;
    if (_seenItems.length > 500) {
      _seenItems.remove(_seenItems.first);
    }
    await _send(crypto.seal('clipboard_ack', identity.deviceId, {'itemId': itemId}));
    await onClipboardUpdate?.call(item);
  }

  void _onDone() {
    final wasOpen = _open;
    _open = false;
    final peerId = _peerId;
    _peerId = null;
    final waiter = _helloWaiter;
    _helloWaiter = null;
    if (waiter != null && !waiter.isCompleted) {
      waiter.completeError(const SocketException('peer closed'));
    }
    if (wasOpen && peerId != null) {
      onClosed?.call(peerId);
    }
  }

  Future<void> sendClipboardUpdate(Map<String, dynamic> item) async {
    final crypto = _crypto;
    if (!_open || crypto == null) return;
    final itemId = item['itemId'] as String?;
    if (itemId == null || !_seenItems.add(itemId)) return;
    if (_seenItems.length > 500) {
      _seenItems.remove(_seenItems.first);
    }
    await _send(crypto.seal('clipboard_update', identity.deviceId, item));
  }

  Future<void> _send(WireMessage message) async {
    final ws = _ws;
    if (ws != null && ws.readyState == WebSocket.open) {
      ws.add(jsonEncode(message.toJson()));
    }
  }

  Future<void> close() async {
    final ws = _ws;
    if (ws != null && ws.readyState == WebSocket.open) {
      await ws.close();
    }
  }
}
