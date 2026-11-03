import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taxi_maroc/main.dart';
import 'package:taxi_maroc/screens/account_screen.dart';
import 'package:taxi_maroc/services/account.dart';
import 'package:taxi_maroc/services/live.dart';
import 'package:taxi_maroc/services/phone_code.dart';

/// Test réel : vrai code SMS, commande WhatsApp et espèces seulement tant que la carte n'est pas branchée.
void main() {
  tearDown(() {
    live.reset();
    serverConfig.value = const ServerConfig();
  });

  void serverOn() {
    live.url = 'https://serveur.test';
    live.enabled = true;
  }

  test('démo : code affiché, vérifié sur le téléphone', () async {
    live.enabled = false;
    final v = PhoneCodeVerifier();
    final c = await v.send('+212 612345678');
    expect(c.testCode, demoSmsCode);
    expect(await v.check('0000'), isFalse);
    expect(v.wrong, isTrue);
    expect(await v.check(demoSmsCode), isTrue);
  });

  test('test réel : SMS envoyé par le serveur, code vérifié par le serveur une seule fois par saisie', () async {
    serverOn();
    final appels = <String>[];
    final api = LiveApi(
      client: MockClient((r) async {
        appels.add('${r.url.path} ${r.body}');
        if (r.url.path == '/auth/code') return http.Response(jsonEncode({'mode': 'sms', 'longueur': 6}), 200);
        final code = (jsonDecode(r.body) as Map)['code'];
        return http.Response(jsonEncode({'ok': code == '482910'}), 200);
      }),
    );
    final v = PhoneCodeVerifier(api: api);
    final c = await v.send('+212 612345678');
    expect(c.realSms, isTrue);
    expect(c.testCode, isNull);
    // Code incomplet : rien n'est envoyé au serveur (Twilio limite le nombre d'essais).
    expect(await v.check('4829'), isFalse);
    expect(v.wrong, isFalse);
    expect(await v.check('482911'), isFalse);
    expect(await v.check('482911'), isFalse);
    expect(await v.check('482910'), isTrue);
    expect(appels.where((a) => a.startsWith('/auth/verify')), hasLength(2));
  });

  test("application de déploiement : jamais de bascule en démo quand le serveur tarde", () async {
    live.url = 'https://serveur.test';
    live.enabled = true;
    live.production = true;
    var essais = 0;
    final api = LiveApi(
      client: MockClient((r) async {
        essais++;
        return essais < 4 ? http.Response('', 503) : http.Response(jsonEncode({'status': 'ok'}), 200);
      }),
    );
    // Même après le délai maximal, l'application continue d'essayer au lieu de passer en démo.
    final attente = live.warmUp(api: api, max: Duration.zero, every: const Duration(milliseconds: 1));
    expect(live.enabled, isTrue, reason: 'le serveur reste utilisé pendant le réveil');
    expect(await attente, isTrue);
    expect(essais, 4);
    expect(live.fellBack, isFalse);
  });

  test('numéro marocain : 9 chiffres après +212, avec ou sans le 0', () {
    for (final ok in ['612345678', '0612345678', '06 61 39 26 81', '0522-000000']) {
      expect(validLocalNumber(ok, dial: '+212'), isTrue, reason: ok);
    }
    for (final ko in ['066784787', '66784787', '06123456789', '0812345678']) {
      expect(validLocalNumber(ko, dial: '+212'), isFalse, reason: ko);
    }
    expect(validLocalNumber('612345678', dial: '+34'), isTrue);
  });

  test('configuration : bouton WhatsApp et carte bancaire', () {
    // Démo : carte simulée proposée, pas de WhatsApp.
    live.enabled = false;
    expect(cardPaymentAvailable, isTrue);
    expect(whatsappOrderLink('Bonjour'), isNull);

    serverOn();
    serverConfig.value = ServerConfig.fromJson({'whatsapp': '212 522-000000', 'sms': 'sms', 'carte': false});
    expect(cardPaymentAvailable, isFalse);
    expect(whatsappOrderLink('Bonjour Bab Taxi').toString(), 'https://wa.me/212522000000?text=Bonjour%20Bab%20Taxi');

    serverConfig.value = ServerConfig.fromJson({'whatsapp': null, 'carte': true});
    expect(cardPaymentAvailable, isTrue);
    expect(whatsappOrderLink('x'), isNull);
  });

  test('compte rendu par le serveur : numéro, indicatif et nationalité', () {
    final a = Account.fromServer(
        {'id': 'UAB12C', 'telephone': '212612345678', 'prenom': 'Salma', 'nom': 'B', 'nationalite': 'MA'})!;
    expect(a.phone, '+212 612345678');
    expect(a.phoneCountry, 'MA');
    expect(a.firstName, 'Salma');
    final f =
        Account.fromServer({'id': 'UFR', 'telephone': '33612345678', 'prenom': 'Paul', 'nom': 'D', 'nationalite': ''})!;
    expect(f.phone, '+33 612345678');
    expect(f.nationality, 'FR');
    expect(Account.fromServer(null), isNull);
  });

  testWidgets("« J'ai déjà un compte » : numéro, code, puis le compte du serveur est repris", (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    accountStore.reset();
    langNotifier.value = 'fr';
    serverOn();
    final api = LiveApi(
      client: MockClient((r) async {
        if (r.url.path == '/auth/code') {
          return http.Response(jsonEncode({'mode': 'test', 'longueur': 4, 'codeTest': '1234'}), 200);
        }
        final b = jsonDecode(r.body) as Map;
        final ok = b['code'] == '1234';
        final connu = (b['phone'] as String).replaceAll(' ', '').contains('612345678');
        return http.Response(
            jsonEncode({
              'ok': ok,
              'compte': ok && connu
                  ? {
                      'id': 'UAB12C',
                      'telephone': '212612345678',
                      'prenom': 'Salma',
                      'nom': 'B',
                      'nationalite': 'MA',
                      'langue': 'fr'
                    }
                  : null,
            }),
            200);
      }),
    );
    Future<void> settle() async {
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
    }

    Future<void> login(String number) async {
      await tester.pumpWidget(MaterialApp(home: AccountScreen(key: UniqueKey(), firstLaunch: true, codeApi: api)));
      await tester.tap(find.byKey(const ValueKey('loginToggle')));
      await tester.pump();
      expect(find.byKey(const ValueKey('firstName')), findsNothing);
      expect(find.text('Se connecter'), findsWidgets);
      await tester.enterText(find.byKey(const ValueKey('phone')), number);
      await tester.pump();
      await tester.tap(find.text('Recevoir le code par SMS'));
      await settle();
      await tester.enterText(find.byKey(const ValueKey('smsCode')), '1234');
      await settle();
    }

    await login('612 345 678');
    expect(accountStore.account?.id, 'UAB12C');
    expect(accountStore.account?.phone, '+212 612345678');

    // Depuis « Créer un compte », un numéro connu connecte aussi directement (comme Uber).
    accountStore.reset();
    await tester.pumpWidget(MaterialApp(home: AccountScreen(key: UniqueKey(), firstLaunch: true, codeApi: api)));
    await tester.enterText(find.byKey(const ValueKey('phone')), '612 345 678');
    await tester.pump();
    await tester.ensureVisible(find.text('Recevoir le code par SMS'));
    await tester.tap(find.text('Recevoir le code par SMS'));
    await settle();
    await tester.enterText(find.byKey(const ValueKey('smsCode')), '1234');
    await settle();
    expect(accountStore.account?.id, 'UAB12C');

    // Numéro sans compte : passage à la création, numéro déjà vérifié.
    accountStore.reset();
    await login('612 345 699');
    expect(accountStore.account, isNull);
    expect(find.byKey(const ValueKey('noAccountForPhone')), findsOneWidget);
    expect(find.byKey(const ValueKey('firstName')), findsOneWidget);
    expect(find.text('Numéro vérifié'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
