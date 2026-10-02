import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

const casablancaCenter = LatLng(33.5731, -7.5898);

/// Position actuelle du téléphone. Repli sur le centre de Casablanca si le GPS est refusé.
Future<Map<String, double>> currentPosition() async {
  final p = await currentLatLng();
  return {'lat': p.latitude, 'lng': p.longitude};
}

/// Position actuelle, ou le centre de Casablanca si le GPS est refusé
/// ou si le téléphone est à plus de 40 km de Casablanca (la démo se passe à Casablanca).
Future<LatLng> currentLatLng() async {
  try {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return casablancaCenter;
    final p = await Geolocator.getCurrentPosition().timeout(const Duration(seconds: 8));
    final here = LatLng(p.latitude, p.longitude);
    if (const Distance()(here, casablancaCenter) > 40000) return casablancaCenter;
    return here;
  } catch (_) {
    return casablancaCenter;
  }
}
