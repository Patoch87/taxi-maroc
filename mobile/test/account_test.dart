import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_maroc/main.dart';
import 'package:taxi_maroc/services/account.dart';
import 'package:taxi_maroc/services/coupons.dart';
import 'package:taxi_maroc/services/dial_codes.dart';
import 'package:taxi_maroc/services/promos.dart';
import 'package:taxi_maroc/services/settings.dart';

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() {
    settings.reset();
    accountStore.reset();
    langNotifier.value = 'fr';
  });

  test('nationalités : Maroc en premier, recherche sans accents, drapeaux', () {
    expect(countries.first.code, 'MA');
    expect(countries.first.flag, '🇲🇦');
    expect(searchCountries('espa').map((c) => c.code), ['ES']);
    expect(searchCountries('etats').map((c) => c.code), ['US']);
    expect(searchCountries('japan').single.lang, 'ja');
    expect(validPhone('+212 6 12 34 56 78'), isTrue);
    expect(validPhone('+212'), isFalse);
    expect(validEmail(''), isTrue);
    expect(validEmail('a@b'), isFalse);
    expect(newAccountId(), matches(RegExp(r'^U[A-Z0-9]{5}$')));
  });

  test('indicatifs : liste UIT complète, Maroc en premier, recherche par pays ou indicatif', () {
    expect(dialCodes.length, greaterThanOrEqualTo(240));
    expect(dialCodes.first.iso, 'MA');
    expect(dialCodes.first.code, '+212');
    expect(dialCodes.map((d) => d.iso).toSet().length, dialCodes.length); // pas de doublon
    expect(searchDialCodes('+33').map((d) => d.iso), contains('FR'));
    expect(searchDialCodes('japon').single.code, '+81');
    expect(dialCodeFor('JM').code, '+1 876');
    expect(dialCodeFor('XX').iso, 'MA');
  });

  testWidgets('indicatif choisi à la main : la nationalité ne le change plus', (tester) async {
    phone(tester);
    await tester.pumpWidget(const TaxiMarocApp(locate: false));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('dialCode')));
    await tester.pumpAndSettle();
    expect(find.text('Indicatif'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('dialSearch')), 'royaume');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('dial-GB')));
    await tester.pumpAndSettle();
    expect(find.text('+44'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('nationality')));
    await tester.tap(find.byKey(const ValueKey('nationality')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('countrySearch')), 'espa');
    await tester.pump();
    await tester.tap(find.text('Espagne'));
    await tester.pumpAndSettle();
    expect(find.text('+44'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('premier lancement : « Continuer en démo » mène à l\'accueil', (tester) async {
    phone(tester);
    await tester.pumpWidget(const TaxiMarocApp(locate: false));
    await tester.pump();
    expect(find.text('Créer un compte'), findsWidgets);
    await tester.tap(find.text('Continuer en démo'));
    await tester.pumpAndSettle();
    expect(find.text('Où allez-vous ?'), findsOneWidget);
    expect(accountStore.account, isNull);
    expect(Coupon(promo: fashionPromo, tripId: 'T1', issuedAt: DateTime(2026)).userId, demoUserId);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('création du compte : SMS simulé, nationalité obligatoire, langue proposée', (tester) async {
    phone(tester);
    await tester.pumpWidget(const TaxiMarocApp(locate: false));
    await tester.pump();
    expect(find.textContaining('jamais utilisée pour la publicité'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('firstName')), 'Lucía');
    await tester.enterText(find.byKey(const ValueKey('lastName')), 'García');
    // Indicatif : Maroc +212 par défaut, numéro local seul dans le champ.
    expect(find.text('+212'), findsOneWidget);
    expect(find.text('🇲🇦'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('phone')), '612 345 678');
    await tester.pump();

    // Sans code SMS ni nationalité : refusé.
    await tester.ensureVisible(find.byKey(const ValueKey('saveAccount')));
    await tester.tap(find.byKey(const ValueKey('saveAccount')));
    await tester.pump();
    expect(accountStore.account, isNull);
    expect(find.text('Champ obligatoire'), findsOneWidget);

    await tester.ensureVisible(find.text('Recevoir le code par SMS'));
    await tester.tap(find.text('Recevoir le code par SMS'));
    await tester.pump();
    expect(find.textContaining('SMS simulé (démo)'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('smsCode')), '0000');
    await tester.pump();
    expect(find.text('Code incorrect'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('smsCode')), demoSmsCode);
    await tester.pump();
    expect(find.text('Numéro vérifié'), findsOneWidget);

    // Nationalité : liste avec recherche, la langue espagnole est proposée.
    await tester.ensureVisible(find.byKey(const ValueKey('nationality')));
    await tester.tap(find.byKey(const ValueKey('nationality')));
    await tester.pumpAndSettle();
    expect(find.text('Maroc'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('countrySearch')), 'espa');
    await tester.pump();
    await tester.tap(find.text('Espagne'));
    await tester.pumpAndSettle();
    expect(find.text('🇪🇸  Español'), findsOneWidget);
    // L'indicatif suit la nationalité tant qu'il n'a pas été choisi à la main.
    expect(find.text('+34'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('saveAccount')));
    await tester.tap(find.byKey(const ValueKey('saveAccount')));
    await tester.pumpAndSettle();
    final a = accountStore.account!;
    expect(a.firstName, 'Lucía');
    expect(a.nationality, 'ES');
    expect(a.phone, '+34 612 345 678');
    expect(a.phoneCountry, 'ES');
    expect(langNotifier.value, 'es');
    expect(find.text('¿A dónde vas?'), findsOneWidget);
    // Les bons de réduction utilisent l'identifiant du compte créé.
    expect(Coupon(promo: fashionPromo, tripId: 'T1', issuedAt: DateTime(2026)).code, contains('-${a.id}-MODE-'));

    // « Mon compte » dans le menu : nationalité modifiable.
    await tester.tap(find.byTooltip('Abrir el menú de navegación'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mi cuenta'));
    await tester.pumpAndSettle();
    expect(find.textContaining(a.id), findsOneWidget);
    expect(find.text('Spain'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    langNotifier.value = 'fr';
  });

  test('« ?demo=1 » ouvre la démo sans inscription (version web)', () {
    expect(skipOnboardingFromUrl(Uri.parse('http://localhost:8765/?demo=1')), isTrue);
    expect(skipOnboardingFromUrl(Uri.parse('http://localhost:8765/')), isFalse);
    expect(skipOnboardingFromUrl(Uri.parse('http://localhost:8765/?demo=0')), isFalse);
  });
}
