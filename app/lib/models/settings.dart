class Settings {
  const Settings({
    required this.deviceName,
    required this.autoConnect,
    required this.applyOnReceive,
    required this.historySize,
    required this.startAtLogin,
  });

  static const defaults = Settings(
    deviceName: 'this device',
    autoConnect: false,
    applyOnReceive: true,
    historySize: 50,
    startAtLogin: false,
  );

  final String deviceName;
  final bool autoConnect;
  final bool applyOnReceive;
  final int historySize;
  final bool startAtLogin;

  Settings copyWith({
    String? deviceName,
    bool? autoConnect,
    bool? applyOnReceive,
    int? historySize,
    bool? startAtLogin,
  }) {
    return Settings(
      deviceName: deviceName ?? this.deviceName,
      autoConnect: autoConnect ?? this.autoConnect,
      applyOnReceive: applyOnReceive ?? this.applyOnReceive,
      historySize: historySize ?? this.historySize,
      startAtLogin: startAtLogin ?? this.startAtLogin,
    );
  }

  Map<String, dynamic> toJson() => {
        'deviceName': deviceName,
        'autoConnect': autoConnect,
        'applyOnReceive': applyOnReceive,
        'historySize': historySize,
        'startAtLogin': startAtLogin,
      };

  factory Settings.fromJson(Map<String, dynamic> json) => Settings(
        deviceName: json['deviceName'] as String? ?? defaults.deviceName,
        autoConnect: json['autoConnect'] as bool? ?? defaults.autoConnect,
        applyOnReceive: json['applyOnReceive'] as bool? ?? defaults.applyOnReceive,
        historySize: json['historySize'] as int? ?? defaults.historySize,
        startAtLogin: json['startAtLogin'] as bool? ?? defaults.startAtLogin,
      );
}
