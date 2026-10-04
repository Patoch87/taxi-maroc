import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_maroc/main.dart';
import 'package:taxi_maroc/screens/complaint_screen.dart';
import 'package:taxi_maroc/screens/history_screen.dart';
import 'package:taxi_maroc/services/rides.dart';
import 'package:taxi_maroc/services/settings.dart';
import 'package:taxi_maroc/widgets/driver_card.dart';

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Commande un taxi pour la gare, monte à bord et accélère jusqu'à l'arrivée.
Future<void> rideToTheEnd(WidgetTester tester) async {
  await tester.tap(find.text('Gare Casa Voyageurs'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.textContaining('Commander ·'));
  await tester.tap(find.textContaining('Commander ·'));
  for (var i = 0; i < 100 && find.text('Je suis dans le taxi').evaluate().isEmpty; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
  await tester.ensureVisible(find.text('Je suis dans le taxi'));
  await tester.tap(find.text('Je suis dans le taxi'));
  await tester.pump();
  // Démo : ×1 → ×2 → ×3 → ×4, la vitesse est affichée sur le bouton.
  for (final x in [2, 3, 4]) {
    await tester.ensureVisible(find.textContaining('Accélérer (démo)'));
    await tester.tap(find.textContaining('Accélérer (démo)'));
    await tester.pump();
    expect(find.text('Accélérer (démo) ×$x'), findsOneWidget);
  }
  for (var i = 0; i < 200 && find.text('Vous êtes arrivé 🎉').evaluate().isEmpty; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
  expect(find.text('Vous êtes arrivé 🎉'), findsOneWidget);
}

void main() {
  setUp(() {
    settings.reset();
    langNotifier.value = 'fr';
    tripHistory.clear();
  });

  testWidgets('fin de course : note, avis rapides, commentaire, pourboire par carte, historique', (tester) async {
    phone(tester);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(const TaxiMarocApp(locate: false, onboarding: false));
    await tester.pump();
    await rideToTheEnd(tester);

    // Vraie photo du chauffeur (fichier de l'application).
    final photo = tester.widget<Image>(find.descendant(of: find.byType(DriverPhoto), matching: find.byType(Image)));
    expect(photo.image, isA<AssetImage>());

    expect(find.bySemanticsLabel('5 étoiles sur 5'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('5 étoiles sur 5'));
    await tester.tap(find.byTooltip('5 étoiles sur 5'));
    await tester.pump();
    expect(find.text('Ponctuel'), findsOneWidget);
    expect(find.text('Retard'), findsNothing);
    await tester.ensureVisible(find.text('Ponctuel'));
    await tester.tap(find.text('Ponctuel'));
    await tester.tap(find.text('Propre'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Très bon chauffeur');

    await tester.ensureVisible(find.text('10 DH'));
    await tester.tap(find.text('10 DH'));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('sendReview')));
    await tester.tap(find.byKey(const ValueKey('sendReview')));
    await tester.pumpAndSettle();

    // Paiement simulé : carte enregistrée, ou nouvelle carte vérifiée au format.
    expect(find.text('Paiement simulé (démo)'), findsOneWidget);
    expect(find.text('Visa •••• 4242'), findsOneWidget);
    await tester.tap(find.text('Ajouter une carte'));
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('cardNumber')), '1234');
    await tester.tap(find.text('Payer 10 DH'));
    await tester.pump();
    expect(find.text('Numéro de carte invalide'), findsOneWidget);
    expect(find.text('CVC invalide'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('cardNumber')), '4242 4242 4242 4242');
    await tester.enterText(find.byKey(const ValueKey('cardExpiry')), '12/39');
    await tester.enterText(find.byKey(const ValueKey('cardCvc')), '123');
    await tester.tap(find.text('Payer 10 DH'));
    await tester.pumpAndSettle();

    expect(find.text('Merci ! Votre avis a été envoyé.'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    final trip = tripHistory.first;
    expect(trip.rating, 5);
    expect(trip.tip, 10);
    expect(trip.tags, ['Ponctuel', 'Propre']);
    expect(trip.comment, 'Très bon chauffeur');

    await tester.pumpWidget(MaterialApp(home: const HistoryScreen()));
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(5));
    expect(find.text('Pourboire : 10 DH'), findsOneWidget);
    semantics.dispose();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('mauvaise note : avis négatifs, raccourci vers la réclamation, autre montant', (tester) async {
    phone(tester);
    await tester.pumpWidget(const TaxiMarocApp(locate: false, onboarding: false));
    await tester.pump();
    await rideToTheEnd(tester);

    await tester.ensureVisible(find.byTooltip('2 étoiles sur 5'));
    await tester.tap(find.byTooltip('2 étoiles sur 5'));
    await tester.pump();
    expect(find.text('Conduite brusque'), findsOneWidget);
    expect(find.text('Ponctuel'), findsNothing);

    await tester.ensureVisible(find.text('Autre montant'));
    await tester.tap(find.text('Autre montant'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('otherTipField')), '15');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('15 DH'), findsOneWidget);

    await tester.ensureVisible(find.text('Un problème pendant la course ? Faire une réclamation'));
    await tester.tap(find.text('Un problème pendant la course ? Faire une réclamation'));
    await tester.pumpAndSettle();
    expect(find.byType(ComplaintScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
