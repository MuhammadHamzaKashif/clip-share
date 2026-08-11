import 'dart:io';

import 'package:clipshare/main.dart';
import 'package:clipshare/platform/config_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('home screen renders the main controls', (tester) async {
    final tmp = Directory.systemTemp.createTempSync('clipshare-widget');
    await tester.pumpWidget(ClipShareApp(store: ConfigStore(tmp)));
    await tester.pumpAndSettle();

    expect(find.text('ClipShare'), findsOneWidget);
    expect(find.text('Pair device'), findsOneWidget);
    expect(find.text('Start sync'), findsOneWidget);
    expect(find.text('Recent clipboard items'), findsOneWidget);
    expect(find.text('history: 50 items'), findsOneWidget);

    tmp.deleteSync(recursive: true);
  });
}
