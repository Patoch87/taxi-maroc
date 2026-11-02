import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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
}
