import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Itinéraire par la route entre deux points (serveur OSRM public, réservé à la démo).
/// En cas d'échec, on trace une ligne droite pour que l'application reste utilisable.
Future<List<LatLng>> fetchRoute(LatLng from, LatLng to) async {
  final url = Uri.parse('https://router.project-osrm.org/route/v1/driving/'
      '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
      '?overview=full&geometries=geojson');
  try {
    final res = await http.get(url).timeout(const Duration(seconds: 6));
    if (res.statusCode == 200) {
      final coords = (jsonDecode(res.body)['routes'][0]['geometry']['coordinates'] as List);
      return coords.map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList();
    }
  } catch (_) {}
  return interpolate(from, to, 40);
}

/// Points régulièrement espacés entre deux positions.
List<LatLng> interpolate(LatLng a, LatLng b, int steps) => List.generate(
    steps + 1,
    (i) => LatLng(
        a.latitude + (b.latitude - a.latitude) * i / steps, a.longitude + (b.longitude - a.longitude) * i / steps));

/// Longueur d'un itinéraire en mètres.
double routeLengthM(List<LatLng> route) {
  const d = Distance();
  var total = 0.0;
  for (var i = 1; i < route.length; i++) {
    total += d(route[i - 1], route[i]);
  }
  return total;
}
