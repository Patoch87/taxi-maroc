import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_maroc/screens/driver_home.dart';
import 'package:taxi_maroc/services/places.dart';
import 'package:taxi_maroc/services/request_chime.dart';
import 'package:taxi_maroc/services/settings.dart';
import 'package:taxi_maroc/theme.dart';

void main() {
  setUp(() {
    settings.reset();
    sosActive = false;
  });

  test('son des demandes : une seule fois par nouvelle demande, jamais si désactivé ou pendant un SOS', () {
    var sounds = 0, haptics = 0;
    final chime = RequestChime(play: () async => sounds++, haptic: () async => haptics++);
    final a = Object(), b = Object(), c = Object(), d = Object();

    expect(chime.onRequest(null, enabled: true), isFalse);
    expect(chime.onRequest(a, enabled: true), isTrue);
    expect(chime.onRequest(a, enabled: true), isFalse); // même demande : pas de deuxième son
    expect(chime.onRequest(b, enabled: true), isTrue);
    expect(chime.onRequest(c, enabled: false), isFalse); // réglage désactivé
    sosActive = true;
    expect(chime.onRequest(d, enabled: true), isFalse); // SOS en cours
    expect(sounds, 2);
    expect(haptics, 2);
  });

  test('taxi vide : destination lue en arabe une fois ; avec passagers, le son seulement', () async {
    var sounds = 0, stops = 0;
    final spoken = <String>[];
    final chime = RequestChime(
      play: () async => sounds++,
      haptic: () async {},
      speak: (text) async => spoken.add(text),
      stopSpeech: () async => stops++,
      speechDelay: Duration.zero,
    );
    final text = requestAnnouncementAr(arabicPlaceName('Morocco Mall'));
    expect(text, 'طلب جديد، الوجهة: موروكو مول');
    expect(arabicPlaceName('Borne Anfa'), 'Borne Anfa'); // pas de nom arabe : nom français

    final a = Object(), b = Object(), c = Object(), d = Object();
    chime.onRequest(a, enabled: true, voice: true, empty: true, speakText: text);
    chime.onRequest(a, enabled: true, voice: true, empty: true, speakText: text); // une seule fois
    await Future<void>.delayed(Duration.zero);
    expect(spoken, [text]);

    chime.onRequest(b, enabled: true, voice: true, empty: false, speakText: text); // passagers à bord
    chime.onRequest(c, enabled: true, voice: false, empty: true, speakText: text); // annonce désactivée
    chime.onRequest(d, enabled: false, voice: true, empty: true, speakText: text); // son des demandes coupé
    await Future<void>.delayed(Duration.zero);
    expect(spoken, [text]);
    expect(sounds, 3);

    // Demande acceptée ou refusée avant la voix : rien n'est lu, la voix est arrêtée.
    final slow = RequestChime(
      play: () async {},
      haptic: () async {},
      speak: (t) async => spoken.add(t),
      stopSpeech: () async => stops++,
      speechDelay: const Duration(milliseconds: 20),
    );
    slow.onRequest(Object(), enabled: true, voice: true, empty: true, speakText: 'x');
    slow.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(spoken, isNot(contains('x')));
    expect(stops, 1);
  });

  test('feux de détresse : rappel une seule fois quand le taxi passe à 50 m ou moins', () {
    final alerts = PickupAlerts();
    final rider = Object(), other = Object();
    expect(alerts.check(rider, 120), isFalse);
    expect(alerts.check(rider, 50.5), isFalse);
    expect(alerts.check(rider, 50), isTrue);
    expect(alerts.check(rider, 30), isFalse); // pas répété
    expect(alerts.check(rider, 10), isFalse);
    expect(alerts.check(other, 45), isTrue); // autre prise en charge
  });

  test('le son est activé par défaut, et le fichier fait moins d\'une seconde', () {
    expect(settings.requestSound, isTrue);
    final bytes = File('assets/sounds/request_chime.wav').readAsBytesSync();
    final data = ByteData.sublistView(bytes);
    final rate = data.getUint32(24, Endian.little);
    final byteRate = data.getUint32(28, Endian.little);
    expect(rate, 22050);
    expect((bytes.length - 44) / byteRate, lessThan(1));
  });

  testWidgets('menu chauffeur : son des demandes activé, annonce vocale en option', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: const DriverHome()));
    await tester.pump();
    await tester.tap(find.byTooltip('Réglages chauffeur'));
    await tester.pumpAndSettle();
    expect(find.text('Son des demandes'), findsOneWidget);
    expect(find.text('Annonce vocale de la destination'), findsOneWidget);
    // L'annonce vocale est une option : désactivée tant que le chauffeur ne l'active pas.
    expect(settings.requestVoice, isFalse);
    await tester.tap(find.text('Annonce vocale de la destination'));
    await tester.pump();
    expect(settings.requestVoice, isTrue);
    await tester.tap(find.text('Son des demandes'));
    await tester.pump();
    expect(settings.requestSound, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('en conduisant : rappel des feux de détresse à l\'approche du passager, puis il disparaît seul',
      (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    settings.requestSound = false; // pas de son dans le test
    await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: const DriverHome()));
    await tester.pump();
    await tester.tap(find.text('Commencer le service'));
    var shown = false;
    for (var i = 0; i < 1500 && !shown; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('Accepter').evaluate().isNotEmpty) await tester.tap(find.text('Accepter'), warnIfMissed: false);
      shown = find.byKey(const ValueKey('hazardBanner')).evaluate().isNotEmpty;
    }
    expect(shown, isTrue);
    expect(find.text('Allumez vos feux de détresse'), findsOneWidget);
    await tester.pump(const Duration(seconds: 7));
    expect(find.byKey(const ValueKey('hazardBanner')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
