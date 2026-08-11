import 'dart:typed_data';

import 'package:pointycastle/export.dart';

Uint8List hkdfSha256(
  List<int> ikm,
  int length, {
  List<int>? salt,
  List<int>? info,
}) {
  final derivator = HKDFKeyDerivator(SHA256Digest())
    ..init(HkdfParameters(
      Uint8List.fromList(ikm),
      length,
      salt == null ? null : Uint8List.fromList(salt),
      info == null ? null : Uint8List.fromList(info),
    ));
  final out = Uint8List(length);
  derivator.deriveKey(null, 0, out, 0);
  return out;
}

Uint8List hmacSha256(List<int> key, List<int> message) {
  final mac = HMac(SHA256Digest(), 64)..init(KeyParameter(Uint8List.fromList(key)));
  final out = Uint8List(mac.macSize);
  mac.update(Uint8List.fromList(message), 0, message.length);
  mac.doFinal(out, 0);
  return out;
}

Uint8List aesGcmSeal(
  List<int> key,
  List<int> nonce,
  List<int> plaintext, {
  List<int>? aad,
}) {
  final cipher = GCMBlockCipher(AESEngine());
  cipher.init(
    true,
    AEADParameters(
      KeyParameter(Uint8List.fromList(key)),
      128,
      Uint8List.fromList(nonce),
      aad == null ? Uint8List(0) : Uint8List.fromList(aad),
    ),
  );
  final out = Uint8List(cipher.getOutputSize(plaintext.length));
  final n = cipher.processBytes(Uint8List.fromList(plaintext), 0, plaintext.length, out, 0);
  cipher.doFinal(out, n);
  return out;
}

Uint8List aesGcmOpen(
  List<int> key,
  List<int> nonce,
  List<int> sealed, {
  List<int>? aad,
}) {
  final cipher = GCMBlockCipher(AESEngine());
  cipher.init(
    false,
    AEADParameters(
      KeyParameter(Uint8List.fromList(key)),
      128,
      Uint8List.fromList(nonce),
      aad == null ? Uint8List(0) : Uint8List.fromList(aad),
    ),
  );
  final out = Uint8List(cipher.getOutputSize(sealed.length));
  final n = cipher.processBytes(Uint8List.fromList(sealed), 0, sealed.length, out, 0);
  cipher.doFinal(out, n);
  return Uint8List.sublistView(out, 0, n);
}
