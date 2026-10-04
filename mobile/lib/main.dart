import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/strings.dart';
import 'screens/account_screen.dart';
import 'screens/rider_home.dart';
import 'services/account.dart';
import 'theme.dart';

/// Langue choisie par l'utilisateur (voir S.supported).
final langNotifier = ValueNotifier<String>('fr');
S get s => S(langNotifier.value);

/// Langue des textes système (calendrier, boutons OK...) : la darija utilise l'arabe,
/// le serbe est écrit en alphabet latin.
Locale materialLocale(String lang) => switch (lang) {
      'dr' => const Locale('ar'),
      'sr' => const Locale.fromSubtags(languageCode: 'sr', scriptCode: 'Latn'),
      _ => Locale(lang),
    };

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent));
  runApp(const TaxiMarocApp());
}

class TaxiMarocApp extends StatelessWidget {
  const TaxiMarocApp({super.key, this.locate = true, this.onboarding = true});

  /// Désactivé dans les tests (pas de GPS).
  final bool locate;

  /// Inscription au premier lancement (désactivée dans la plupart des tests).
  final bool onboarding;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: langNotifier,
      builder: (context, lang, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: s.t('appTitle'),
        // La darija utilise les traductions système de l'arabe (et l'écriture de droite à gauche).
        locale: materialLocale(lang),
        supportedLocales: [
          for (final code in S.supported)
            if (code != 'dr') materialLocale(code)
        ],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: buildTheme(),
        // Premier lancement : création du compte, ou « Continuer en démo ».
        // La clé force la reconstruction de l'accueil quand la langue change.
        home: ListenableBuilder(
          listenable: accountStore,
          builder: (context, _) => onboarding && accountStore.account == null && !accountStore.skipped
              ? const AccountScreen(firstLaunch: true)
              : RiderHome(key: ValueKey(lang), locate: locate),
        ),
      ),
    );
  }
}
