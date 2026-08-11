import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../crypto/identity_service.dart';
import '../models/app_constants.dart';
import '../models/paired_device.dart';
import '../pairing/pairing_service.dart';
import '../platform/trust_store.dart';
import 'sync_messages.dart';

class PeerSession {
  PeerSession({required this.deviceId, required this.name, required this.crypto});

  final String deviceId;
  final String name;
  final SessionCrypto crypto;
}

class SyncServer {
  SyncServer({
    required this.identity,
    required this.deviceName,
    required this.trustStore,
    required this.pairingService,
    this.onPeerConnected,
    this.onPeerDisconnected,
    this.onClipboardUpdate,
  });

  final Identity identity;
  final String deviceName;
  final TrustStore trustStore;
  final PairingService pairingService;
  final void Function(PeerSession session)? onPeerConnected;
  final void Function(String deviceId)? onPeerDisconnected;
  final Future<void> Function(PeerSession session, Map<String, dynamic> item)? onClipboardUpdate;

  HttpServer? _server;
  final Map<String, _Connection> _connections = {};
  final Set<String> _seenItems = {};
  String? _pairingCode;

  int get port => _server?.port ?? 0;
  bool get running => _server != null;

  Future<void> start({int port = kClipsharePort, String? pairingCode}) async {
    _pairingCode = pairingCode;
    _server = await HttpServer.bind(InternetAddress.anyIPv4, port, shared: true);
    _server!.listen(_handleRequest);
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    for (final conn in _connections.values) {
      await conn.ws.close();
    }
    _connections.clear();
  }

  Future<void> _handleRequest(HttpRequest request) async {
    if (request.uri.path == '/key') {
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'publicKey': identity.publicKey,
        'name': deviceName,
      }));
      await request.response.close();
      return;
    }
    try {
      final ws = await WebSocketTransformer.upgrade(request);
      final conn = _Connection(ws);
      ws.listen(
        (data) => _enqueue(conn, data),
        onDone: () => _onClosed(conn),
        onError: (_) => _onClosed(conn),
      );
    } catch (_) {}
  }

  void _enqueue(_Connection conn, dynamic data) {
    conn.queue = (conn.queue ?? Future.value())
        .then((_) => _onData(conn, data))
        .catchError((_) {});
  }

  Future<void> _onData(_Connection conn, dynamic data) async {
    WireMessage message;
    try {
      message = WireMessage.fromJson(
          jsonDecode(data as String) as Map<String, dynamic>);
    } catch (_) {
      return;
    }
    switch (message.type) {
      case 'pair_request':
        await _onPairRequest(conn, message);
        break;
      case 'hello':
        await _onHello(conn, message);
        break;
      case 'clipboard_update':
        await _onClipboardUpdate(conn, message);
        break;
      case 'ping':
        await _send(conn,
            WireMessage(type: 'pong', deviceId: identity.deviceId));
        break;
    }
  }

  Future<void> _onPairRequest(_Connection conn, WireMessage message) async {
    final data = message.clear;
    final code = _pairingCode;
    if (data == null || code == null) return;
    final peerPublicKey = data['publicKey'] as String?;
    final proof = data['proof'] as String?;
    if (peerPublicKey == null || proof == null) return;
    if (await trustStore.find(message.deviceId) != null) {
      await _reject(conn, 'already_paired');
      return;
    }
    final pairKey = pairingService.derivePairKey(
      myPrivateKey: identity.privateKey,
      peerPublicKey: peerPublicKey,
      code: code,
    );
    if (!pairingService.verifyProof(pairKey, base64Decode(proof))) {
      await _reject(conn, 'bad_proof');
      return;
    }
    await _send(conn, WireMessage(
      type: 'pair_confirm',
      deviceId: identity.deviceId,
      clear: {
        'publicKey': identity.publicKey,
        'name': deviceName,
        'proof': base64Encode(pairingService.proofOf(pairKey)),
      },
    ));
    conn.crypto = SessionCrypto(pairingService.deriveSessionKey(
      myPrivateKey: identity.privateKey,
      peerPublicKey: peerPublicKey,
    ));
    conn.pendingDevice = PairedDevice(
      deviceId: message.deviceId,
      name: (data['name'] as String?) ?? message.deviceId,
      publicKey: peerPublicKey,
      keyHash: data['keyHash'] as String? ?? '',
      pairedAt: DateTime.now(),
    );
  }

  Future<void> _onHello(_Connection conn, WireMessage message) async {
    final deviceId = message.deviceId;
    final device = conn.pendingDevice ?? await trustStore.find(deviceId);
    if (device == null) {
      await conn.ws.close(4003, 'not paired');
      return;
    }
    var crypto = conn.crypto;
    crypto ??= SessionCrypto(pairingService.deriveSessionKey(
      myPrivateKey: identity.privateKey,
      peerPublicKey: device.publicKey,
    ));
    Map<String, dynamic>? payload;
    try {
      payload = crypto.open(message);
    } catch (_) {
      await conn.ws.close(4004, 'bad session');
      return;
    }
    if (conn.pendingDevice != null) {
      await trustStore.add(conn.pendingDevice!);
      conn.pendingDevice = null;
    }
    final session = PeerSession(
      deviceId: deviceId,
      name: payload['name'] as String? ?? device.name,
      crypto: crypto,
    );
    if (_connections[deviceId] != null && _connections[deviceId] != conn) {
      _connections[deviceId]!.ws.close();
    }
    _connections[deviceId] = conn;
    conn.peer = session;
    await _send(conn, crypto.seal('hello', identity.deviceId, {'name': deviceName}));
    onPeerConnected?.call(session);
  }

  Future<void> _onClipboardUpdate(_Connection conn, WireMessage message) async {
    final peer = conn.peer;
    if (peer == null) return;
    Map<String, dynamic> item;
    try {
      item = peer.crypto.open(message);
    } catch (_) {
      return;
    }
    final itemId = item['itemId'] as String?;
    if (itemId == null || !_seenItems.add(itemId)) return;
    if (_seenItems.length > 500) {
      _seenItems.remove(_seenItems.first);
    }
    await _send(conn, peer.crypto.seal('clipboard_ack', identity.deviceId, {'itemId': itemId}));
    await onClipboardUpdate?.call(peer, item);
  }

  Future<void> _onClosed(_Connection conn) async {
    final peer = conn.peer;
    if (peer != null) {
      _connections.remove(peer.deviceId);
      onPeerDisconnected?.call(peer.deviceId);
    }
  }

  Future<void> _reject(_Connection conn, String reason) async {
    await _send(conn, WireMessage(
      type: 'pair_reject',
      deviceId: identity.deviceId,
      clear: {'reason': reason},
    ));
    await conn.ws.close();
  }

  Future<void> _send(_Connection conn, WireMessage message) async {
    if (conn.ws.readyState == WebSocket.open) {
      conn.ws.add(jsonEncode(message.toJson()));
    }
  }
}

class _Connection {
  _Connection(this.ws);

  final WebSocket ws;
  SessionCrypto? crypto;
  PairedDevice? pendingDevice;
  PeerSession? peer;
  Future<void>? queue;
}
