import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_maroc/main.dart';
import 'package:taxi_maroc/screens/earnings_screen.dart';
import 'package:taxi_maroc/services/driver_earnings.dart';

void main() {
  final now = DateTime(2026, 10, 22, 18); // jeudi

  test('semaines : « avant » = moyenne déclarée, gains en plus en hausse', () {
    final e = DriverEarnings(beforePerDay: 250);
    final weeks = e.weeks(now);
    expect(weeks.length, 8);
    expect(weeks.first.before, 1500); // 6 jours de 250 DH
    expect(weeks.last.start, DateTime(2026, 10, 19)); // lundi de la semaine en cours
    expect(weeks.last.before, 1000); // 4 jours écoulés
    expect(weeks[6].extraTotal, greaterThan(weeks[0].extraTotal));
    for (final w in weeks.take(7)) {
      expect(w.extraTotal, inInclusiveRange(300, 500), reason: '${w.start}');
    }
  });

  test('mois : 1 500 à 2 000 DH de plus par mois complet', () {
    final months = DriverEarnings().months(now);
    expect(months.length, 6);
    expect(months.last.start, DateTime(2026, 10));
    for (final m in months.take(5)) {
      expect(m.extraTotal, inInclusiveRange(1500, 2000), reason: '${m.start}');
    }
  });

  test('le service du jour s\'ajoute à la période en cours', () {
    final e = DriverEarnings();
    final base = e.weeks(now).last;
    final live = e.weeks(now, todayRides: 42, todayTips: 10).last;
    expect(live.extraTotal - base.extraTotal, 52);
    expect(live.extra[ExtraSource.tips]! - base.extra[ExtraSource.tips]!, 10);
  });

  test('série de hausses et hausse en pourcentage', () {
    List<EarningsPeriod> p(List<double> v) =>
        [for (final x in v) EarningsPeriod(start: now, before: 1000, extra: {ExtraSource.rides: x})];
    expect(DriverEarnings.risingStreak(p([100, 200, 300, 50])), 2); // la période en cours ne compte pas
    expect(DriverEarnings.risingStreak(p([300, 200, 100, 50])), 0);
    expect(p([270]).first.increase, closeTo(.27, 1e-9));
  });

  testWidgets('écran « Mes gains » : semaine puis mois', (tester) async {
    langNotifier.value = 'fr';
    await tester.pumpWidget(MaterialApp(home: EarningsScreen(now: now)));
    expect(find.text('Cette semaine'), findsOneWidget);
    expect(find.text('Avant Bab Taxi'), findsOneWidget);
    expect(find.text('Avec Bab Taxi'), findsOneWidget);
    expect(find.textContaining('par rapport à avant'), findsOneWidget);
    await tester.tap(find.text('Mois'));
    await tester.pumpAndSettle();
    expect(find.text('Ce mois-ci'), findsOneWidget);
    await tester.dragUntilVisible(find.text('Oct.'), find.byType(ListView), const Offset(0, -200));
    expect(find.text('Oct.'), findsOneWidget);
  });
}
