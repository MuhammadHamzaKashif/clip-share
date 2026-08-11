import '../models/paired_device.dart';
import 'config_store.dart';

class TrustStore {
  TrustStore(this.store);

  static const _file = 'devices';

  final ConfigStore store;

  Future<List<PairedDevice>> all() async {
    final data = await store.read(_file);
    final list = data['devices'] as List<dynamic>? ?? [];
    return list
        .map((e) => PairedDevice.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> add(PairedDevice device) async {
    final devices = await all();
    devices.removeWhere((d) => d.deviceId == device.deviceId);
    devices.add(device);
    await _save(devices);
  }

  Future<void> remove(String deviceId) async {
    final devices = await all();
    devices.removeWhere((d) => d.deviceId == deviceId);
    await _save(devices);
  }

  Future<PairedDevice?> find(String deviceId) async {
    for (final device in await all()) {
      if (device.deviceId == deviceId) {
        return device;
      }
    }
    return null;
  }

  Future<PairedDevice?> findByKeyHash(String keyHash) async {
    for (final device in await all()) {
      if (device.keyHash == keyHash) {
        return device;
      }
    }
    return null;
  }

  Future<void> _save(List<PairedDevice> devices) async {
    await store.write(_file, {
      'devices': devices.map((d) => d.toJson()).toList(),
    });
  }
}
