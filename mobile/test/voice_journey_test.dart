import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_maroc/main.dart';
import 'package:taxi_maroc/services/rides.dart';
import 'package:taxi_maroc/services/settings.dart';
import 'package:taxi_maroc/services/voice_intents.dart';

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

String prompt(WidgetTester tester) => tester.widget<Text>(find.byKey(const ValueKey('voicePrompt'))).data!;

/// Répond comme le ferait le passager en touchant une réponse proposée (sans micro dans les tests).
Future<void> answer(WidgetTester tester, String value) async {
  await tester.ensureVisible(find.byKey(ValueKey('vj-$value')));
  await tester.tap(find.byKey(ValueKey('vj-$value')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    settings.reset();
    langNotifier.value = 'fr';
    tripHistory.clear();
  });

  test('réponses dites : oui, non, taxi, paiement, urgence, en français, arabe, darija et anglais', () {
    Set<VoiceIntent> it(String said) => voiceIntents(said);
    expect(it('oui'), contains(VoiceIntent.yes));
    expect(it("Oui, c'est ça"), contains(VoiceIntent.yes));
    expect(it('واخا'), contains(VoiceIntent.yes));
    expect(it('yes please'), contains(VoiceIntent.yes));
    expect(it('non'), contains(VoiceIntent.no));
    expect(it('لا'), contains(VoiceIntent.no));
    expect(it('la'), contains(VoiceIntent.no));
    expect(it('la gare'), isNot(contains(VoiceIntent.no)));
    expect(it('un taxi partagé'), contains(VoiceIntent.shared));
    expect(it('je veux être seul'), contains(VoiceIntent.alone));
    expect(it('بوحدي'), contains(VoiceIntent.alone));
    expect(it('premium'), contains(VoiceIntent.premium));
    expect(it('en espèces'), contains(VoiceIntent.cash));
    expect(it('كاش'), contains(VoiceIntent.cash));
    expect(it('par carte'), contains(VoiceIntent.card));
    expect(it('où est mon taxi'), contains(VoiceIntent.where));
    expect(it('فين الطاكسي'), contains(VoiceIntent.where));
    expect(it('appelle le chauffeur'), contains(VoiceIntent.call));
    expect(it('partager mon trajet'), {VoiceIntent.share});
    expect(it('au secours'), contains(VoiceIntent.sos));
    expect(it('aidez-moi'), {VoiceIntent.sos});
    expect(it('عتقوني'), contains(VoiceIntent.sos));
    expect(it('annuler'), contains(VoiceIntent.cancel));
    expect(it('non merci'), {VoiceIntent.skip});
    expect(it('bonjour'), isEmpty);
  });

  test('nombres dits : note et pourboire', () {
    expect(spokenNumber('5 étoiles'), 5);
    expect(spokenNumber('quatre'), 4);
    expect(spokenNumber('ربعة'), 4);
    expect(spokenNumber('khamsa'), 5);
    expect(spokenNumber('3achra dirhams'), 10);
    expect(spokenNumber('20 dirhams'), 20);
    expect(spokenNumber('٢٠'), 20);
    expect(spokenNumber('vingt dirhams'), 20);
    expect(spokenNumber('rien'), isNull);
  });

  testWidgets('parcours 100 % vocal : destination, taxi, paiement, confirmation, suivi, note et pourboire',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(const TaxiMarocApp(locate: false, onboarding: false));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('voiceJourneyStart')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('voiceJourney')), findsOneWidget);
    expect(prompt(tester), contains('Où voulez-vous aller ?'));
    // Pas de voix ni de micro dans les tests : après la question, les réponses se touchent.
    await tester.pump(const Duration(seconds: 35));
    await tester.pumpAndSettle();
    expect(find.text('Micro indisponible : touchez une réponse'), findsOneWidget);

    await answer(tester, 'Maison');
    expect(prompt(tester), 'Vous allez à Maison. C\'est bien ça ?');
    await answer(tester, 'oui');

    // Choix du taxi : les trois prix sont lus, seulement le total.
    expect(prompt(tester), contains('Taxi premium : '));
    expect(prompt(tester), contains(' dirhams'));
    expect(prompt(tester), contains('Quel taxi voulez-vous ?'));
    await answer(tester, 'opt:seul');
    expect(prompt(tester), 'Vous payez en espèces ou par carte ?');
    await answer(tester, 'carte');
    expect(prompt(tester), startsWith('Je résume : '));
    expect(prompt(tester), contains('carte bancaire'));
    await answer(tester, 'oui');

    // Recherche du taxi, puis suivi : « Où est mon taxi ? » donne la plaque et les minutes.
    expect(prompt(tester), contains('Je cherche un taxi sur votre route'));
    for (var i = 0; i < 20 && find.byKey(const ValueKey('vj-où est')).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.byKey(const ValueKey('vj-où est')), findsOneWidget);
    expect(find.byKey(const ValueKey('vj-annuler')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('vj-où est')));
    await tester.tap(find.byKey(const ValueKey('vj-où est')));
    await tester.pump();

    // Le chauffeur démarre la course, puis arrivée : note et pourboire à la voix.
    for (var i = 0; i < 1500 && find.byKey(const ValueKey('vj-5')).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(prompt(tester), contains('Vous êtes arrivé'));
    expect(prompt(tester), contains('de 1 à 5'));
    await answer(tester, '5');
    expect(prompt(tester), contains('pourboire'));
    await answer(tester, '10');

    // Course enregistrée, mode vocal terminé (lancé pour une course).
    expect(tripHistory.first.rating, 5);
    expect(tripHistory.first.tip, 10);
    expect(tripHistory.first.destination, 'Maison');
    expect(find.byKey(const ValueKey('voiceJourney')), findsNothing);
    expect(find.text('Où allez-vous ?'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('parcours vocal : « Quitter » et « annuler » ramènent à l\'écran normal', (tester) async {
    phone(tester);
    await tester.pumpWidget(const TaxiMarocApp(locate: false, onboarding: false));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('voiceJourneyStart')));
    await tester.pumpAndSettle();
    await answer(tester, 'annuler');
    expect(find.byKey(const ValueKey('voiceJourney')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('voiceJourneyStart')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('voiceJourneyClose')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('voiceJourney')), findsNothing);
    expect(find.text('Où allez-vous ?'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
  });
}
