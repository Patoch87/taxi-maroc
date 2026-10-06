import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_maroc/main.dart';
import 'package:taxi_maroc/services/rides.dart';
import 'package:taxi_maroc/services/settings.dart';
import 'package:taxi_maroc/widgets/promo_card.dart';

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

final handle = find.byKey(const ValueKey('sheetHandle'));

Future<void> startTrip(WidgetTester tester) async {
  await tester.tap(find.text('Gare Casa Voyageurs'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.textContaining('Commander ·'));
  await tester.tap(find.textContaining('Commander ·'));
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

void main() {
  setUp(() {
    settings.reset();
    langNotifier.value = 'fr';
    tripHistory.clear();
  });

  testWidgets('poignée : glisser vers le bas replie le panneau sur la recherche, vers le haut le rouvre',
      (tester) async {
    phone(tester);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(const TaxiMarocApp(locate: false, onboarding: false));
    await tester.pump();
    expect(find.bySemanticsLabel('Afficher ou masquer les détails'), findsOneWidget);
    // Zone à saisir assez grande.
    expect(tester.getSize(handle).height, greaterThanOrEqualTo(40));
    expect(find.text('Où allez-vous ?'), findsOneWidget);

    await tester.drag(handle, const Offset(0, 250));
    await tester.pumpAndSettle();
    expect(find.text('Où allez-vous ?'), findsNothing);
    expect(find.text('Rechercher une destination'), findsOneWidget);

    await tester.drag(handle, const Offset(0, -250));
    await tester.pumpAndSettle();
    expect(find.text('Où allez-vous ?'), findsOneWidget);
    semantics.dispose();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('course : panneau replié = bandeau du taxi et bandeau publicitaire masquable', (tester) async {
    phone(tester);
    await tester.pumpWidget(const TaxiMarocApp(locate: false, onboarding: false));
    await tester.pump();
    await startTrip(tester);
    expect(find.text('Votre taxi arrive dans'), findsOneWidget);

    // Le taxi arrive : panneau replié sans publicité (seulement passager à bord).
    await tester.drag(handle, const Offset(0, 300));
    await tester.pump();
    expect(find.text('Votre taxi arrive dans'), findsNothing);
    expect(find.byType(AdBanner), findsNothing);
    expect(find.byTooltip('SOS urgence'), findsOneWidget);
    expect(find.byTooltip('Appeler'), findsOneWidget);
    await tester.tap(handle);
    await tester.pump();
    for (var i = 0; i < 100 && find.text('Je suis dans le taxi').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.ensureVisible(find.text('Je suis dans le taxi'));
    await tester.tap(find.text('Je suis dans le taxi'));
    await tester.pump();

    await tester.drag(handle, const Offset(0, 300));
    await tester.pump();
    expect(find.byType(AdBanner), findsOneWidget);
    expect(find.text('Publicité'), findsOneWidget);
    expect(find.byTooltip('SOS urgence'), findsOneWidget);

    // Rotation toutes les 15 s, toujours avec la mention.
    await tester.pump(const Duration(seconds: 15));
    expect(find.text('Publicité'), findsOneWidget);

    await tester.tap(find.byTooltip('Masquer la publicité'));
    await tester.pump();
    expect(find.byType(AdBanner), findsNothing);

    await tester.tap(find.byTooltip('SOS urgence'));
    await tester.pumpAndSettle();
    expect(find.text('Numéros d\'urgence'), findsOneWidget);
    Navigator.of(tester.element(find.text('Numéros d\'urgence'))).pop();
    await tester.pumpAndSettle();

    // Toucher la poignée rouvre les détails.
    await tester.tap(handle);
    await tester.pump();
    expect(find.byTooltip('Carte plein écran'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('mode senior : l\'icône l\'active, « Revenir au mode normal » fonctionne partout', (tester) async {
    phone(tester);
    await tester.pumpWidget(const TaxiMarocApp(locate: false, onboarding: false));
    await tester.pump();

    // Depuis l'accueil senior.
    await tester.tap(find.byTooltip('Mode senior'));
    await tester.pumpAndSettle();
    expect(settings.senior, isTrue);
    expect(find.text('Revenir au mode normal'), findsOneWidget);
    await tester.tap(find.text('Revenir au mode normal'));
    await tester.pumpAndSettle();
    expect(settings.senior, isFalse);
    expect(find.text('Où allez-vous ?'), findsOneWidget);

    // Depuis l'écran de recherche senior.
    await tester.tap(find.byTooltip('Mode senior'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Commander un taxi'));
    await tester.pumpAndSettle();
    expect(find.text('Dire ma destination'), findsOneWidget);
    await tester.tap(find.text('Revenir au mode normal'));
    await tester.pumpAndSettle();
    expect(settings.senior, isFalse);
    expect(find.text('Dire ma destination'), findsNothing);
    await tester.tap(find.text('Gare Casa Voyageurs'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Commander ·'), findsOneWidget);
    final cancel = find.ancestor(of: find.byIcon(Icons.close), matching: find.byType(OutlinedButton)).first;
    await tester.ensureVisible(cancel);
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    expect(find.text('Où allez-vous ?'), findsOneWidget);

    // Depuis une course en mode senior : retour aux détails normaux de la course.
    await tester.tap(find.byTooltip('Mode senior'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rentrer à la maison'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.text('Votre taxi arrive dans'), findsOneWidget); // titre de l'écran senior
    await tester.tap(find.text('Revenir au mode normal'));
    await tester.pump();
    expect(settings.senior, isFalse);
    expect(find.byTooltip('Carte plein écran'), findsOneWidget); // panneau normal de la course
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('mode senior après un changement de langue : retour au mode normal', (tester) async {
    phone(tester);
    await tester.pumpWidget(const TaxiMarocApp(locate: false, onboarding: false));
    await tester.pump();
    await tester.tap(find.byTooltip('Mode senior'));
    await tester.pumpAndSettle();
    langNotifier.value = 'en'; // l'accueil est reconstruit avec une nouvelle clé
    await tester.pumpAndSettle();
    expect(find.text('Back to normal mode'), findsOneWidget);
    await tester.tap(find.text('Back to normal mode'));
    await tester.pumpAndSettle();
    expect(settings.senior, isFalse);
    expect(find.text('Where to?'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    langNotifier.value = 'fr';
  });

  testWidgets('menu : Langue sous Sécurité, annonces vocales désactivées par défaut', (tester) async {
    phone(tester);
    expect(settings.voiceAnnounce, isFalse);
    await tester.pumpWidget(const TaxiMarocApp(locate: false, onboarding: false));
    await tester.pump();
    await tester.tap(find.byTooltip('Ouvrir le menu de navigation'));
    await tester.pumpAndSettle();
    final safety = tester.getTopLeft(find.text('Sécurité')).dy;
    final language = tester.getTopLeft(find.text('Langue')).dy;
    expect(language, greaterThan(safety));
    expect(language - safety, lessThan(80)); // juste en dessous
    expect(find.text('Offres personnalisées selon mes trajets'), findsNothing);
    expect(find.text('Je suis touriste'), findsNothing);

    await tester.scrollUntilVisible(find.text('Annonces vocales'), 100, scrollable: find.byType(Scrollable).last);
    final voice = find.ancestor(of: find.text('Annonces vocales'), matching: find.byType(SwitchListTile));
    expect(tester.widget<SwitchListTile>(voice).value, isFalse);

    // « Malvoyant » active les annonces vocales.
    await tester.tap(find.text('Je suis malvoyant(e)'));
    await tester.pumpAndSettle();
    expect(settings.voiceAnnounce, isTrue);
    expect(tester.widget<SwitchListTile>(voice).value, isTrue);
    await tester.pumpWidget(const SizedBox());
  });
}
