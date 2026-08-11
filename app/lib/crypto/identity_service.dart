import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import '../platform/config_store.dart';

class Identity {
  const Identity({
    required this.deviceId,
    required this.privateKey,
    required this.publicKey,
  });

  final String deviceId;
  final String privateKey;
  final String publicKey;

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'privateKey': privateKey,
        'publicKey': publicKey,
      };

  factory Identity.fromJson(Map<String, dynamic> json) => Identity(
        deviceId: json['deviceId'] as String,
        privateKey: json['privateKey'] as String,
        publicKey: json['publicKey'] as String,
      );
}

class IdentityService {
  IdentityService(this.store);

  static const _file = 'identity';

  final ConfigStore store;

  Future<Identity> loadOrCreate() async {
    final data = await store.read(_file);
    if (data['deviceId'] != null) {
      return Identity.fromJson(data);
    }
    final identity = _generate();
    await store.write(_file, identity.toJson());
    return identity;
  }

  Identity _generate() {
    final random = _secureRandom();
    final keypair = _newKeypair(random);
    final rand = Random.secure();
    return Identity(
      deviceId: _hex(_randomBytes(rand, 16)),
      privateKey: base64Encode(keypair.$1),
      publicKey: base64Encode(keypair.$2),
    );
  }

  (Uint8List, Uint8List) _newKeypair(SecureRandom random) {
    final domain = ECDomainParameters('secp256r1');
    final gen = ECKeyGenerator()
      ..init(ParametersWithRandom(ECKeyGeneratorParameters(domain), random));
    final pair = gen.generateKeyPair();
    return (_bigIntToBytes(pair.privateKey.d!, 32), pair.publicKey.Q!.getEncoded(false));
  }

  SecureRandom _secureRandom() {
    final rand = Random.secure();
    return FortunaRandom()
      ..seed(KeyParameter(Uint8List.fromList(_randomBytes(rand, 32))));
  }

  Uint8List _randomBytes(Random rand, int n) =>
      Uint8List.fromList(List.generate(n, (_) => rand.nextInt(256)));

  String _hex(Uint8List bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  Uint8List _bigIntToBytes(BigInt value, int length) {
    final hex = value.toRadixString(16).padLeft(length * 2, '0');
    return Uint8List.fromList(List.generate(
        length, (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16)));
  }
}
