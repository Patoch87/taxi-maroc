import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'live.dart';

const casablancaCenter = LatLng(33.5731, -7.5898);

/// Position actuelle du téléphone. Repli sur le centre de Casablanca si le GPS est refusé.
Future<Map<String, double>> currentPosition() async {
  final p = await currentLatLng();
  return {'lat': p.latitude, 'lng': p.longitude};
}

/// Position actuelle, ou le centre de Casablanca si le GPS est refusé
/// ou si le téléphone est à plus de 40 km de Casablanca (la démo se passe à Casablanca).
/// En test réel, la vraie position est gardée partout.
Future<LatLng> currentLatLng() async {
  try {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return casablancaCenter;
    final p = await Geolocator.getCurrentPosition().timeout(const Duration(seconds: 8));
    final here = LatLng(p.latitude, p.longitude);
    if (!live.enabled && const Distance()(here, casablancaCenter) > 40000) return casablancaCenter;
    return here;
  } catch (_) {
    return casablancaCenter;
  }
}

/// Positions GPS en continu (chauffeur en test réel) : une mise à jour tous les 5 m environ.
/// Sur Android, une notification permanente garde le GPS actif quand le chauffeur passe dans Waze
/// ou éteint l'écran : sinon sa position se fige et le serveur le croit hors ligne.
Stream<LatLng> positionStream() => Geolocator.getPositionStream(
      locationSettings: !kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? AndroidSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 5,
              foregroundNotificationConfig: const ForegroundNotificationConfig(
                notificationTitle: 'Bab Taxi : vous êtes en ligne',
                notificationText: 'Votre position est partagée avec les passagers.',
                enableWakeLock: true,
                setOngoing: true,
              ),
            )
          : const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5),
    ).map((p) => LatLng(p.latitude, p.longitude));
