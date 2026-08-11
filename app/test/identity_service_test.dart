import 'dart:io';

import 'package:clipshare/crypto/identity_service.dart';
import 'package:clipshare/platform/config_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;
  late ConfigStore store;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('clipshare-identity');
    store = ConfigStore(tmp);
  });

  tearDown(() {
    tmp.deleteSync(recursive: true);
  });

  test('generates a fresh identity on first load', () async {
    final identity = await IdentityService(store).loadOrCreate();
    expect(identity.deviceId, hasLength(32));
    expect(identity.privateKey, isNotEmpty);
    expect(identity.publicKey, isNotEmpty);
  });

  test('loads the same identity on later loads', () async {
    final first = await IdentityService(store).loadOrCreate();
    final second = await IdentityService(store).loadOrCreate();
    expect(second.deviceId, first.deviceId);
    expect(second.privateKey, first.privateKey);
    expect(second.publicKey, first.publicKey);
  });

  test('two devices get different identities', () async {
    final a = await IdentityService(ConfigStore(tmp)).loadOrCreate();
    final other = Directory.systemTemp.createTempSync('clipshare-other');
    final b = await IdentityService(ConfigStore(other)).loadOrCreate();
    other.deleteSync(recursive: true);
    expect(a.deviceId, isNot(b.deviceId));
    expect(a.publicKey, isNot(b.publicKey));
  });
}
