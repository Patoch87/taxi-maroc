import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_maroc/screens/driver_home.dart';
import 'package:taxi_maroc/services/driver_notifications.dart';
import 'package:taxi_maroc/services/settings.dart';
import 'package:taxi_maroc/theme.dart';

void main() {
  final n = DriverNotifications.instance;
  final shown = <(int, String, String, bool)>[];

  tearDown(() => DriverHome.requestGap = const Duration(seconds: 7));
  setUp(() {
    settings.reset();
    settings.requestSound = false;
    shown.clear();
    DriverHome.requestGap = Duration.zero;
    n.debugShow = (id, title, body, actions) => shown.add((id, title, body, actions));
  });
  tearDown(() => n.debugState = null);

  Future<void> waitForRequest(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: const DriverHome()));
    await tester.pump();
    await tester.tap(find.text('Passer en ligne'));
    for (var i = 0; i < 600 && shown.isEmpty && find.text('Accepter').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('dans l\'application : pas de notification système', (tester) async {
    n.debugState = AppLifecycleState.resumed;
    await waitForRequest(tester);
    expect(find.text('Accepter'), findsWidgets);
    expect(shown, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('dans Waze : la demande arrive en notification et « Accepter » l\'accepte', (tester) async {
    n.debugState = AppLifecycleState.paused;
    await waitForRequest(tester);
    expect(shown, hasLength(1));
    final (id, title, body, actions) = shown.single;
    expect(id, DriverNotifications.requestId);
    expect(title, startsWith('Passager sur votre route'));
    expect(body, contains(' m'));
    expect(actions, isTrue);

    final state = tester.state(find.byType(DriverHome));
    final key = (state as dynamic).debugRequestKey as String;
    n.onAction!(acceptAction, key);
    await tester.pump();
    expect(find.text('Accepter'), findsNothing, reason: 'demande acceptée depuis la notification');
    await tester.pumpWidget(const SizedBox());
  });
}
