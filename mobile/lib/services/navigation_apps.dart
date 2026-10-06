import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

/// Comment le chauffeur se fait guider vers un passager : rester dans l'application (carte Google
/// Maps si une clé est fournie à la compilation, sinon la carte actuelle), ou ouvrir Waze ou
/// Google Maps. Waze ne peut pas être intégré comme carte : seulement des liens d'ouverture.
enum NavApp { ask, inApp, waze, googleMaps }

/// Clé Google Maps fournie à la compilation (`--dart-define=MAPS_API_KEY=…`), jamais dans le dépôt.
const mapsApiKey = String.fromEnvironment('MAPS_API_KEY');

/// La carte de l'application est Google Maps seulement avec une clé, et pas sur le web (démo).
bool get useGoogleMaps => mapsApiKey.isNotEmpty && !kIsWeb;

/// Nom affiché des applications externes (noms de marque, identiques dans toutes les langues).
String navAppName(NavApp app) => switch (app) {
      NavApp.waze => 'Waze',
      NavApp.googleMaps => 'Google Maps',
      NavApp.inApp || NavApp.ask => '',
    };

String _ll(LatLng p) => '${p.latitude.toStringAsFixed(6)},${p.longitude.toStringAsFixed(6)}';

/// Waze : lien universel (ouvre l'application si elle est installée, sinon le site).
Uri wazeUri(LatLng p) => Uri.parse('https://waze.com/ul?ll=${_ll(p)}&navigate=yes');

/// Google Maps sur Android : guidage en voiture directement.
Uri googleNavigationUri(LatLng p) => Uri.parse('google.navigation:q=${_ll(p)}&mode=d');

/// Google Maps sur iPhone (schéma « comgooglemaps »).
Uri googleMapsIosUri(LatLng p) => Uri.parse('comgooglemaps://?daddr=${_ll(p)}&directionsmode=driving');

/// Google Maps sur le web (repli si l'application n'est pas installée).
Uri googleMapsWebUri(LatLng p) =>
    Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${_ll(p)}&travelmode=driving');

/// Passager : voir la destination dans Google Maps (application ou site).
Uri googleMapsPlaceUri(LatLng p) => Uri.parse('https://www.google.com/maps/search/?api=1&query=${_ll(p)}');

/// Ouvre un lien : « appOnly » = seulement dans une application (pas le navigateur).
/// Renvoie faux si rien ne peut l'ouvrir.
typedef UrlOpener = Future<bool> Function(Uri uri, {required bool appOnly});

Future<bool> _launch(Uri uri, {required bool appOnly}) async {
  try {
    return await launchUrl(uri,
        mode: appOnly ? LaunchMode.externalNonBrowserApplication : LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// Remplaçable dans les tests.
UrlOpener urlOpener = _launch;

enum NavOpenResult { app, store, web, failed }

/// Fiche Play Store de l'application (Android), quand elle n'est pas installée.
Uri playStoreUri(NavApp app) =>
    Uri.parse('market://details?id=${app == NavApp.waze ? 'com.waze' : 'com.google.android.apps.maps'}');

/// Liens à essayer dans l'ordre : d'abord l'application, puis (Android) le Play Store, puis le site.
({List<Uri> app, Uri? store, Uri web}) navigationLinks(NavApp app, LatLng p, {TargetPlatform? platform}) {
  final os = platform ?? defaultTargetPlatform;
  final android = !kIsWeb && os == TargetPlatform.android;
  return switch (app) {
    NavApp.waze => (
        // Le lien universel waze.com/ul est celui que Waze recommande ; le schéma « waze:// » en secours.
        app: kIsWeb ? <Uri>[] : [wazeUri(p), Uri.parse('waze://?ll=${_ll(p)}&navigate=yes')],
        store: android ? playStoreUri(app) : null,
        web: wazeUri(p),
      ),
    _ => (
        app: kIsWeb
            ? <Uri>[]
            : os == TargetPlatform.iOS
                ? [googleMapsIosUri(p)]
                : [googleNavigationUri(p)],
        store: android ? playStoreUri(app) : null,
        web: googleMapsWebUri(p),
      ),
  };
}

/// Ouvre l'itinéraire vers [p] dans Waze ou Google Maps. Application absente : le Play Store sur
/// Android (le site de Waze ne guide pas), sinon le site (le chauffeur en est averti).
Future<NavOpenResult> openNavigation(NavApp app, LatLng p, {TargetPlatform? platform}) async {
  final links = navigationLinks(app, p, platform: platform);
  for (final uri in links.app) {
    if (await urlOpener(uri, appOnly: true)) return NavOpenResult.app;
  }
  final store = links.store;
  if (store != null && await urlOpener(store, appOnly: true)) return NavOpenResult.store;
  if (await urlOpener(links.web, appOnly: false)) return NavOpenResult.web;
  return NavOpenResult.failed;
}
