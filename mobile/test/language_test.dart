import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_maroc/main.dart';
import 'package:taxi_maroc/screens/rider_home.dart';
import 'package:taxi_maroc/services/settings.dart';

void main() {
  setUp(() {
    settings.reset();
    langNotifier.value = 'fr';
  });
  tearDown(() => langNotifier.value = 'fr');

  testWidgets('une seule option « Langue » : grille de drapeaux, passage à l\'espagnol', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const TaxiMarocApp(locate: false, onboarding: false));
    await tester.pump();
    // Les langues ne sont pas listées à l'écran : seulement le drapeau de la langue actuelle.
    expect(find.text('Español'), findsNothing);
    await tester.tap(find.bySemanticsLabel('Langue : Français'));
    await tester.pumpAndSettle();
    for (final name in ['Français', 'الدارجة', 'English', 'Español', 'Português', '日本語', '한국어', 'فارسی']) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
    await tester.tap(find.text('Español'));
    await tester.pumpAndSettle();
    expect(langNotifier.value, 'es');
    expect(find.text('¿A dónde vas?'), findsOneWidget);

    // Même choix depuis le menu : une seule ligne « Idioma ».
    await tester
        .tap(find.byTooltip(MaterialLocalizations.of(tester.element(find.byType(RiderHome))).openAppDrawerTooltip));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Idioma'), 200, scrollable: find.byType(Scrollable).last);
    expect(find.text('Idioma'), findsOneWidget);
    expect(find.text('Deutsch'), findsNothing);
  });

  testWidgets('persan : écriture de droite à gauche', (tester) async {
    langNotifier.value = 'fa';
    await tester.pumpWidget(const TaxiMarocApp(locate: false, onboarding: false));
    await tester.pump();
    expect(find.text('کجا می‌روید؟'), findsOneWidget);
    expect(Directionality.of(tester.element(find.text('کجا می‌روید؟'))), TextDirection.rtl);
  });
}
