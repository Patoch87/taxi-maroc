import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taxi_maroc/main.dart';
import 'package:taxi_maroc/screens/lock_screen.dart';
import 'package:taxi_maroc/screens/rider_home.dart';
import 'package:taxi_maroc/screens/sos_screen.dart';
import 'package:taxi_maroc/services/account.dart';
import 'package:taxi_maroc/services/biometric_auth.dart';
import 'package:taxi_maroc/services/request_chime.dart';
import 'package:taxi_maroc/services/settings.dart';
import 'package:taxi_maroc/services/sos.dart';

class FakeSosApi implements SosApi {
  int failNext = 0;
  final segments = <int>[];
  final positions = <LatLng>[];
  bool ended = false;
  LatLng? openedAt;

  @override
  Future<String> open({String? taxiId, String? name, String? accountId, LatLng? position}) async {
    openedAt = position;
    return 'A1';
  }

  @override
  Future<void> segment(String id, int index, Uint8List bytes, String type) async {
    if (failNext > 0) {
      failNext--;
      throw Exception('réseau');
    }
    segments.add(index);
  }

  @override
  Future<void> position(String id, LatLng p) async => positions.add(p);

  @override
  Future<void> end(String id) async => ended = true;
}

class FakeBiometrics implements BiometricDevice {
  FakeBiometrics({this.ok = true});
  bool ok;
  int asked = 0;

  @override
  Future<BiometricSupport> support() async => const BiometricSupport(fingerprint: true, face: true);

  @override
  Future<bool> authenticate(String reason) async {
    asked++;
    return ok;
  }
}

const ahmed = Account(id: 'UABCDE', firstName: 'Ahmed', lastName: 'Bennani', phone: '+212 612345678', nationality: 'MA');

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() {
    settings.reset();
    accountStore.reset();
    biometricLock.reset();
    langNotifier.value = 'fr';
    SharedPreferences.setMockInitialValues({});
    loadCameras = () async => [];
  });

  test('SOS : alerte ouverte avec la position, séquences envoyées dans l\'ordre, réessai après une coupure', () async {
    final api = FakeSosApi();
    final session = SosSession(api: api, demo: false);
    await session.start(taxiId: 'CASA-123', position: const LatLng(33.57, -7.63));
    expect(session.opened, isTrue);
    expect(api.openedAt, const LatLng(33.57, -7.63));

    api.failNext = 1;
    session.addSegment(Uint8List.fromList([1, 2, 3]));
    await Future<void>.delayed(Duration.zero);
    expect(session.failed, isTrue);
    expect(session.sent, 0);

    // La séquence suivante repart avec celle qui attendait, dans l'ordre.
    session.addSegment(Uint8List.fromList([4, 5]));
    await Future<void>.delayed(Duration.zero);
    expect(api.segments, [0, 1]);
    expect(session.sent, 2);
    expect(session.bytes, 5);
    expect(session.failed, isFalse);

    await session.updatePosition(const LatLng(33.58, -7.62));
    expect(api.positions, hasLength(1));
    await session.stop();
    expect(api.ended, isTrue);
    expect(session.ended, isTrue);
  });

  test('SOS : type de vidéo selon le fichier (iPhone .mov, Android .mp4)', () {
    expect(videoMime('/x/REC123.mp4'), 'video/mp4');
    expect(videoMime('/x/REC123.MOV'), 'video/quicktime');
  });

  testWidgets('écran SOS : en direct dès l\'ouverture, « Je suis en sécurité » clôt l\'alerte', (tester) async {
    phone(tester);
    final api = FakeSosApi();
    final session = SosSession(api: api, demo: true);
    await tester.pumpWidget(MaterialApp(home: SosScreen(session: session, position: () => const LatLng(33.5, -7.6))));
    await tester.pump();
    expect(sosActive, isTrue);
    expect(find.textContaining('EN DIRECT'), findsOneWidget);
    expect(find.text('Démo : envoi simulé, rien ne quitte le téléphone'), findsOneWidget);
    expect(find.textContaining('loi 09-08'), findsOneWidget);
    expect(find.text('Police (19)'), findsOneWidget);
    await tester.pumpAndSettle();
    // Pas de caméra dans les tests : l'alerte et la position partent quand même.
    expect(find.text('Caméra indisponible : alerte et position envoyées'), findsOneWidget);
    expect(session.opened, isTrue);

    await tester.tap(find.byKey(const ValueKey('sosStop')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sosStopConfirm')));
    await tester.pumpAndSettle();
    expect(api.ended, isTrue);
    expect(find.byType(SosScreen), findsNothing);
    expect(sosActive, isFalse);
  });

  test('compte : enregistré sur le téléphone puis relu au lancement', () async {
    await accountStore.load();
    accountStore.save(ahmed);
    await Future<void>.delayed(Duration.zero);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('account'), contains('Ahmed'));

    final other = AccountStore();
    await other.load();
    expect(other.account?.id, 'UABCDE');
    expect(other.account?.phoneCountry, 'MA');
    expect(Account.fromJson({'id': 1}), isNull);
  });

  test('connexion biométrique : activée seulement après une vérification réussie, verrouille au lancement', () async {
    final device = FakeBiometrics(ok: false);
    biometricLock.device = device;
    accountStore.save(ahmed);
    await biometricLock.load();
    expect(biometricLock.support.any, isTrue);
    expect(biometricLock.locked, isFalse);

    expect(await biometricLock.enable(), isFalse);
    expect(biometricLock.enabled, isFalse);
    device.ok = true;
    expect(await biometricLock.enable(), isTrue);
    expect((await SharedPreferences.getInstance()).getBool('biometricLogin'), isTrue);

    // Lancement suivant : l'accueil attend l'empreinte ou le visage.
    await biometricLock.load();
    expect(biometricLock.locked, isTrue);
    device.ok = false;
    expect(await biometricLock.unlock(), isFalse);
    expect(biometricLock.locked, isTrue);
    device.ok = true;
    expect(await biometricLock.unlock(), isTrue);
    expect(biometricLock.locked, isFalse);

    await biometricLock.disable();
    await biometricLock.load();
    expect(biometricLock.locked, isFalse);
  });

  testWidgets('écran de connexion : empreinte ou visage demandé tout de suite, code SMS possible, SOS accessible',
      (tester) async {
    phone(tester);
    final device = FakeBiometrics(ok: false);
    biometricLock.device = device;
    accountStore.save(ahmed);
    SharedPreferences.setMockInitialValues({'biometricLogin': true});
    await tester.runAsync(biometricLock.load);
    expect(biometricLock.locked, isTrue);

    await tester.pumpWidget(const TaxiMarocApp(locate: false, onboarding: false));
    await tester.pump();
    await tester.pump();
    expect(find.byType(LockScreen), findsOneWidget);
    expect(find.text('Bonjour Ahmed'), findsOneWidget);
    expect(device.asked, 1);
    expect(find.text('Non reconnu, réessayez'), findsOneWidget);
    expect(find.byKey(const ValueKey('lockSos')), findsOneWidget);

    // Code SMS (démo : affiché à l'écran).
    await tester.tap(find.byKey(const ValueKey('bioUseCode')));
    await tester.pump();
    await tester.tap(find.textContaining('Recevoir le code'));
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('lockSmsCode')), demoSmsCode);
    await tester.pump();
    expect(find.byType(LockScreen), findsNothing);
    expect(find.byType(RiderHome), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('écran de connexion : l\'empreinte reconnue ouvre l\'accueil', (tester) async {
    phone(tester);
    biometricLock.device = FakeBiometrics(ok: true);
    accountStore.save(ahmed);
    SharedPreferences.setMockInitialValues({'biometricLogin': true});
    await tester.runAsync(biometricLock.load);
    await tester.pumpWidget(const TaxiMarocApp(locate: false, onboarding: false));
    await tester.pump();
    await tester.pump();
    expect(find.byType(LockScreen), findsNothing);
    expect(find.byType(RiderHome), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
