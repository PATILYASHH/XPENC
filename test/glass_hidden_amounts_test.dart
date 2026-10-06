import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/core/theme/theme_preset.dart';
import 'package:xpenc/core/widgets/money_text.dart';

/// Hide amounts under Glass: the figure turns to frosted glass — and what's
/// frosted is a fixed decoy, never the real digits (a blur of real digits in
/// a known font can be matched back to them).
void main() {
  Widget app(Money amount, {required bool glass}) => MaterialApp(
    theme: glass
        ? AppTheme.of(
            GlassBackdrop.black.palette,
            ThemeStyle.glass.shape,
            backdrop: GlassBackdrop.black,
          )
        : AppTheme.of(
            ThemeStyle.classic.lightPalette,
            ThemeStyle.classic.shape,
          ),
    home: AmountVisibilityScope(
      hidden: true,
      child: Scaffold(body: Center(child: MoneyText(amount))),
    ),
  );

  String shown(WidgetTester tester) =>
      tester.widget<Text>(find.byType(Text)).data!;

  testWidgets('Glass frosts a decoy, the same for every amount', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(app(Money.fromRupees(1234), glass: true));
    expect(find.byType(ImageFiltered), findsOneWidget);
    expect(find.textContaining('1,234'), findsNothing);
    expect(find.bySemanticsLabel('Amount hidden'), findsOneWidget);
    final small = shown(tester);

    await tester.pumpWidget(app(Money.fromRupees(12345678), glass: true));
    expect(shown(tester), small);
    handle.dispose();
  });

  testWidgets('other styles keep the bullet mask, unblurred', (tester) async {
    await tester.pumpWidget(app(Money.fromRupees(1234), glass: false));
    expect(find.byType(ImageFiltered), findsNothing);
    expect(shown(tester), contains('••••••'));
  });
}
