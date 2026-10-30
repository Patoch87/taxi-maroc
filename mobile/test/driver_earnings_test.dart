import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_maroc/main.dart';
import 'package:taxi_maroc/screens/earnings_screen.dart';
import 'package:taxi_maroc/services/driver_earnings.dart';
import 'package:taxi_maroc/services/driver_shift.dart';

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

  test('prime qualité : versée en fin de mois selon la note moyenne de toutes les courses', () {
    expect(RatingBonus.perRide(4.95), 2.0);
    expect(RatingBonus.perRide(4.9), 2.0);
    expect(RatingBonus.perRide(4.85), 1.5);
    expect(RatingBonus.perRide(4.6), 1.0);
    expect(RatingBonus.perRide(4.5), 0);
    expect(RatingBonus.forMonth(average: 4.9, rides: 90), 180); // 2 DH × 90 courses
    expect(RatingBonus.forMonth(average: 4.9, rides: 10), 0); // trop peu de courses notées
    expect(RatingBonus.forMonth(average: 4.9, rides: 30, rated: 15), 0);
    final months = DriverEarnings().months(now);
    expect(months.first.extra[ExtraSource.rating], closeTo(113.3, 1e-9)); // 4,62 : 1 DH × 1,1 × 103 courses
    expect(months[4].extra[ExtraSource.rating], greaterThan(113.3));
    expect(DriverEarnings().weeks(now).last.extra.containsKey(ExtraSource.rating), isFalse);
    // Les notes du jour comptent dans la moyenne du mois en cours.
    final low = DriverEarnings().months(now, todayRatingSum: 3 * 20, todayRated: 20).last;
    final high = DriverEarnings().months(now, todayRatingSum: 5 * 20, todayRated: 20).last;
    expect(high.rating, greaterThan(low.rating));
  });

  test('prime qualité : plus de courses dans le mois, plus la prime grandit', () {
    expect(RatingBonus.volumeFactor(99), 1);
    expect(RatingBonus.volumeFactor(100), 1.1);
    expect(RatingBonus.volumeFactor(149), 1.1);
    expect(RatingBonus.volumeFactor(150), 1.2);
    expect(RatingBonus.volumeFactor(250), 1.3);
    expect(RatingBonus.forMonth(average: 4.8, rides: 120), closeTo(198, 1e-9)); // 1,50 DH × 1,1 × 120
    expect(RatingBonus.forMonth(average: 4.9, rides: 160), closeTo(384, 1e-9)); // 2 DH × 1,2 × 160
  });

  test('prime qualité : les courses de tous les taxis du chauffeur s\'additionnent', () {
    for (final m in DriverEarnings().months(now)) {
      expect(m.ridesByTaxi.values.fold(0, (a, b) => a + b), m.rides);
      expect(m.ridesByTaxi.length, 2);
    }
    final base = DriverEarnings().months(now).last;
    final grand = DriverEarnings().months(now, todayRideCount: 7, todayTaxi: DemoTaxi.grand).last;
    expect(grand.rides, base.rides + 7);
    expect(grand.ridesByTaxi[DemoTaxi.grand], base.ridesByTaxi[DemoTaxi.grand]! + 7);
    expect(grand.ridesByTaxi[DemoTaxi.petit], base.ridesByTaxi[DemoTaxi.petit]);
  });

  test('chaque note du jour est comptée pour la prime du mois', () {
    final shift = DriverShift();
    shift.accept(ShiftRider(name: 'Amina', pickupIdx: 1, dropIdx: 2, fare: 10, rating: 5));
    shift.accept(ShiftRider(name: 'Karim', pickupIdx: 1, dropIdx: 3, fare: 10, rating: 4));
    shift.waitingAt(1).forEach(shift.pickUp);
    shift.advance(3);
    expect(shift.ratedToday, 2);
    expect(shift.ratingSumToday, 9);
  });

  test('le service du jour s\'ajoute à la période en cours', () {
    final e = DriverEarnings();
    final base = e.weeks(now).last;
    final live = e.weeks(now, todayRides: 42, todayTips: 10).last;
    expect(live.extraTotal - base.extraTotal, 52);
    expect(live.extra[ExtraSource.tips]! - base.extra[ExtraSource.tips]!, 10);
  });

  test('série de hausses et hausse en pourcentage', () {
    List<EarningsPeriod> p(List<double> v) => [
          for (final x in v) EarningsPeriod(start: now, before: 1000, extra: {ExtraSource.rides: x})
        ];
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
    expect(find.text('Prime qualité du mois'), findsOneWidget);
    expect(find.textContaining('tous vos taxis'), findsOneWidget);
    expect(find.textContaining('Petit taxi n° 2417'), findsOneWidget);
    expect(find.textContaining('Grand taxi n° 318'), findsOneWidget);
  });
}
