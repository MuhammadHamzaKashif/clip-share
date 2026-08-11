import 'package:clipshare/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('home screen renders the main controls', (tester) async {
    await tester.pumpWidget(const ClipShareApp());

    expect(find.text('ClipShare'), findsOneWidget);
    expect(find.text('Pair device'), findsOneWidget);
    expect(find.text('Start sync'), findsOneWidget);
    expect(find.text('Recent clipboard items'), findsOneWidget);
  });
}
