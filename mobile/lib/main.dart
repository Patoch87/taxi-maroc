import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/strings.dart';
import 'screens/rider_home.dart';
import 'theme.dart';

/// Langue choisie par l'utilisateur (fr, ar, en).
final langNotifier = ValueNotifier<String>('fr');
S get s => S(langNotifier.value);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent));
  runApp(const TaxiMarocApp());
}

class TaxiMarocApp extends StatelessWidget {
  const TaxiMarocApp({super.key, this.locate = true});

  /// Désactivé dans les tests (pas de GPS).
  final bool locate;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: langNotifier,
      builder: (context, lang, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: s.t('appTitle'),
        // La darija utilise les traductions système de l'arabe (et l'écriture de droite à gauche).
        locale: Locale(lang == 'dr' ? 'ar' : lang),
        supportedLocales: const [Locale('fr'), Locale('ar'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: buildTheme(),
        // La clé force la reconstruction de l'accueil quand la langue change.
        home: RiderHome(key: ValueKey(lang), locate: locate),
      ),
    );
  }
}
