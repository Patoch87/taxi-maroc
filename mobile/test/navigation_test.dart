import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:taxi_maroc/screens/driver_home.dart';
import 'package:taxi_maroc/services/navigation_apps.dart';
import 'package:taxi_maroc/services/settings.dart';
import 'package:taxi_maroc/theme.dart';

void main() {
  const p = LatLng(33.5731, -7.5898);
  final opened = <(Uri, bool)>[];
  var installed = <String>{};

  tearDown(() => DriverHome.requestGap = const Duration(seconds: 7));
  setUp(() {
    settings.reset();
    opened.clear();
    DriverHome.requestGap = Duration.zero;
    installed = {};
    urlOpener = (uri, {required appOnly}) async {
      opened.add((uri, appOnly));
      return !appOnly || installed.contains(uri.scheme);
    };
  });

  test('liens Waze et Google Maps vers le point, voiture', () {
    expect(wazeUri(p).toString(), 'https://waze.com/ul?ll=33.573100,-7.589800&navigate=yes');
    expect(googleNavigationUri(p).toString(), 'google.navigation:q=33.573100,-7.589800&mode=d');
    expect(googleMapsWebUri(p).toString(),
        'https://www.google.com/maps/dir/?api=1&destination=33.573100,-7.589800&travelmode=driving');
    expect(googleMapsIosUri(p).toString(), 'comgooglemaps://?daddr=33.573100,-7.589800&directionsmode=driving');
    final android = navigationLinks(NavApp.googleMaps, p, platform: TargetPlatform.android);
    expect(android.app.single.scheme, 'google.navigation');
    final ios = navigationLinks(NavApp.googleMaps, p, platform: TargetPlatform.iOS);
    expect(ios.app.single.scheme, 'comgooglemaps');
    final waze = navigationLinks(NavApp.waze, p, platform: TargetPlatform.android);
    expect(waze.app.map((u) => u.scheme), ['https', 'waze']);
    expect(waze.store.toString(), 'market://details?id=com.waze');
  });

  test('application installée : ouverte directement ; sinon repli sur le site', () async {
    installed = {'https'};
    expect(await openNavigation(NavApp.waze, p, platform: TargetPlatform.android), NavOpenResult.app);
    expect(opened.single.$1.host, 'waze.com');

    opened.clear();
    installed = {'waze'};
    expect(await openNavigation(NavApp.waze, p, platform: TargetPlatform.android), NavOpenResult.app);
    expect(opened.last.$1.scheme, 'waze');

    // Waze absent : Play Store plutôt que le site, qui ne guide pas.
    opened.clear();
    installed = {'market'};
    expect(await openNavigation(NavApp.waze, p, platform: TargetPlatform.android), NavOpenResult.store);
    expect(opened.last.$1.toString(), 'market://details?id=com.waze');

    opened.clear();
    installed = {};
    expect(await openNavigation(NavApp.waze, p, platform: TargetPlatform.iOS), NavOpenResult.web);
    expect(opened.last.$1.host, 'waze.com');
    expect(opened.last.$2, isFalse);
  });

  test('sans clé Google Maps, la carte reste OpenStreetMap ; réglage « demander » par défaut', () {
    expect(mapsApiKey, isEmpty);
    expect(useGoogleMaps, isFalse);
    expect(settings.navApp, NavApp.ask);
  });

  Future<void> driveToFirstStop(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    settings.requestSound = false;
    await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: const DriverHome()));
    await tester.pump();
    await tester.tap(find.text('Passer en ligne'));
    for (var i = 0; i < 600 && find.byKey(const ValueKey('navigate')).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('Accepter').evaluate().isNotEmpty) await tester.tap(find.text('Accepter'), warnIfMissed: false);
    }
    expect(find.byKey(const ValueKey('navigate')), findsOneWidget);
  }

  // Les demandes qui arrivent peuvent recouvrir le panneau : on actionne le bouton directement.
  Future<void> tapNavigate(WidgetTester tester) async {
    tester.widget<ButtonStyleButton>(find.byKey(const ValueKey('navigate'))).onPressed!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('Naviguer : rester dans l\'application affiche le guidage, Waze ouvre l\'application', (tester) async {
    await driveToFirstStop(tester);

    await tapNavigate(tester);
    expect(find.text("Rester dans l'application"), findsOneWidget);
    expect(find.text('Ouvrir dans Waze'), findsOneWidget);
    expect(find.text('Ouvrir dans Google Maps'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nav-inApp')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('guideBanner')), findsOneWidget);
    expect(find.textContaining('Guidage vers'), findsOneWidget);
    expect(settings.navApp, NavApp.ask, reason: 'pas enregistré sans « toujours »');

    // Waze, choix enregistré : la fois suivante, plus de question.
    installed = {'waze'};
    await tapNavigate(tester);
    await tester.tap(find.text('Toujours utiliser ce choix'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('nav-waze')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(settings.navApp, NavApp.waze);
    expect(opened.last.$1.scheme, 'waze');

    opened.clear();
    await tapNavigate(tester);
    expect(find.text("Rester dans l'application"), findsNothing);
    expect(opened.last.$1.scheme, 'waze');
    await tester.pumpWidget(const SizedBox());
  });
}
