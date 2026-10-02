import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_maroc/main.dart';
import 'package:taxi_maroc/services/demo.dart';
import 'package:taxi_maroc/services/places.dart';

void main() {
  testWidgets("l'accueil propose passager, chauffeur et commande vocale, et change de langue", (tester) async {
    await tester.pumpWidget(const TaxiMarocApp());
    expect(find.text('Je suis passager'), findsOneWidget);
    expect(find.text('Je suis chauffeur'), findsOneWidget);
    expect(find.text('Commande vocale'), findsOneWidget);

    langNotifier.value = 'ar';
    await tester.pumpAndSettle();
    expect(find.text('أنا راكب'), findsOneWidget);
    langNotifier.value = 'fr';
  });

  test('reconnaît une destination dictée', () {
    expect(findPlace('je veux aller à la gare Casa Voyageurs')?.name, 'Gare Casa Voyageurs');
    expect(findPlace('مسجد الحسن الثاني')?.name, 'Mosquée Hassan II');
    expect(findPlace('nulle part'), isNull);
  });

  test('mode démo : même prix que le serveur', () {
    // Même cas que backend/test/fare.test.ts : 4 km de route, nuit, seul, premium = 46,8 DH.
    const a = {'lat': 33.57, 'lng': -7.63};
    const b = {'lat': 33.57, 'lng': -7.63 + 0.033237}; // environ 3,077 km à vol d'oiseau, soit 4 km par la route
    final e = Demo.estimatePetitTaxi(
        depart: a, destination: b, seul: true, premium: true, date: DateTime(2026, 10, 2, 23));
    expect(e['montantMad'], closeTo(46.8, 0.2));
    expect(Demo.findTaxis(premium: false), isNotEmpty);
  });
}
