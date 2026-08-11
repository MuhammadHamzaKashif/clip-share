import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import '../crypto/secure_crypto.dart';

const kProtoVersion = 1;

class WireMessage {
  const WireMessage({
    required this.type,
    required this.deviceId,
    this.nonce,
    this.ciphertext,
    this.clear,
  });

  final String type;
  final String deviceId;
  final String? nonce;
  final String? ciphertext;
  final Map<String, dynamic>? clear;

  Map<String, dynamic> toJson() => {
        'v': kProtoVersion,
        'type': type,
        'deviceId': deviceId,
        if (nonce != null) 'nonce': nonce,
        if (ciphertext != null) 'ciphertext': ciphertext,
        if (clear != null) 'data': clear,
      };

  static WireMessage fromJson(Map<String, dynamic> json) => WireMessage(
        type: json['type'] as String,
        deviceId: json['deviceId'] as String,
        nonce: json['nonce'] as String?,
        ciphertext: json['ciphertext'] as String?,
        clear: (json['data'] as Map<String, dynamic>?)?.cast<String, dynamic>(),
      );
}

class SessionCrypto {
  SessionCrypto(this.key);

  final Uint8List key;

  WireMessage seal(String type, String deviceId, Map<String, dynamic> payload) {
    final nonce = _randomNonce();
    final plaintext = utf8.encode(jsonEncode(payload));
    final sealed = aesGcmSeal(key, nonce, plaintext,
        aad: utf8.encode('$type|$deviceId'));
    return WireMessage(
      type: type,
      deviceId: deviceId,
      nonce: base64Encode(nonce),
      ciphertext: base64Encode(sealed),
    );
  }

  Map<String, dynamic> open(WireMessage message) {
    final plaintext = aesGcmOpen(
      key,
      base64Decode(message.nonce!),
      base64Decode(message.ciphertext!),
      aad: utf8.encode('${message.type}|${message.deviceId}'),
    );
    return jsonDecode(utf8.decode(plaintext)) as Map<String, dynamic>;
  }

  Uint8List _randomNonce() {
    final random = Random.secure();
    return Uint8List.fromList(List.generate(12, (_) => random.nextInt(256)));
  }
}
