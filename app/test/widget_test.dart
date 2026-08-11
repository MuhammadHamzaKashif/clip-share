import 'dart:io';

import 'package:clipshare/crypto/identity_service.dart';
import 'package:clipshare/discovery/discovery_service.dart';
import 'package:clipshare/main.dart';
import 'package:clipshare/models/settings.dart';
import 'package:clipshare/pairing/pairing_service.dart';
import 'package:clipshare/platform/config_store.dart';
import 'package:clipshare/platform/trust_store.dart';
import 'package:clipshare/sync/sync_engine.dart';
import 'package:clipshare/ui/pair_device_sheet.dart';
import 'package:clipshare/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('home screen renders the main controls', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final tmp = Directory.systemTemp.createTempSync('clipshare-widget');
    await tester.pumpWidget(ClipShareApp(store: ConfigStore(tmp), startEngine: false));
    await tester.pumpAndSettle();

    expect(find.text('ClipShare'), findsOneWidget);
    expect(find.text('Pair device'), findsOneWidget);
    expect(find.text('Start sync'), findsOneWidget);
    expect(find.text('Recent'), findsOneWidget);
    expect(find.text('Devices'), findsOneWidget);
    expect(find.text('history: 50 items'), findsOneWidget);

    tmp.deleteSync(recursive: true);
  });

  testWidgets('pair sheet opens as a proper sized panel', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final tmp = Directory.systemTemp.createTempSync('clipshare-widget');
    final store = ConfigStore(tmp);
    final identity = await tester.runAsync(() => IdentityService(store).loadOrCreate());
    final engine = SyncEngine(
      identity: identity!,
      settings: Settings.defaults,
      trustStore: TrustStore(store),
      pairingService: PairingService(identity),
      discovery: DiscoveryService(),
    );
    addTearDown(engine.dispose);

    await tester.pumpWidget(MaterialApp(
      theme: lightTheme,
      home: Scaffold(
        body: Center(
          child: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                constraints: const BoxConstraints(maxWidth: 520),
                builder: (_) => PairDeviceSheet(engine: engine, devices: const []),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Show my code'), findsOneWidget);
    expect(find.text('Enter a code'), findsOneWidget);
    final size = tester.getSize(find.byType(PairDeviceSheet));
    expect(size.width, closeTo(520, 1));

    tmp.deleteSync(recursive: true);
  });
}
