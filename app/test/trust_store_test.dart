import 'dart:io';

import 'package:clipshare/models/paired_device.dart';
import 'package:clipshare/platform/config_store.dart';
import 'package:clipshare/platform/trust_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;
  late TrustStore store;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('clipshare-trust');
    store = TrustStore(ConfigStore(tmp));
  });

  tearDown(() {
    tmp.deleteSync(recursive: true);
  });

  final phone = PairedDevice(
    deviceId: 'phone-1',
    name: 'phone',
    publicKey: 'AQID',
    keyHash: 'hash-1',
    pairedAt: DateTime(2026, 8, 12),
  );
  test('empty by default', () async {
    expect(await store.all(), isEmpty);
  });

  test('add and list', () async {
    await store.add(phone);
    final devices = await store.all();
    expect(devices, hasLength(1));
    expect(devices.first.deviceId, 'phone-1');
    expect(devices.first.name, 'phone');
  });

  test('add replaces an existing device with the same id', () async {
    await store.add(phone);
    await store.add(PairedDevice(
      deviceId: 'phone-1',
      name: 'phone2',
      publicKey: 'AQID',
      keyHash: 'hash-2',
      pairedAt: DateTime(2026, 8, 13),
    ));
    final devices = await store.all();
    expect(devices, hasLength(1));
    expect(devices.first.name, 'phone2');
    expect(devices.first.keyHash, 'hash-2');
  });

  test('remove', () async {
    await store.add(phone);
    await store.remove('phone-1');
    expect(await store.all(), isEmpty);
  });

  test('find by id and key hash', () async {
    await store.add(phone);
    expect((await store.find('phone-1'))?.name, 'phone');
    expect(await store.find('nope'), isNull);
    expect((await store.findByKeyHash('hash-1'))?.deviceId, 'phone-1');
    expect(await store.findByKeyHash('nope'), isNull);
  });

  test('persists across instances', () async {
    await store.add(phone);
    final reloaded = TrustStore(ConfigStore(tmp));
    final devices = await reloaded.all();
    expect(devices, hasLength(1));
    expect(devices.first.pairedAt, DateTime(2026, 8, 12));
  });
}
