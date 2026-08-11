import 'dart:io';

import 'package:clipshare/crypto/identity_service.dart';
import 'package:clipshare/pairing/pairing_service.dart';
import 'package:clipshare/platform/config_store.dart';
import 'package:clipshare/platform/trust_store.dart';
import 'package:clipshare/sync/sync_client.dart';
import 'package:clipshare/sync/sync_server.dart';
import 'package:flutter_test/flutter_test.dart';

class _Node {
  _Node(this.identity, this.trustStore, this.pairingService);

  final Identity identity;
  final TrustStore trustStore;
  final PairingService pairingService;
  final List<Map<String, dynamic>> received = [];
  final List<String> connected = [];

  static Future<_Node> create() async {
    final dir = Directory.systemTemp.createTempSync('clipshare-node');
    final store = ConfigStore(dir);
    final identity = await IdentityService(store).loadOrCreate();
    return _Node(identity, TrustStore(store), PairingService(identity));
  }
}

void main() {
  late _Node alice;
  late _Node bob;

  setUp(() async {
    alice = await _Node.create();
    bob = await _Node.create();
  });

  test('pairing handshake pairs both devices', () async {
    final code = 'K7M2XQ';
    final server = SyncServer(
      identity: alice.identity,
      deviceName: 'alice pc',
      trustStore: alice.trustStore,
      pairingService: alice.pairingService,
    );
    await server.start(port: 0, pairingCode: code);

    final client = SyncClient(
      identity: bob.identity,
      deviceName: 'bob phone',
      trustStore: bob.trustStore,
      pairingService: bob.pairingService,
    );
    await client.connect('127.0.0.1', server.port, pairingCode: code);

    final aliceHas = await alice.trustStore.find(bob.identity.deviceId);
    final bobHas = await bob.trustStore.find(alice.identity.deviceId);
    expect(aliceHas, isNotNull);
    expect(bobHas, isNotNull);
    expect(aliceHas!.publicKey, bob.identity.publicKey);
    expect(bobHas!.publicKey, alice.identity.publicKey);
    expect(client.isOpen, isTrue);

    await client.close();
    await server.stop();
  });

  test('wrong code is rejected', () async {
    final server = SyncServer(
      identity: alice.identity,
      deviceName: 'alice pc',
      trustStore: alice.trustStore,
      pairingService: alice.pairingService,
    );
    await server.start(port: 0, pairingCode: 'K7M2XQ');

    final client = SyncClient(
      identity: bob.identity,
      deviceName: 'bob phone',
      trustStore: bob.trustStore,
      pairingService: bob.pairingService,
    );
    await expectLater(
      client.connect('127.0.0.1', server.port, pairingCode: 'WRONGX'),
      throwsA(isA<StateError>()),
    );
    expect(await alice.trustStore.find(bob.identity.deviceId), isNull);
    expect(await bob.trustStore.find(alice.identity.deviceId), isNull);

    await server.stop();
  });

  test('clipboard updates flow encrypted with dedupe', () async {
    final code = 'K7M2XQ';
    final server = SyncServer(
      identity: alice.identity,
      deviceName: 'alice pc',
      trustStore: alice.trustStore,
      pairingService: alice.pairingService,
      onClipboardUpdate: (session, item) async {
        alice.received.add(item);
      },
    );
    await server.start(port: 0, pairingCode: code);

    final client = SyncClient(
      identity: bob.identity,
      deviceName: 'bob phone',
      trustStore: bob.trustStore,
      pairingService: bob.pairingService,
      onClipboardUpdate: (item) async {
        bob.received.add(item);
      },
    );
    await client.connect('127.0.0.1', server.port, pairingCode: code);

    final item = {
      'itemId': 'abc123',
      'kind': 'text',
      'payload': 'hello from bob',
      'ts': DateTime.now().millisecondsSinceEpoch,
    };
    await client.sendClipboardUpdate(item);
    await client.sendClipboardUpdate(item);
    await Future.delayed(const Duration(milliseconds: 300));

    expect(alice.received, hasLength(1));
    expect(alice.received.first['payload'], 'hello from bob');
    expect(bob.received, isEmpty);

    await client.close();
    await server.stop();
  });

  test('image clipboard items flow encrypted with dedupe', () async {
    final code = 'K7M2XQ';
    final server = SyncServer(
      identity: alice.identity,
      deviceName: 'alice pc',
      trustStore: alice.trustStore,
      pairingService: alice.pairingService,
      onClipboardUpdate: (session, item) async {
        alice.received.add(item);
      },
    );
    await server.start(port: 0, pairingCode: code);

    final client = SyncClient(
      identity: bob.identity,
      deviceName: 'bob phone',
      trustStore: bob.trustStore,
      pairingService: bob.pairingService,
    );
    await client.connect('127.0.0.1', server.port, pairingCode: code);

    final pngBase64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
        'AAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
    final item = {
      'itemId': 'img-1',
      'kind': 'image',
      'payload': pngBase64,
      'ts': DateTime.now().millisecondsSinceEpoch,
    };
    await client.sendClipboardUpdate(item);
    await client.sendClipboardUpdate(item);
    await Future.delayed(const Duration(milliseconds: 300));

    expect(alice.received, hasLength(1));
    expect(alice.received.first['kind'], 'image');
    expect(alice.received.first['payload'], pngBase64);

    await client.close();
    await server.stop();
  });

  test('reconnect with stored trust skips pairing', () async {
    final code = 'K7M2XQ';
    final server = SyncServer(
      identity: alice.identity,
      deviceName: 'alice pc',
      trustStore: alice.trustStore,
      pairingService: alice.pairingService,
    );
    await server.start(port: 0, pairingCode: code);

    final client = SyncClient(
      identity: bob.identity,
      deviceName: 'bob phone',
      trustStore: bob.trustStore,
      pairingService: bob.pairingService,
    );
    await client.connect('127.0.0.1', server.port, pairingCode: code);
    expect(client.isOpen, isTrue);
    await client.close();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(client.isOpen, isFalse);

    final second = SyncClient(
      identity: bob.identity,
      deviceName: 'bob phone',
      trustStore: bob.trustStore,
      pairingService: bob.pairingService,
    );
    await second.connect('127.0.0.1', server.port);
    expect(second.isOpen, isTrue);

    await second.close();
    await server.stop();
  });

  test('unpaired device cannot connect', () async {
    final server = SyncServer(
      identity: alice.identity,
      deviceName: 'alice pc',
      trustStore: alice.trustStore,
      pairingService: alice.pairingService,
    );
    await server.start(port: 0);

    final client = SyncClient(
      identity: bob.identity,
      deviceName: 'bob phone',
      trustStore: bob.trustStore,
      pairingService: bob.pairingService,
    );
    await expectLater(
      client.connect('127.0.0.1', server.port),
      throwsA(anything),
    );

    await server.stop();
  });
}
