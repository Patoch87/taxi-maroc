import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_maroc/main.dart';
import 'package:taxi_maroc/screens/driver_home.dart';
import 'package:taxi_maroc/services/places.dart';
import 'package:taxi_maroc/services/promos.dart';
import 'package:taxi_maroc/services/rides.dart';
import 'package:taxi_maroc/services/settings.dart';
import 'package:taxi_maroc/services/tourism.dart';
import 'package:taxi_maroc/theme.dart';

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
  });

  test('offre choisie selon la destination, l\'heure, le type de course et les trajets passés', () {
    final mall = place('Morocco Mall');
    final options = rideOptions(destination: mall, routeM: 9000);
    RideOption opt(String id) => options.firstWhere((o) => o.id == id);
    final noon = DateTime(2026, 10, 3, 12);

    expect(pickPromo(destination: mall, option: opt('seul'), now: noon), zaraPromo);
    expect(pickPromo(destination: mall, option: opt('partage'), now: noon), koolsmoothiePromo);
    expect(pickPromo(destination: place('Gare Casa Voyageurs'), option: opt('partage'), now: DateTime(2026, 10, 3, 8)),
        cafePromo);
    final twin = place('Twin Center');
    expect(pickPromo(destination: twin, option: opt('partage'), now: DateTime(2026, 10, 3, 9)), isNull);
    final history = [
      for (var i = 0; i < 2; i++) TripRecord(destination: 'Ain Diab', option: 'Petit taxi', price: 15, date: noon),
    ];
    expect(pickPromo(destination: twin, option: opt('partage'), now: DateTime(2026, 10, 3, 9), history: history),
        koolsmoothiePromo);
  });

  test('taxi électrique au prix officiel du petit taxi, restaurants proches', () {
    final options = rideOptions(destination: place('Twin Center'), routeM: 4000, date: DateTime(2026, 10, 3, 12));
    final e = options.firstWhere((o) => o.id == 'electrique');
    expect(e.electric, isTrue);
    expect(e.priceMad, options.first.priceMad);
    expect(e.description, '0 essence, 0 CO₂ en route');

    final near = restaurantsNear(place('Morocco Mall'));
    expect(near.length, 3);
    expect(near.map((r) => r.$1.name), contains('Pasta Mall')); // le plus proche du Morocco Mall
    final ratings = near.map((r) => r.$1.rating).toList();
    expect(ratings, orderedEquals([...ratings]..sort((a, b) => b.compareTo(a)))); // mieux notés d'abord
  });

  testWidgets('carte d\'offre marquée « Exemple publicitaire (démo) », et désactivable', (tester) async {
    phone(tester);
    await tester.pumpWidget(const TaxiMarocApp(locate: false));
    await tester.pump();
    await tester.tap(find.text('Rechercher une destination'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Morocco Mall'), 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Morocco Mall'));
    await tester.pumpAndSettle();

    // Électrique : feuille verte et « 0 essence, 0 CO₂ en route ».
    expect(find.text('Électrique'), findsOneWidget);
    expect(find.text('0 essence, 0 CO₂ en route'), findsOneWidget);
    expect(find.byIcon(Icons.eco), findsOneWidget);

    await tester.tap(find.text('Petit taxi seul'));
    await tester.pumpAndSettle();
    expect(find.text('Exemple publicitaire (démo)'), findsOneWidget);
    expect(find.text('-15 % chez Zara au Morocco Mall'), findsOneWidget);

    settings.offers = false;
    await tester.pumpAndSettle();
    expect(find.text('Exemple publicitaire (démo)'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('mode senior : pas d\'offre tant que le passager ne la demande pas', (tester) async {
    phone(tester);
    settings.senior = true;
    await tester.pumpWidget(const TaxiMarocApp(locate: false));
    await tester.pump();
    await tester.tap(find.text('Commander un taxi'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'mall');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Morocco Mall'));
    await tester.pumpAndSettle();

    expect(find.text('Exemple publicitaire (démo)'), findsNothing);
    await tester.ensureVisible(find.text('Voir une offre'));
    await tester.tap(find.text('Voir une offre'));
    await tester.pumpAndSettle();
    expect(find.text('Exemple publicitaire (démo)'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('touriste (application en anglais) : 3 restaurants avec « Take a taxi there »', (tester) async {
    phone(tester);
    langNotifier.value = 'en';
    await tester.pumpWidget(const TaxiMarocApp(locate: false));
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
    await tester.ensureVisible(find.text('Take a taxi there').first);
    await tester.tap(find.text('Take a taxi there').first);
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
