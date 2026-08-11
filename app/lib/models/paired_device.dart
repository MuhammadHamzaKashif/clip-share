class PairedDevice {
  const PairedDevice({
    required this.deviceId,
    required this.name,
    required this.publicKey,
    required this.keyHash,
    required this.pairedAt,
  });

  final String deviceId;
  final String name;
  final String publicKey;
  final String keyHash;
  final DateTime pairedAt;

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'name': name,
        'publicKey': publicKey,
        'keyHash': keyHash,
        'pairedAt': pairedAt.toIso8601String(),
      };

  factory PairedDevice.fromJson(Map<String, dynamic> json) => PairedDevice(
        deviceId: json['deviceId'] as String,
        name: json['name'] as String,
        publicKey: json['publicKey'] as String,
        keyHash: json['keyHash'] as String,
        pairedAt: DateTime.parse(json['pairedAt'] as String),
      );
}
