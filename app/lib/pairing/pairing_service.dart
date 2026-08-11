import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

import '../crypto/identity_service.dart';
import '../crypto/secure_crypto.dart';

const kPairCodeAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const kPairCodeLength = 6;

class PairingService {
  PairingService(this.identity);

  final Identity identity;

  static String generateCode([Random? rng]) {
    final random = rng ?? Random.secure();
    return List.generate(
      kPairCodeLength,
      (_) => kPairCodeAlphabet[random.nextInt(kPairCodeAlphabet.length)],
    ).join();
  }

  static bool isValidCode(String code) {
    if (code.length != kPairCodeLength) return false;
    for (final ch in code.split('')) {
      if (!kPairCodeAlphabet.contains(ch)) return false;
    }
    return true;
  }

  Uint8List derivePairKey({
    required String myPrivateKey,
    required String peerPublicKey,
    required String code,
  }) {
    final shared = ecdhSecret(myPrivateKey, peerPublicKey);
    return hkdfSha256(
      shared,
      32,
      salt: utf8.encode('clipshare-pair'),
      info: utf8.encode(code),
    );
  }

  Uint8List proofOf(Uint8List pairKey) {
    return hmacSha256(pairKey, utf8.encode('clipshare-pair-proof'));
  }

  bool verifyProof(Uint8List pairKey, List<int> proof) {
    return _constantTimeEquals(proofOf(pairKey), proof);
  }

  Uint8List sessionKey(Uint8List pairKey) {
    return hkdfSha256(pairKey, 32, info: utf8.encode('clipshare-session'));
  }

  String fingerprint(String publicKey) {
    final digest = sha256.convert(base64Decode(publicKey)).toString().toUpperCase();
    final groups = <String>[];
    for (var i = 0; i < digest.length && groups.length < 8; i += 4) {
      groups.add(digest.substring(i, i + 4));
    }
    return groups.join(' ');
  }

  bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

Uint8List ecdhSecret(String myPrivateKey, String peerPublicKey) {
  final domain = ECDomainParameters('secp256r1');
  final privBytes = base64Decode(myPrivateKey);
  final d = BigInt.parse(
    privBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
    radix: 16,
  );
  final peerBytes = base64Decode(peerPublicKey);
  final peerPoint = domain.curve.decodePoint(peerBytes);
  final agreement = ECDHBasicAgreement()
    ..init(ECPrivateKey(d, domain));
  final shared = agreement.calculateAgreement(ECPublicKey(peerPoint, domain));
  return _bigIntToBytes(shared, 32);
}

Uint8List _bigIntToBytes(BigInt value, int length) {
  final hex = value.toRadixString(16).padLeft(length * 2, '0');
  return Uint8List.fromList(List.generate(
      length, (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16)));
}
