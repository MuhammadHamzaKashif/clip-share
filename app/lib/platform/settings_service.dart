import '../models/settings.dart';
import 'config_store.dart';

class SettingsService {
  SettingsService(this.store);

  static const _file = 'settings';

  final ConfigStore store;

  Future<Settings> load() async {
    return Settings.fromJson(await store.read(_file));
  }

  Future<void> save(Settings settings) async {
    await store.write(_file, settings.toJson());
  }
}
