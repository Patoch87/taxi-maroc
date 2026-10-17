import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taxi_maroc/l10n/strings.dart';
import 'package:taxi_maroc/main.dart';
import 'package:taxi_maroc/screens/driver_home.dart';
import 'package:taxi_maroc/screens/search_screen.dart';
import 'package:taxi_maroc/services/ads.dart';
import 'package:taxi_maroc/services/coupons.dart';
import 'package:taxi_maroc/services/live.dart';
import 'package:taxi_maroc/services/places.dart';
import 'package:taxi_maroc/services/rides.dart';
import 'package:taxi_maroc/services/settings.dart';
import 'package:taxi_maroc/theme.dart';
import 'package:taxi_maroc/widgets/coupon_sheet.dart';
import 'package:taxi_maroc/widgets/promo_card.dart';

import 'rating_test.dart' show phone, rideToTheEnd;

void main() {
  setUp(() {
    settings.reset();
    live.reset();
    adCatalog.reset();
    langNotifier.value = 'fr';
    savedCoupons.clear();
    tripHistory.clear();
  });

  group('catalogue de publicités', () {
    test('un annonceur fictif par emplacement, titres courts dans les 16 langues', () {
      expect(localAds.map((a) => a.placement).toSet(), AdPlacement.values.toSet());
      for (final ad in localAds) {
        expect(ad.promo.fictive, isTrue, reason: ad.id);
        for (final lang in S.supported) {
          final t = S.strings(lang);
          expect(t[ad.promo.titleKey], isNotNull, reason: '$lang ${ad.promo.titleKey}');
          expect(t[ad.promo.titleKey]!.length, lessThanOrEqualTo(40), reason: '$lang ${ad.promo.titleKey}');
          expect(t[ad.promo.detailKey], isNotNull, reason: '$lang ${ad.promo.detailKey}');
        }
      }
      expect(localAds.where((a) => a.placement == AdPlacement.place || a.placement == AdPlacement.destination),
          everyElement(predicate<Ad>((a) => a.asPlace != null)));
    });

    test('GET /ads : seules les publicités actives sur le serveur sont affichées', () async {
      live.url = 'http://serveur';
      live.enabled = true;
      final api = LiveApi(
          client: MockClient((r) async => http.Response(
              jsonEncode([
                {'id': 'SOUK', 'emplacement': 'accueil', 'exempleFictif': true},
                {'id': 'AMAL', 'emplacement': 'destination', 'exempleFictif': true},
              ]),
              200)));
      await adCatalog.refresh(api: api);
      expect(adCatalog.ads.map((a) => a.id), ['SOUK', 'AMAL']);
      expect(adCatalog.forPlacement(AdPlacement.waiting), isNull);
    });

    test('serveur injoignable : le catalogue local reste', () async {
      live.url = 'http://serveur';
      live.enabled = true;
      await adCatalog.refresh(api: LiveApi(client: MockClient((r) async => http.Response('', 500))));
      expect(adCatalog.ads, localAds);
    });
  });

  group('serveur Render (offre gratuite) : réveil puis mode démo automatique', () {
    test('le serveur répond après quelques essais : test réel', () async {
      live.url = 'http://serveur';
      live.enabled = true;
      var calls = 0;
      final api = LiveApi(
          client: MockClient(
              (r) async => ++calls < 3 ? http.Response('', 503) : http.Response(jsonEncode({'status': 'ok'}), 200)));
      final states = <bool>[];
      void listener() => states.add(live.connecting);
      live.addListener(listener);
      final ok = await live.warmUp(api: api, every: Duration.zero);
      live.removeListener(listener);
      expect(ok, isTrue);
      expect(calls, 3);
      expect(states.first, isTrue); // « Connexion au serveur… »
      expect(live.enabled, isTrue);
      expect(live.fellBack, isFalse);
    });

    test('pas de réponse : mode démo avec l\'avis, sans erreur', () async {
      live.url = 'http://serveur';
      live.enabled = true;
      final ok = await live.warmUp(
          api: LiveApi(client: MockClient((r) async => http.Response('', 503))),
          max: Duration.zero,
          every: Duration.zero);
      expect(ok, isFalse);
      expect(live.enabled, isFalse);
      expect(live.fellBack, isTrue);
      expect(live.connecting, isFalse);
      // Le mode démo du menu peut toujours repasser sur le serveur.
      live.enabled = true;
      expect(live.fellBack, isFalse);
    });
  });

  testWidgets('accueil : bannière (logo, titre, bon), avis « Connexion au serveur… »', (tester) async {
    phone(tester);
    await tester.pumpWidget(const TaxiMarocApp(locate: false, onboarding: false));
    await tester.pump();
    expect(find.byKey(const ValueKey('homeAd')), findsOneWidget);
    expect(find.text('Publicité · exemple fictif'), findsOneWidget);
    expect(find.text('-15 % sur la nouvelle collection'), findsOneWidget);
    await tester.tap(find.text('-15 % sur la nouvelle collection'));
    await tester.pumpAndSettle();
    expect(find.byType(CouponView), findsOneWidget);
    expect(tester.widget<SelectableText>(find.byType(SelectableText)).data, startsWith('TM-$demoUserId-SOUK-'));
    Navigator.of(tester.element(find.byType(CouponView))).pop();
    await tester.pumpAndSettle();
    await tester.tap(
        find.descendant(of: find.byKey(const ValueKey('homeAd')), matching: find.byTooltip('Masquer la publicité')));
    await tester.pump();
    expect(find.byKey(const ValueKey('homeAd')), findsNothing);

    // Réveil du serveur puis repli en mode démo : avis discret au lieu d'une erreur.
    live.url = 'http://serveur';
    live.enabled = true;
    final answer = Completer<http.Response>();
    final waking =
        live.warmUp(api: LiveApi(client: MockClient((r) => answer.future)), max: Duration.zero, every: Duration.zero);
    await tester.pump();
    expect(find.text('Connexion au serveur…'), findsOneWidget);
    answer.complete(http.Response('', 503));
    await tester.runAsync(() => waking);
    await tester.pump();
    expect(find.text('Mode démo (serveur indisponible)'), findsOneWidget);
    live.dismissFallback();
    await tester.pump();
    expect(find.byKey(const ValueKey('serverNotice')), findsNothing);
  });

  testWidgets('recherche : une destination sponsorisée parmi les premières suggestions', (tester) async {
    phone(tester);
    Place? chosen;
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      home: Builder(
        builder: (ctx) => TextButton(
          onPressed: () async =>
              chosen = await Navigator.push<Place>(ctx, MaterialPageRoute(builder: (_) => const SearchScreen())),
          child: const Text('ouvrir'),
        ),
      ),
    ));
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sponsoredDestination')), findsOneWidget);
    expect(find.text('Sponsorisé'), findsOneWidget);
    expect(find.text('Pharmacie Al Amal'), findsOneWidget);
    await tester.tap(find.text('Pharmacie Al Amal'));
    await tester.pumpAndSettle();
    expect(chosen?.name, 'Pharmacie Al Amal');
  });

  testWidgets('attente du chauffeur, course (QR) et reçu : bon enregistré dans « Mes offres »', (tester) async {
    phone(tester);
    await tester.pumpWidget(const TaxiMarocApp(locate: false, onboarding: false));
    await tester.pump();
    await tester.tap(find.text('Gare Casa Voyageurs'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.textContaining('Commander ·'));
    await tester.tap(find.textContaining('Commander ·'));
    await tester.pump();
    expect(find.byKey(const ValueKey('waitingAd')), findsOneWidget);
    expect(find.text('20 Go d\'internet pour 49 DH'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());

    await tester.pumpWidget(const TaxiMarocApp(locate: false, onboarding: false));
    await tester.pump();
    await rideToTheEnd(tester);
    expect(find.byKey(const ValueKey('receiptAd')), findsOneWidget);
    expect(find.text('Bon ajouté à Mes offres'), findsOneWidget);
    expect(savedCoupons.where((c) => c.promo.id == 'ATLASBON'), hasLength(1));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('menu : « Offres personnalisées » désactivables ; jamais de publicité côté chauffeur', (tester) async {
    phone(tester);
    await tester.pumpWidget(const TaxiMarocApp(locate: false, onboarding: false));
    await tester.pump();
    await tester.tap(find.byTooltip('Ouvrir le menu de navigation'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const ValueKey('personalizedOffers')), 100,
        scrollable: find.descendant(of: find.byType(Drawer), matching: find.byType(Scrollable)));
    await tester.ensureVisible(find.byKey(const ValueKey('personalizedOffers')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('personalizedOffers')));
    await tester.pump();
    expect(settings.personalizedOffers, isFalse);

    await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: const DriverHome()));
    await tester.pump();
    expect(find.byType(PromoCard), findsNothing);
    expect(find.byType(AdBanner), findsNothing);
    expect(find.byType(AdQrCard), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
