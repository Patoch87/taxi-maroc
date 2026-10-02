import 'package:geolocator/geolocator.dart';

/// Position actuelle du téléphone. Repli sur le centre de Casablanca si le GPS est refusé.
Future<Map<String, double>> currentPosition() async {
  const fallback = {'lat': 33.5731, 'lng': -7.5898};
  try {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return fallback;
    final p = await Geolocator.getCurrentPosition();
    return {'lat': p.latitude, 'lng': p.longitude};
  } catch (_) {
    return fallback;
  }
}
