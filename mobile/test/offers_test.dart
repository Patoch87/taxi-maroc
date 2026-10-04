import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:taxi_maroc/main.dart';
import 'package:taxi_maroc/screens/driver_home.dart';
import 'package:taxi_maroc/services/card_check.dart';
import 'package:taxi_maroc/services/coupons.dart';
import 'package:taxi_maroc/services/places.dart';
import 'package:latlong2/latlong.dart';
import 'package:taxi_maroc/services/promos.dart';
import 'package:taxi_maroc/services/location.dart';
import 'package:taxi_maroc/services/routing.dart';
import 'package:taxi_maroc/services/rides.dart';
import 'package:taxi_maroc/services/settings.dart';
import 'package:taxi_maroc/services/tourism.dart';
import 'package:taxi_maroc/theme.dart';
import 'package:taxi_maroc/widgets/promo_card.dart';

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Place place(String name) => casablancaPlaces.firstWhere((p) => p.name == name);

void main() {
  setUp(() {
    settings.reset();
    langNotifier.value = 'fr';
    tripHistory.clear();
    savedCoupons.clear();
  });

  test('offre choisie selon la destination, l\'heure et les trajets passés', () {
    final mall = place('Morocco Mall');
    final options = rideOptions(destination: mall, routeM: 9000);
    final opt = options.first;
    final noon = DateTime(2026, 10, 5, 12); // lundi

    expect(promosFor(destination: mall, option: opt, now: noon), [fashionPromo, koolsmoothiePromo]);
    expect(promosFor(destination: mall, option: opt, now: DateTime(2026, 10, 5, 19)), [fashionPromo]);
    expect(pickPromo(destination: place('Gare Casa Port'), option: opt, now: DateTime(2026, 10, 5, 8)), portCafePromo);
    expect(pickPromo(destination: place('Anfa Place'), option: opt, now: noon), sportPromo);
    expect(pickPromo(destination: place('Twin Center'), option: opt, now: noon), lunchPromo);
    expect(
        pickPromo(destination: place('Twin Center'), option: opt, now: DateTime(2026, 10, 4, 12)), // dimanche
        koolsmoothiePromo);
    expect(pickPromo(destination: place('Ain Diab'), option: opt, now: DateTime(2026, 10, 5, 21)), teaPromo);
    expect(pickPromo(destination: place('Habous'), option: opt, now: noon), isNull);
    final history = [
      for (var i = 0; i < 2; i++) TripRecord(destination: 'Ain Diab', option: 'Petit taxi', price: 15, date: noon),
    ];
    expect(pickPromo(destination: place('Habous'), option: opt, now: noon, history: history), koolsmoothiePromo);
    // Chaque annonceur a un badge (initiales), jamais un logo de marque.
    for (final p in allPromos) {
      expect(p.initials.length, inInclusiveRange(1, 3));
      expect(p.address, isNotEmpty);
    }
  });

  test('code du bon : compte, offre, course, expiration et somme de contrôle', () {
    final code =
        buildCouponCode(userId: 'U7Q3K9', offerId: 'MODE', tripId: 'T123456', expires: DateTime(2026, 10, 6, 14, 30));
    expect(code, startsWith('TM-U7Q3K9-MODE-T123456-20261006-'));
    expect(code.split('-').last, hasLength(2));
    expect(isValidCouponCode(code), isTrue);
    expect(isValidCouponCode(code.replaceFirst('MODE', 'MODA')), isFalse); // faute de frappe détectée
    expect(isValidCouponCode('nimporte quoi'), isFalse);
    // Même entrée, même code ; course différente, code différent.
    expect(buildCouponCode(userId: 'U7Q3K9', offerId: 'MODE', tripId: 'T123456', expires: DateTime(2026, 10, 6)), code);
    expect(
        buildCouponCode(userId: 'U7Q3K9', offerId: 'MODE', tripId: 'T654321', expires: DateTime(2026, 10, 6)) == code,
        isFalse);
    final c = Coupon(promo: fashionPromo, tripId: 'T1', issuedAt: DateTime(2026, 10, 5, 9));
    expect(c.expires, DateTime(2026, 10, 6, 9)); // valable 24 h
    expect(c.code, contains('-$demoUserId-MODE-T1-20261006-'));
  });

  test('carte (paiement simulé) : vérification du format seulement', () {
    expect(validCardNumber('4242 4242 4242 4242'), isTrue);
    expect(validCardNumber('4242'), isFalse);
    expect(validCardNumber('4242 abcd 4242 4242'), isFalse);
    final now = DateTime(2026, 10, 5);
    expect(validExpiry('12/29', now: now), isTrue);
    expect(validExpiry('10/26', now: now), isTrue);
    expect(validExpiry('09/26', now: now), isFalse);
    expect(validExpiry('13/29', now: now), isFalse);
    expect(validExpiry('1229', now: now), isFalse);
    expect(validCvc('123'), isTrue);
    expect(validCvc('12'), isFalse);
  });

  test('plus d\'option électrique côté passager, restaurants proches', () {
    final options = rideOptions(destination: place('Twin Center'), routeM: 4000, date: DateTime(2026, 10, 3, 12));
    expect(options.where((o) => o.kind == TaxiKind.electrique), isEmpty);

    final near = restaurantsNear(place('Morocco Mall'));
    expect(near.length, 3);
    expect(near.map((r) => r.$1.name), contains('Pasta Mall')); // le plus proche du Morocco Mall
    final ratings = near.map((r) => r.$1.rating).toList();
    expect(ratings, orderedEquals([...ratings]..sort((a, b) => b.compareTo(a)))); // mieux notés d'abord
  });

  testWidgets('options : valises et siège bébé, sans offre avant la course', (tester) async {
    phone(tester);
    await tester.pumpWidget(const TaxiMarocApp(locate: false, onboarding: false));
    await tester.pump();
    await tester.tap(find.text('Rechercher une destination'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Morocco Mall'), 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Morocco Mall'));
    await tester.pumpAndSettle();

    // Plus d'option « Électrique » ; chaque option montre ses valises.
    expect(find.text('Électrique'), findsNothing);
    expect(find.byIcon(Icons.luggage), findsNWidgets(4)); // 3 options + compteur de valises

    // 3 valises : seul le premium reste possible, il est choisi.
    for (var i = 0; i < 3; i++) {
      await tester.ensureVisible(find.byTooltip('Une valise de plus'));
      await tester.tap(find.byTooltip('Une valise de plus'));
      await tester.pump();
    }
    expect(find.text('Pas assez de place pour vos valises'), findsNWidgets(2));
    expect(find.textContaining('Commander ·'), findsOneWidget);
    await tester.ensureVisible(find.text('Petit taxi seul'));
    await tester.tap(find.text('Petit taxi seul'), warnIfMissed: false);
    await tester.pump();
    expect(find.text('Pas assez de place pour vos valises'), findsNWidgets(2)); // non sélectionnable
    await tester.ensureVisible(find.byTooltip('Une valise de moins'));
    await tester.tap(find.byTooltip('Une valise de moins'));
    await tester.pump();
    await tester.ensureVisible(find.byTooltip('Une valise de moins'));
    await tester.tap(find.byTooltip('Une valise de moins'));
    await tester.pump();
    await tester.ensureVisible(find.byTooltip('Une valise de moins'));
    await tester.tap(find.byTooltip('Une valise de moins'));
    await tester.pump();

    // Pas d'offre avant le début de la course.
    expect(find.text('Exemple publicitaire (démo)'), findsNothing);

    // Siège bébé : gratuit, puis visible sur la fiche du chauffeur.
    await tester.ensureVisible(find.text('Siège bébé'));
    await tester.tap(find.text('Siège bébé'));
    await tester.pumpAndSettle();
    expect(find.textContaining('seuls les chauffeurs équipés'), findsOneWidget);
    await tester.ensureVisible(find.textContaining('Commander ·'));
    await tester.tap(find.textContaining('Commander ·'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.text('Votre taxi arrive dans'), findsOneWidget);
    expect(find.text('Siège bébé demandé'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('offre seulement passager à bord : bon avec QR code, enregistré dans « Mes offres »', (tester) async {
    phone(tester);
    await tester.pumpWidget(const TaxiMarocApp(locate: false, onboarding: false));
    await tester.pump();
    await tester.tap(find.text('Rechercher une destination'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Morocco Mall'), 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Morocco Mall'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.textContaining('Commander ·'));
    await tester.tap(find.textContaining('Commander ·'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    // Le taxi arrive : toujours pas d'offre.
    expect(find.text('Votre taxi arrive dans'), findsOneWidget);
    expect(find.text('Exemple publicitaire (démo)'), findsNothing);
    for (var i = 0; i < 90 && find.text('Je suis dans le taxi').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.ensureVisible(find.text('Je suis dans le taxi'));
    await tester.tap(find.text('Je suis dans le taxi'));
    await tester.pump();

    // Passager à bord : l'offre apparaît, avec le badge de l'annonceur.
    expect(find.text('Exemple publicitaire (démo)'), findsOneWidget);
    expect(find.text('-15 % sur la nouvelle collection'), findsOneWidget);
    expect(find.byType(BrandBadge), findsOneWidget);

    await tester.ensureVisible(find.text('-15 % sur la nouvelle collection'));
    await tester.tap(find.text('-15 % sur la nouvelle collection'));
    await tester.pumpAndSettle();
    expect(find.text('Votre bon de réduction'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    final code = tester.widget<QrImageView>(find.byType(QrImageView));
    final text = tester.widget<SelectableText>(find.byType(SelectableText)).data!;
    expect(text, startsWith('TM-$demoUserId-MODE-T'));
    expect(isValidCouponCode(text), isTrue);
    expect(code.semanticsLabel, isNotNull);
    expect(find.text('Valable 24 h, une fois, sur présentation en caisse'), findsOneWidget);
    expect(find.textContaining('Morocco Mall, niveau 1'), findsOneWidget);

    await tester.ensureVisible(find.text('Enregistrer dans mes offres'));
    await tester.tap(find.text('Enregistrer dans mes offres'));
    await tester.pump();
    expect(savedCoupons.single.code, text);
    expect(find.text('Enregistré dans mes offres'), findsWidgets);
    Navigator.of(tester.element(find.text('Votre bon de réduction'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Ouvrir le menu de navigation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mes offres'));
    await tester.pumpAndSettle();
    expect(find.text('-15 % sur la nouvelle collection'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('touriste (application en anglais) : 3 restaurants avec « Take a taxi there »', (tester) async {
    phone(tester);
    langNotifier.value = 'en';
    await tester.pumpWidget(const TaxiMarocApp(locate: false, onboarding: false));
    await tester.pump();
    await tester.tap(find.text('Gare Casa Voyageurs'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.textContaining('Request ·'));
    await tester.tap(find.textContaining('Request ·'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.text('Your taxi arrives in'), findsOneWidget);
    expect(find.text('Restaurants near Gare Casa Voyageurs'), findsOneWidget);
    expect(find.text('Take a taxi there'), findsNWidgets(3));
    expect(find.text('TripAdvisor rating (demo)'), findsNWidgets(3));

    final first = restaurantsNear(place('Gare Casa Voyageurs')).first.$1;
    // Confirmation : nouveau prix depuis la position actuelle, même type de taxi, et nouvelle arrivée.
    await tester.ensureVisible(find.text('Take a taxi there').first);
    await tester.tap(find.text('Take a taxi there').first);
    await tester.pumpAndSettle();
    expect(find.text('Change destination?'), findsOneWidget);
    expect(find.text('Current price'), findsOneWidget);
    expect(find.textContaining('New price'), findsOneWidget);
    expect(find.text('New arrival'), findsOneWidget);
    final newPrice = tester.widget<Text>(find.byKey(const ValueKey('newPrice'))).data!;
    final expected = rideOptions(
            destination: first.place,
            routeM: routeLengthM(interpolate(casablancaCenter, LatLng(first.lat, first.lng), 40)))
        .first;
    expect(newPrice, dh(expected.priceMad));

    // Annuler : la destination ne change pas.
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Cancel')));
    await tester.pumpAndSettle();
    expect(find.text('New destination : ${first.name}'), findsNothing);
    expect(find.text('Restaurants near Gare Casa Voyageurs'), findsOneWidget);

    await tester.ensureVisible(find.text('Take a taxi there').first);
    await tester.tap(find.text('Take a taxi there').first);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Confirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('New destination : ${first.name}'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    langNotifier.value = 'fr';
  });

  testWidgets('chauffeur de taxi électrique : batterie et bornes de recharge', (tester) async {
    phone(tester);
    await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: const DriverHome()));
    await tester.pump();
    await tester.tap(find.text('Électrique'));
    await tester.pump();
    await tester.tap(find.text('Passer en ligne'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Batterie'), findsOneWidget);

    await tester.tap(find.text('Bornes de recharge'));
    await tester.pumpAndSettle();
    expect(find.text('Borne Anfa'), findsOneWidget);
    expect(find.text('Borne Aïn Sebaâ'), findsOneWidget);
    expect(find.text('Y aller'), findsNWidgets(4));
    await tester.tap(find.text('Y aller').first);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('Y aller'), findsNothing);
    // Bornes affichées sur la carte pendant le trajet vers la recharge.
    expect(find.byIcon(Icons.ev_station), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });
}
