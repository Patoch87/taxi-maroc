import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_maroc/main.dart';
import 'package:taxi_maroc/services/demo.dart';
import 'package:taxi_maroc/services/places.dart';
import 'package:taxi_maroc/services/rides.dart';

void main() {
  testWidgets("l'accueil affiche la carte et « Où allez-vous ? », et change de langue", (tester) async {
    await tester.pumpWidget(const TaxiMarocApp(locate: false));
    await tester.pump();
    expect(find.text('Où allez-vous ?'), findsOneWidget);

    langNotifier.value = 'ar';
    await tester.pump();
    expect(find.text('إلى أين تذهب؟'), findsOneWidget);
    langNotifier.value = 'fr';
    await tester.pump();
  });

  test('reconnaît une destination dictée ou tapée', () {
    expect(findPlace('je veux aller à la gare Casa Voyageurs')?.name, 'Gare Casa Voyageurs');
    expect(findPlace('مسجد الحسن الثاني')?.name, 'Mosquée Hassan II');
    expect(findPlace('nulle part'), isNull);
    expect(searchPlaces('twin').map((p) => p.name), ['Twin Center']);
  });

  test('options de course : petit taxi en ville, grand taxi hors de la ville', () {
    final ville = rideOptions(destination: casablancaPlaces.first, routeM: 4000, date: DateTime(2026, 10, 2, 12));
    expect(ville.map((o) => o.id), ['partage', 'seul', 'premium']);
    expect(ville[0].priceMad, 16); // 2 + 4 km x 3,5
    expect(ville[1].priceMad, 20.8); // + 30 % seul
    expect(ville.map((o) => o.luggage), [2, 2, 3]); // valises dans le coffre

    final mohammedia = casablancaPlaces.firstWhere((p) => p.name == 'Mohammedia');
    final grand = rideOptions(destination: mohammedia, routeM: 25000);
    expect(grand.map((o) => o.priceMad), [12, 72]);
    expect(grand.map((o) => o.luggage), [1, 4]);
  });

  test('mode démo : même prix que le serveur', () {
    // Même cas que backend/test/fare.test.ts : 4 km de route, nuit, seul, premium = 46,8 DH.
    const a = {'lat': 33.57, 'lng': -7.63};
    const b = {'lat': 33.57, 'lng': -7.63 + 0.033237}; // environ 3,077 km à vol d'oiseau, soit 4 km par la route
    final e =
        Demo.estimatePetitTaxi(depart: a, destination: b, seul: true, premium: true, date: DateTime(2026, 10, 2, 23));
    expect(e['montantMad'], closeTo(46.8, 0.2));
    expect(Demo.petitTaxiPrice(routeKm: 4, seul: true, premium: true, date: DateTime(2026, 10, 2, 23)), 46.8);
  });
}
