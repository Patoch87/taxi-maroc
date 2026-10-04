import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_maroc/main.dart';
import 'package:taxi_maroc/services/account.dart';
import 'package:taxi_maroc/services/coupons.dart';
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
    await tester.enterText(find.byKey(const ValueKey('phone')), '+34 612 345 678');
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

    await tester.ensureVisible(find.byKey(const ValueKey('saveAccount')));
    await tester.tap(find.byKey(const ValueKey('saveAccount')));
    await tester.pumpAndSettle();
    final a = accountStore.account!;
    expect(a.firstName, 'Lucía');
    expect(a.nationality, 'ES');
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
}
