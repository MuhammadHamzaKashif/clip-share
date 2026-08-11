import 'dart:io';

import 'package:clipshare/models/settings.dart';
import 'package:clipshare/platform/config_store.dart';
import 'package:clipshare/platform/settings_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;
  late ConfigStore store;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('clipshare-settings');
    store = ConfigStore(tmp);
  });

  tearDown(() {
    tmp.deleteSync(recursive: true);
  });

  test('defaults when nothing saved yet', () async {
    final settings = await SettingsService(store).load();
    expect(settings.deviceName, Settings.defaults.deviceName);
    expect(settings.autoConnect, false);
    expect(settings.applyOnReceive, true);
    expect(settings.historySize, 50);
    expect(settings.startAtLogin, false);
  });

  test('saves and reloads settings', () async {
    final service = SettingsService(store);
    await service.save(const Settings(
      deviceName: 'my laptop',
      autoConnect: true,
      applyOnReceive: false,
      historySize: 100,
      startAtLogin: true,
    ));
    final loaded = await service.load();
    expect(loaded.deviceName, 'my laptop');
    expect(loaded.autoConnect, true);
    expect(loaded.applyOnReceive, false);
    expect(loaded.historySize, 100);
    expect(loaded.startAtLogin, true);
  });

  test('copyWith keeps other fields', () {
    const s = Settings.defaults;
    final changed = s.copyWith(historySize: 25);
    expect(changed.historySize, 25);
    expect(changed.deviceName, s.deviceName);
    expect(changed.autoConnect, s.autoConnect);
  });
}
