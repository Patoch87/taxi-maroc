import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_maroc/l10n/strings.dart';
import 'package:taxi_maroc/main.dart';
import 'package:taxi_maroc/screens/games_screen.dart';
import 'package:taxi_maroc/services/coupons.dart';
import 'package:taxi_maroc/services/demo.dart';
import 'package:taxi_maroc/services/games.dart';
import 'package:taxi_maroc/services/places.dart';
import 'package:taxi_maroc/services/rides.dart';
import 'package:taxi_maroc/services/settings.dart';
import 'package:taxi_maroc/services/tourism.dart';
import 'package:taxi_maroc/theme.dart';
import 'package:taxi_maroc/widgets/table_booking.dart';

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Widget app(Widget home) => MaterialApp(theme: buildTheme(), home: home);

void main() {
  setUp(() {
    settings.reset();
    langNotifier.value = 'fr';
    savedCoupons.clear();
    resetGames();
  });

  group('prix « Seul » : compteur + compensation chauffeur + 3 MAD de frais', () {
    test('1 passager : 2 places bloquées, compensation = compteur', () {
      final p = Demo.seulPrice(compteur: 20, passengers: 1);
      expect([p.compteur, p.compensation, p.frais, p.total], [20, 20, 3, 43]);
    });
    test('groupe de 2 : compensation = 50 % du compteur, au moins 10 MAD', () {
      expect(Demo.seulPrice(compteur: 30, passengers: 2).compensation, 15);
      expect(Demo.seulPrice(compteur: 16, passengers: 2).compensation, 10);
      expect(Demo.seulPrice(compteur: 16, passengers: 2).total, 29);
    });
    test('groupe de 3 : aucune compensation', () {
      final p = Demo.seulPrice(compteur: 16, passengers: 3);
      expect(p.compensation, 0);
      expect(p.total, 19);
    });
    test('compensation minimale de 10 MAD pour un petit compteur', () {
      expect(Demo.seulPrice(compteur: 7.5).compensation, 10);
    });
    test('options : détail affiché sur « Seul », premium inchangé', () {
      final noon = DateTime(2026, 10, 2, 12);
      final o = rideOptions(destination: casablancaPlaces.first, routeM: 4000, date: noon);
      final seul = o.firstWhere((x) => x.id == 'seul');
      expect(seul.priceMad, 35);
      expect(seulBreakdownText(seul.breakdown!), 'Compteur 16 + compensation chauffeur 16 + frais 3 = 35 DH');
      expect(o.firstWhere((x) => x.id == 'premium').priceMad, 31.2); // 16 × 1,3 × 1,5
      final group = rideOptions(destination: casablancaPlaces.first, routeM: 4000, date: noon, passengers: 3);
      expect(group.firstWhere((x) => x.id == 'seul').priceMad, 19);
      expect(group.first.priceMad, 16); // partagé inchangé
    });
  });

  testWidgets('choix du taxi : détail du prix seul et explication', (tester) async {
    phone(tester);
    await tester.pumpWidget(const TaxiMarocApp(locate: false, onboarding: false));
    await tester.pump();
    await tester.tap(find.text('Gare Casa Voyageurs'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('seulBreakdown')), findsOneWidget);
    expect(find.textContaining('compensation chauffeur'), findsOneWidget);
    expect(find.text("La compensation paie au chauffeur les places qu'il ne pourra pas proposer sur sa route."),
        findsOneWidget);
  });

  testWidgets('jeux : cadeau gagné enregistré dans Mes offres, une partie par course', (tester) async {
    phone(tester);
    await tester.pumpWidget(app(const GamesScreen(tripId: 'T123456')));
    expect(find.text('Grattez et gagnez'), findsOneWidget);
    expect(find.text('Roue des cadeaux'), findsOneWidget);
    expect(find.text('Quiz du Maroc'), findsOneWidget);
    await tester.tap(find.text('Grattez et gagnez'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tout gratter'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Gagné !'), findsOneWidget);
    expect(find.textContaining('exemple fictif'), findsWidgets);
    expect(find.text('Cadeau ajouté à Mes offres'), findsOneWidget);
    expect(savedCoupons, hasLength(1));
    expect(savedCoupons.first.promo.partnerGift, isTrue);
    expect(isValidCouponCode(savedCoupons.first.code), isTrue);
    await tester.tap(find.text('Fermer'));
    await tester.pumpAndSettle();
    expect(find.text('Déjà joué pendant cette course'), findsOneWidget);
    expect(hasPlayed('T123456', TripGame.scratch), isTrue);
    expect(hasPlayed('T999999', TripGame.scratch), isFalse);
  });

  testWidgets('roue et quiz', (tester) async {
    phone(tester);
    await tester.pumpWidget(app(GamePage(game: TripGame.wheel, tripId: 'T1', titleKey: 'gameWheel', rnd: Random(1))));
    await tester.tap(find.text('Tourner la roue'));
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Gagné !'), findsOneWidget);

    await tester.pumpWidget(app(GamePage(
        key: const ValueKey('quiz'), game: TripGame.quiz, tripId: 'T1', titleKey: 'gameQuiz', rnd: Random(2))));
    await tester.pumpAndSettle();
    final q = quizQuestions.firstWhere((q) => find.text(S('fr').t(q.$1)).evaluate().isNotEmpty);
    await tester.tap(find.text(q.$2[q.$3]));
    await tester.pumpAndSettle();
    expect(find.text('Gagné !'), findsOneWidget);
    expect(savedCoupons, hasLength(2));
  });

  testWidgets('réserver une table : panneau prérempli puis « Table réservée »', (tester) async {
    phone(tester);
    final r = demoRestaurants.first;
    TableBooking? booking;
    await tester.pumpWidget(app(Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
              onPressed: () async => booking = await showTableBookingSheet(context, r), child: const Text('ouvrir')),
        ),
      ),
    )));
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    expect(find.text('Réserver une table'), findsOneWidget);
    expect(find.text('Yasmine B.'), findsOneWidget);
    await tester.tap(find.byTooltip('Une personne de plus'));
    await tester.pump();
    await tester.tap(find.text('Confirmer la réservation'));
    await tester.pumpAndSettle();
    expect(booking!.people, 3);
    expect(booking!.name, 'Yasmine B.');

    await tester.pumpWidget(app(TableBookedScreen(booking: booking!)));
    expect(find.text('Table réservée'), findsWidgets);
    expect(find.text("Y aller en taxi à l'heure de la réservation"), findsOneWidget);
    expect(find.textContaining('Table pour 3'), findsOneWidget);
  });
}
