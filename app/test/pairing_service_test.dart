import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:clipshare/crypto/identity_service.dart';
import 'package:clipshare/pairing/pairing_service.dart';
import 'package:clipshare/platform/config_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;
  late PairingService alice;
  late PairingService bob;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('clipshare-pairing');
    final aliceIdentity = await IdentityService(ConfigStore(tmp)).loadOrCreate();
    final bobDir = Directory.systemTemp.createTempSync('clipshare-pairing-bob');
    final bobIdentity = await IdentityService(ConfigStore(bobDir)).loadOrCreate();
    bobDir.deleteSync(recursive: true);
    alice = PairingService(aliceIdentity);
    bob = PairingService(bobIdentity);
  });

  tearDown(() {
    tmp.deleteSync(recursive: true);
  });

  group('codes', () {
    test('generates 6 chars from the safe alphabet', () {
      final code = PairingService.generateCode(Random(1));
      expect(code, hasLength(6));
      for (final ch in code.split('')) {
        expect(kPairCodeAlphabet.contains(ch), isTrue,
            reason: 'char $ch not in alphabet');
      }
    });

    test('generates distinct codes', () {
      final codes = List.generate(20, (_) => PairingService.generateCode());
      expect(codes.toSet().length, greaterThan(10));
    });

    test('validates codes', () {
      expect(PairingService.isValidCode('ABCDEF'), isTrue);
      expect(PairingService.isValidCode('ABCDE'), isFalse);
      expect(PairingService.isValidCode('ABODE1'), isFalse);
      expect(PairingService.isValidCode('ABODEf'), isFalse);
    });
  });

  group('key derivation', () {
    test('both sides derive the same pair key', () {
      final code = 'K7M2XQ';
      final aliceKey = alice.derivePairKey(
        myPrivateKey: alice.identity.privateKey,
        peerPublicKey: bob.identity.publicKey,
        code: code,
      );
      final bobKey = bob.derivePairKey(
        myPrivateKey: bob.identity.privateKey,
        peerPublicKey: alice.identity.publicKey,
        code: code,
      );
      expect(base64Encode(aliceKey), base64Encode(bobKey));
      expect(aliceKey, hasLength(32));
    });

    test('wrong code gives a different key', () {
      final keyA = alice.derivePairKey(
        myPrivateKey: alice.identity.privateKey,
        peerPublicKey: bob.identity.publicKey,
        code: 'AAAAAA',
      );
      final keyB = alice.derivePairKey(
        myPrivateKey: alice.identity.privateKey,
        peerPublicKey: bob.identity.publicKey,
        code: 'BBBBBB',
      );
      expect(base64Encode(keyA), isNot(base64Encode(keyB)));
    });

    test('proof verifies only for the matching pair key', () {
      final key = alice.derivePairKey(
        myPrivateKey: alice.identity.privateKey,
        peerPublicKey: bob.identity.publicKey,
        code: 'K7M2XQ',
      );
      final proof = bob.proofOf(key);
      expect(alice.verifyProof(key, proof), isTrue);
      final other = alice.derivePairKey(
        myPrivateKey: alice.identity.privateKey,
        peerPublicKey: bob.identity.publicKey,
        code: 'WRONGX',
      );
      expect(alice.verifyProof(other, proof), isFalse);
    });
  });

  group('fingerprint', () {
    test('is stable and formatted', () {
      final fp = alice.fingerprint(alice.identity.publicKey);
      expect(fp, hasLength(8 * 5 - 1));
      expect(fp, matches(RegExp(r'^[0-9A-F]{4}( [0-9A-F]{4}){7}$')));
      expect(alice.fingerprint(alice.identity.publicKey), fp);
    });

    test('differs between devices', () {
      expect(
        alice.fingerprint(alice.identity.publicKey),
        isNot(bob.fingerprint(bob.identity.publicKey)),
      );
    });
  });
}
