import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_maroc/main.dart';
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
}
