import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_maroc/main.dart';
import 'package:taxi_maroc/services/settings.dart';
import 'package:taxi_maroc/widgets/promo_card.dart';

void main() {
  setUp(() {
    settings.reset();
    langNotifier.value = 'fr';
  });

  testWidgets('vue carte : bandeau du taxi, bandeau publicitaire masquable, SOS toujours là', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const TaxiMarocApp(locate: false));
    await tester.pump();
    await tester.tap(find.text('Gare Casa Voyageurs'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.textContaining('Commander ·'));
    await tester.tap(find.textContaining('Commander ·'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.text('Votre taxi arrive dans'), findsOneWidget);

    await tester.tap(find.byTooltip('Carte plein écran'));
    await tester.pump();
    expect(find.text('Votre taxi arrive dans'), findsNothing);
    expect(find.byType(AdBanner), findsOneWidget);
    expect(find.text('Exemple publicitaire (démo)'), findsOneWidget);
    expect(find.byTooltip('SOS urgence'), findsOneWidget);
    expect(find.byTooltip('Appeler'), findsOneWidget);

    // Rotation toutes les 15 s, toujours avec la mention.
    await tester.pump(const Duration(seconds: 15));
    expect(find.text('Exemple publicitaire (démo)'), findsOneWidget);

    await tester.tap(find.byTooltip('Masquer la publicité'));
    await tester.pump();
    expect(find.byType(AdBanner), findsNothing);
    expect(find.byTooltip('SOS urgence'), findsOneWidget);

    await tester.tap(find.byTooltip('SOS urgence'));
    await tester.pumpAndSettle();
    expect(find.text('Numéros d\'urgence'), findsOneWidget);
    Navigator.of(tester.element(find.text('Numéros d\'urgence'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Afficher les détails'));
    await tester.pump();
    expect(find.text('Votre taxi arrive dans'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('offres personnalisées désactivées : bandeau générique non personnalisé', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    settings.offers = false;
    await tester.pumpWidget(const TaxiMarocApp(locate: false));
    await tester.pump();
    await tester.tap(find.text('Gare Casa Voyageurs'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.textContaining('Commander ·'));
    await tester.tap(find.textContaining('Commander ·'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    await tester.tap(find.byTooltip('Carte plein écran'));
    await tester.pump();
    expect(find.text('Votre publicité ici'), findsOneWidget);
    expect(find.text('Exemple publicitaire (démo)'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
