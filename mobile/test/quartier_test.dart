import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_maroc/main.dart';
import 'package:taxi_maroc/screens/driver_home.dart';
import 'package:taxi_maroc/services/quartiers.dart';
import 'package:taxi_maroc/services/settings.dart';
import 'package:taxi_maroc/theme.dart';

void main() {
  setUp(() {
    settings.reset();
    langNotifier.value = 'fr';
  });

  test('quartier dit à voix haute : accents, darija, arabe, petites fautes', () {
    String? name(String said) => findQuartier(said)?.name;
    expect(name('Maârif'), 'Maârif');
    expect(name('je vais au maarif'), 'Maârif');
    expect(name("l'Maarif"), 'Maârif');
    expect(name('المعاريف'), 'Maârif');
    expect(name('غادي للمعاريف'), 'Maârif');
    expect(name('ماشي للحي المحمدي'), 'Hay Mohammadi');
    expect(name('Aïn Diab'), 'Aïn Diab');
    expect(name('ain diab'), 'Aïn Diab');
    expect(name('ayn diab'), 'Aïn Diab');
    expect(name('عين الذئاب'), 'Aïn Diab');
    expect(name('Sidi Maarouf'), 'Sidi Maârouf');
    expect(name('sidi marouf'), 'Sidi Maârouf');
    expect(name('Hay Mohammadi'), 'Hay Mohammadi');
    expect(name('hay mohamadi'), 'Hay Mohammadi');
    expect(name('الحي المحمدي'), 'Hay Mohammadi');
    expect(name('Hay Hassani'), 'Hay Hassani');
    expect(name('Sidi Bernoussi'), 'Sidi Bernoussi');
    expect(name('vers Aïn Sebaâ'), 'Aïn Sebaâ');
    expect(name('bonjour'), isNull);
    expect(name(''), isNull);
    // Centres de quartier dans Casablanca.
    for (final q in casablancaQuartiers) {
      expect(q.lat, inInclusiveRange(33.40, 33.65), reason: q.name);
      expect(q.lng, inInclusiveRange(-7.75, -7.45), reason: q.name);
    }
  });

  testWidgets('chauffeur en service : « Dire mon quartier », puis le quartier touché devient la destination',
      (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    settings.requestSound = false;
    await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: const DriverHome()));
    await tester.pump();
    expect(find.byKey(const ValueKey('sayArea')), findsNothing);

    await tester.tap(find.text('Commencer le service'));
    await tester.pump(const Duration(milliseconds: 300));
    // Passager pris dans la rue, sans l'application : le bouton reste là.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Dire mon quartier'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('sayArea')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Je vais vers…'), findsOneWidget);
    // Sans micro (navigateur, tests), la liste des quartiers reste utilisable.
    expect(find.text('Ou touchez le quartier'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('area-Maârif')));
    await tester.tap(find.byKey(const ValueKey('area-Maârif')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Je vais vers…'), findsNothing);
    expect(find.text('Vers Maârif'), findsOneWidget);
    expect(find.text('Uniquement les passagers sur votre trajet'), findsOneWidget);
    expect(find.byKey(const ValueKey('sayArea')), findsNothing);
    expect(find.byKey(const ValueKey('sayAreaAgain')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('myDestClear')));
    await tester.pump();
    expect(find.byKey(const ValueKey('myDestBanner')), findsNothing);
    expect(find.byKey(const ValueKey('sayArea')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
