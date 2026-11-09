import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:taxi_maroc/main.dart';
import 'package:taxi_maroc/screens/driver_home.dart';
import 'package:taxi_maroc/services/live.dart';
import 'package:taxi_maroc/services/settings.dart';
import 'package:taxi_maroc/theme.dart';
import 'package:taxi_maroc/widgets/roadside_help.dart';

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Le taxi de la démo roule (minuteur de 100 ms) : on avance le temps au lieu d'attendre la fin des animations.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> openMenu(WidgetTester tester) async {
  tester.state<ScaffoldState>(find.byType(Scaffold).first).openEndDrawer();
  await settle(tester);
}

void main() {
  setUp(() {
    settings.reset();
    settings.requestSound = false;
    langNotifier.value = 'fr';
    DriverHome.requestGap = const Duration(hours: 1);
  });
  tearDown(() => DriverHome.requestGap = const Duration(seconds: 7));

  testWidgets('panne : le chauffeur appelle les taxis proches, voit qui arrive, puis « Problème réglé »',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: const DriverHome()));
    await tester.pump();
    await tester.tap(find.text('Commencer le service'));
    await tester.pump(const Duration(milliseconds: 300));

    await openMenu(tester);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('helpDrawer')), 200,
        scrollable: find.descendant(of: find.byType(Drawer), matching: find.byType(Scrollable)).first);
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('helpDrawer')));
    await settle(tester);
    expect(find.text('Que se passe-t-il ?'), findsOneWidget);
    // Rien de choisi : on ne peut pas encore appeler.
    expect(tester.widget<ButtonStyleButton>(find.byKey(const ValueKey('helpSend'))).onPressed, isNull);

    // Accident : les numéros des secours apparaissent.
    await tester.tap(find.byKey(const ValueKey('helpAccident')));
    await tester.pump();
    expect(find.text('Ambulance · 15'), findsOneWidget);
    expect(find.text('Police · 19'), findsOneWidget);
    expect(find.text('Gendarmerie · 177'), findsOneWidget);

    // Finalement une panne.
    await tester.tap(find.byKey(const ValueKey('helpBreakdown')));
    await tester.pump();
    expect(find.text('Ambulance · 15'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('helpSend')));
    await settle(tester);

    expect(find.byKey(const ValueKey('helpCallCard')), findsOneWidget);
    expect(find.text('Appel envoyé · Panne'), findsOneWidget);
    expect(find.textContaining('chauffeurs Bab Taxi prévenus autour de vous'), findsOneWidget);
    expect(find.text('En attente de réponse…'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(find.textContaining('Youssef (41237 | أ | 6) arrive pour vous aider'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('helpSolved')));
    await tester.pump();
    expect(find.byKey(const ValueKey('helpCallCard')), findsNothing);
    expect(find.byKey(const ValueKey('helpButton')), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('un collègue en panne : carte d\'alerte, « Je prends les passagers », bandeau « Vous allez aider »',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: const DriverHome()));
    await tester.pump();
    await tester.tap(find.text('Commencer le service'));
    await tester.pump(const Duration(milliseconds: 300));

    await openMenu(tester);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('helpDemoIncoming')), 200,
        scrollable: find.descendant(of: find.byType(Drawer), matching: find.byType(Scrollable)).first);
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('helpDemoIncoming')));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const ValueKey('helpAlertCard')), findsOneWidget);
    expect(find.text("Un collègue a besoin d'aide"), findsOneWidget);
    expect(find.text('Hamid · 28451 | ب | 6'), findsOneWidget);
    expect(find.textContaining('passager(s) à reprendre'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('helpTake')));
    await tester.pump();
    expect(find.byKey(const ValueKey('helpAlertCard')), findsNothing);
    expect(find.byKey(const ValueKey('helpGoingBanner')), findsOneWidget);
    expect(find.text('Vous allez aider Hamid'), findsOneWidget);
    expect(find.text('Passagers repris : allez les chercher au taxi en panne'), findsOneWidget);

    // « Je ne peux plus » : le bandeau disparaît.
    await tester.tap(find.byKey(const ValueKey('helpCancelGoing')));
    await tester.pump();
    expect(find.byKey(const ValueKey('helpGoingBanner')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  });

  test('distance affichée', () {
    expect(helpDistance(430), '430 m');
    expect(helpDistance(1240), '1,2 km');
  });

  group('serveur', () {
    setUp(() {
      live.reset();
      live.url = 'https://serveur.test';
    });

    test('appel, appels proches, reprise des passagers et course relayée', () async {
      final sent = <String>[];
      final api = LiveApi(
        client: MockClient((r) async {
          sent.add('${r.method} ${r.url.path}${r.url.hasQuery ? '?${r.url.query}' : ''}');
          final alerte = {
            'id': 'A1',
            'taxiId': 'T-HAMID',
            'nom': 'Hamid',
            'plaque': '28451',
            'motif': 'accident',
            'blesses': true,
            'position': {'lat': 33.58, 'lng': -7.62},
            'statut': 'ouverte',
            'passagers': 2,
            'destinations': ['Maarif'],
            'prevenus': 3,
            'reponses': [
              {'taxiId': 'T-Y', 'nom': 'Youssef', 'action': 'reprend', 'le': '2026-11-09T15:00:00Z'}
            ],
            'reprisePar': 'T-Y',
            'coursesReprises': ['C1'],
            'distanceM': 850,
          };
          if (r.url.path == '/assistance/proches') return http.Response(jsonEncode([alerte]), 200);
          if (r.url.path == '/assistance/A1/reponse') {
            return http.Response(
                jsonEncode({
                  'alerte': alerte,
                  'courses': [
                    {
                      'id': 'C1',
                      'statut': 'acceptee',
                      'demande': {
                        'depart': {'lat': 33.58, 'lng': -7.62},
                        'destination': {'lat': 33.59, 'lng': -7.63},
                        'destinationNom': 'Maarif',
                        'passager': {'nom': 'Salma'},
                        'passagers': 2,
                        'prixMad': 18,
                      },
                    }
                  ],
                }),
                201);
          }
          if (r.url.path == '/rides/requests/C1') {
            return http.Response(
                jsonEncode({
                  'id': 'C1',
                  'statut': 'acceptee',
                  'proposeeA': [],
                  'relais': {'deTaxi': 'T-HAMID', 'deNom': 'Hamid', 'motif': 'panne', 'etaitABord': true},
                }),
                200);
          }
          return http.Response(jsonEncode(alerte), 201);
        }),
      );

      final a = await api.callForHelp(position: const LatLng(33.58, -7.62), accident: true, injured: true);
      expect(a.accident, isTrue);
      expect(a.injured, isTrue);
      expect(sent.last, 'POST /assistance');

      final near = await api.nearbyHelp(const LatLng(33.57, -7.61));
      expect(near.single.distanceM, 850);
      expect(near.single.replies.single.takesRiders, isTrue);
      expect(near.single.takenRides, ['C1']);

      final rides = await api.answerHelp('A1', takeRiders: true);
      expect(rides.single.riderName, 'Salma');
      expect(rides.single.seats, 2);
      expect(rides.single.pickup, const LatLng(33.58, -7.62));

      final ride = await api.ride('C1');
      expect(ride.relayFrom, 'Hamid');
      expect(ride.relayReason, 'panne');
    });
  });
}
