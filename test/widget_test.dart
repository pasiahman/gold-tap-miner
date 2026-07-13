import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gold_tap_miner/main.dart';

void main() {
  testWidgets('mining screen exposes core controls and tapping awards gold', (tester) async {
    await tester.pumpWidget(const GoldTapMinerApp(testMode: true));
    await tester.pumpAndSettle();

    expect(find.text('GOLD'), findsOneWidget);
    expect(find.textContaining('LEVEL'), findsOneWidget);
    expect(find.text('UPGRADE'), findsOneWidget);
    expect(find.text('SHOP'), findsOneWidget);
    expect(find.text('2X GOLD'), findsOneWidget);
    expect(find.byKey(const Key('miner-tap-target')), findsOneWidget);
    expect(find.text('0'), findsOneWidget);

    await tester.tap(find.byKey(const Key('miner-tap-target')));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('1'), findsOneWidget);
    expect(find.text('+1'), findsOneWidget);
  });
}
