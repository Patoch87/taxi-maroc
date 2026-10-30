import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/strings.dart';
import 'screens/account_screen.dart';
import 'screens/lock_screen.dart';
import 'screens/rider_home.dart';
import 'services/ads.dart';
import 'services/live.dart';
import 'services/navigation_apps.dart';
import 'services/account.dart';
import 'services/biometric_auth.dart';
import 'services/settings.dart';
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent));
  if (kIsWeb) applyWebDemoOptions(Uri.base);
  if (useGoogleMaps) _setUpGoogleMapsAndroid();
  // Compte enregistré sur le téléphone, puis connexion par empreinte ou visage si elle est activée.
  if (!kIsWeb) {
    await accountStore.load().then((_) => biometricLock.load()).timeout(const Duration(seconds: 3), onTimeout: () {});
  }
  runApp(const TaxiMarocApp());
  connectToServer();
}

/// Serveur du test réel (Render, offre gratuite) : réveil au lancement, « Connexion au serveur… »
/// pendant 60 s au plus, puis mode démo automatique avec un avis si le serveur ne répond pas.
Future<void> connectToServer() async {
  if (!live.enabled) return;
  if (await live.warmUp()) {
    await adCatalog.refresh();
  } else {
    Future.delayed(const Duration(seconds: 12), live.dismissFallback);
  }
}

/// Carte Google sur Android : composition « hybride » (vue Android réelle) et moteur récent ;
/// sans cela, la carte peut rester blanche sur certains téléphones.
void _setUpGoogleMapsAndroid() {
  if (defaultTargetPlatform != TargetPlatform.android) return;
  final maps = GoogleMapsFlutterPlatform.instance;
  if (maps is GoogleMapsFlutterAndroid) {
    maps.initializeWithRenderer(AndroidMapRenderer.latest).catchError((_) => AndroidMapRenderer.platformDefault);
  }
}

/// Options de la version web pour la vidéo de démonstration :
/// « ?demo=1 » ouvre directement l'accueil en démo (sans inscription),
/// « ?video=1 » masque les suggestions de restaurants.
void applyWebDemoOptions(Uri uri) {
  if (uri.queryParameters['demo'] == '1') {
    accountStore.skip();
    live.enabled = false;
  }
  if (uri.queryParameters['video'] == '1') settings.restaurantSuggestions = false;
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
        // Compte enregistré et connexion biométrique activée : empreinte ou visage d'abord.
        home: ListenableBuilder(
          listenable: Listenable.merge([accountStore, biometricLock]),
          builder: (context, _) => biometricLock.locked
              ? const LockScreen()
              : onboarding && accountStore.account == null && !accountStore.skipped
                  ? const AccountScreen(firstLaunch: true)
                  : RiderHome(key: ValueKey(lang), locate: locate),
        ),
      ),
    );
  }
}
