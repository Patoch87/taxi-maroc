import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_maroc/l10n/strings.dart';
import 'package:taxi_maroc/main.dart';
import 'package:taxi_maroc/screens/trusted_contacts_screen.dart';
import 'package:taxi_maroc/services/rides.dart';
import 'package:taxi_maroc/services/schedule.dart';
import 'package:taxi_maroc/services/settings.dart';
import 'package:taxi_maroc/theme.dart';
import 'package:taxi_maroc/widgets/app_logo.dart';
import 'package:taxi_maroc/widgets/senior.dart';

/// Écran de téléphone (390 x 844), comme les captures.
void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() {
    settings.reset();
    langNotifier.value = 'fr';
  });

  test('chaque texte existe dans les 16 langues', () {
    expect(S.supported.length, 16);
    final keys = S.table.keys.toSet();
    for (final lang in S.supported) {
      final strings = S.strings(lang);
      expect(strings.keys.toSet(), keys, reason: lang);
      expect(strings.values.every((v) => v.trim().isNotEmpty), isTrue, reason: lang);
      expect(S.names[lang], isNotNull, reason: lang);
      expect(S.flags[lang], isNotNull, reason: lang);
    }
    expect(S('fa').rtl && S('ar').rtl && S('dr').rtl, isTrue);
    expect(S('es').rtl, isFalse);
    expect(S('ja').speechLocale, 'ja-JP');
    expect(S('sr').speechLocale, 'sr-RS');
  });

  group('réservation pour plus tard', () {
    final now = DateTime(2026, 10, 3, 10, 0); // samedi

    test('libellés : aujourd\'hui, demain, puis jour et date', () {
      expect(scheduleLabel(DateTime(2026, 10, 3, 14, 0), lang: 'fr', now: now), 'Aujourd\'hui 14:00');
      expect(scheduleLabel(DateTime(2026, 10, 4, 8, 30), lang: 'fr', now: now), 'Demain 08:30');
      expect(scheduleLabel(DateTime(2026, 10, 5, 8, 30), lang: 'fr', now: now), 'Lun. 5 oct. 08:30');
      expect(scheduleLabel(DateTime(2026, 10, 6, 18, 5), lang: 'fr', now: now), 'Mar. 6 oct. 18:05');
      expect(scheduleLabel(DateTime(2026, 11, 1, 7, 0), lang: 'fr', now: now), 'Dim. 1 nov. 07:00');
      expect(scheduleLabel(DateTime(2026, 10, 4, 8, 30), lang: 'en', now: now), 'Tomorrow 08:30');
      expect(scheduleLabel(DateTime(2026, 10, 5, 8, 30), lang: 'en', now: now), 'Mon 5 Oct 08:30');
      expect(scheduleLabel(DateTime(2026, 10, 4, 8, 30), lang: 'ar', now: now), 'غدا 08:30');
      expect(scheduleLabel(DateTime(2026, 10, 5, 8, 30), lang: 'dr', now: now), 'الاثنين 5 أكتوبر 08:30');
      expect(scheduleLabel(DateTime(2026, 10, 4, 8, 30), lang: 'es', now: now), 'Mañana 08:30');
      expect(scheduleLabel(DateTime(2026, 10, 5, 8, 30), lang: 'es', now: now), 'lun. 5 oct. 08:30');
      expect(scheduleLabel(DateTime(2026, 10, 5, 8, 30), lang: 'de', now: now), 'Mo. 5. Okt. 08:30');
      expect(scheduleLabel(DateTime(2026, 10, 5, 8, 30), lang: 'ja', now: now), '10月5日(月) 08:30');
    });

    test('au moins 15 minutes avant le départ, au plus 30 jours', () {
      expect(clampSchedule(DateTime(2026, 10, 3, 10, 5), now: now), DateTime(2026, 10, 3, 10, 15));
      expect(
          clampSchedule(DateTime(2026, 10, 3, 9, 0), now: DateTime(2026, 10, 3, 10, 2)), DateTime(2026, 10, 3, 10, 20));
      expect(clampSchedule(DateTime(2026, 10, 4, 8, 30), now: now), DateTime(2026, 10, 4, 8, 30));
      expect(clampSchedule(DateTime(2026, 12, 25, 8, 0), now: now), DateTime(2026, 11, 2, 23, 59));
    });
  });

  group('contacts de confiance', () {
    test('5 contacts au maximum et partage automatique la nuit', () {
      for (var i = 0; i < 6; i++) {
        settings.addContact(TrustedContact('Proche $i', '06000000$i'));
      }
      expect(settings.contacts.length, 5);
      expect(settings.canAddContact, isFalse);
      expect(settings.addContact(const TrustedContact('', '0600')), isFalse);

      expect(settings.autoShare, AutoShare.night);
      expect(settings.shouldAutoShare(DateTime(2026, 10, 3, 22)), isTrue);
      expect(settings.shouldAutoShare(DateTime(2026, 10, 3, 5, 59)), isTrue);
      expect(settings.shouldAutoShare(DateTime(2026, 10, 3, 12)), isFalse);
      settings.autoShare = AutoShare.always;
      expect(settings.shouldAutoShare(DateTime(2026, 10, 3, 12)), isTrue);
      settings.autoShare = AutoShare.never;
      expect(settings.shouldAutoShare(DateTime(2026, 10, 3, 23)), isFalse);
    });

    testWidgets('ajouter puis supprimer un contact', (tester) async {
      phone(tester);
      await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: const TrustedContactsScreen()));
      expect(find.text('Aucun contact pour le moment'), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('contactName')), 'Amina');
      await tester.enterText(find.byKey(const ValueKey('contactPhone')), '0612345678');
      await tester.pump();
      await tester.tap(find.text('Ajouter'));
      await tester.pump();
      expect(settings.contacts.single.name, 'Amina');
      expect(find.text('Amina'), findsOneWidget);
      expect(find.text('0612345678'), findsOneWidget);

      await tester.tap(find.text('Toujours'));
      await tester.pump();
      expect(settings.autoShare, AutoShare.always);

      await tester.tap(find.byTooltip('Supprimer Amina'));
      await tester.pump();
      expect(settings.contacts, isEmpty);
      expect(find.text('Aucun contact pour le moment'), findsOneWidget);
    });
  });

  testWidgets('mode senior : trois gros boutons, puis retour au mode normal', (tester) async {
    phone(tester);
    await tester.pumpWidget(const TaxiMarocApp(locate: false));
    await tester.pump();
    expect(find.text('Où allez-vous ?'), findsOneWidget);
    expect(find.byType(AppLogo), findsWidgets);

    await tester.tap(find.byTooltip('Mode senior'));
    await tester.pumpAndSettle();
    expect(settings.senior, isTrue);
    for (final label in ['Commander un taxi', 'Rentrer à la maison', 'Appeler un proche']) {
      final text = tester.widget<Text>(find.text(label));
      expect(text.style!.fontSize, greaterThanOrEqualTo(24), reason: label);
    }
    expect(find.text('Où allez-vous ?'), findsNothing);

    // Commander : écran de recherche en très gros, avec le micro.
    await tester.tap(find.text('Commander un taxi'));
    await tester.pumpAndSettle();
    expect(find.text('Dire ma destination'), findsOneWidget);
    await tester.tap(find.text('Gare Casa Voyageurs'));
    await tester.pumpAndSettle();
    expect(find.text('Aller à'), findsOneWidget);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Revenir au mode normal'));
    await tester.tap(find.text('Revenir au mode normal'));
    await tester.pumpAndSettle();
    expect(settings.senior, isFalse);
    expect(find.text('Où allez-vous ?'), findsOneWidget);
  });

  testWidgets('commander pour quelqu\'un d\'autre : le passager apparaît sur la fiche du chauffeur', (tester) async {
    phone(tester);
    settings.addContact(const TrustedContact('Fatima', '0611223344'));
    await tester.pumpWidget(const TaxiMarocApp(locate: false));
    await tester.pump();

    await tester.tap(find.text('Gare Casa Voyageurs'));
    await tester.pumpAndSettle();
    expect(find.text('Choisissez votre taxi'), findsOneWidget);

    await tester.ensureVisible(find.text('Pour moi'));
    await tester.tap(find.text('Pour moi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pour quelqu\'un d\'autre'));
    await tester.pumpAndSettle();
    // Choisi dans les contacts enregistrés.
    await tester.tap(find.widgetWithText(ActionChip, 'Fatima'));
    await tester.pump();
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();

    expect(find.text('Pour moi'), findsNothing);
    expect(find.text('Passager : Fatima · 0611223344'), findsOneWidget);

    await tester.ensureVisible(find.textContaining('Commander ·'));
    await tester.tap(find.textContaining('Commander ·'));
    await tester.pump();
    // Le premier chauffeur accepte en moins de 5 secondes, puis le taxi part vers le passager.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.text('Votre taxi arrive dans'), findsOneWidget);
    expect(find.text('Passager : Fatima'), findsOneWidget);
    expect(find.text('Envoyer les infos à Fatima'), findsOneWidget);

    ScaffoldMessenger.of(tester.element(find.text('Annuler'))).clearSnackBars();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Annuler'));
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
  });

  testWidgets('mode senior : « Rentrer à la maison » commande un petit taxi partagé en un geste', (tester) async {
    phone(tester);
    settings.senior = true;
    await tester.pumpWidget(const TaxiMarocApp(locate: false));
    await tester.pump();

    await tester.tap(find.text('Rentrer à la maison'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Recherche d\'un taxi sur votre route…'), findsOneWidget);

    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    // L'essentiel seulement : plaque en très grand, compte à rebours, un gros bouton SOS.
    expect(find.text('Votre taxi arrive dans'), findsOneWidget);
    expect(find.text('SOS urgence'), findsOneWidget);
    final plate = tester.widget<SeniorPlate>(find.byType(SeniorPlate)).plate;
    expect(tester.widget<Text>(find.text(plate)).style!.fontSize, greaterThanOrEqualTo(40));
    expect(find.text('Je suis dans le taxi'), findsNothing);
    expect(find.byType(FlutterMap), findsNothing);
    expect(tripHistory.isEmpty || !tripHistory.first.scheduled, isTrue);

    await tester.pumpWidget(const SizedBox());
  });
}
