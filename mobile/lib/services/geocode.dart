import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'places.dart';

/// Recherche d'adresses partout (test réel, hors des lieux de la démo) avec OpenStreetMap Nominatim.
/// Les résultats proches de [near] passent en premier.
Future<List<Place>> searchAddresses(String query, {LatLng? near, String lang = 'fr', http.Client? client}) async {
  final q = query.trim();
  if (q.length < 3) return const [];
  final params = {
    'q': q,
    'format': 'jsonv2',
    'limit': '8',
    'accept-language': lang,
    if (near != null) ...{
      // Zone d'environ 30 km autour du téléphone, préférée mais pas imposée.
      'viewbox': '${near.longitude - .3},${near.latitude + .3},${near.longitude + .3},${near.latitude - .3}',
    },
  };
  final uri = Uri.https('nominatim.openstreetmap.org', '/search', params);
  final res = await (client ?? http.Client())
      .get(uri, headers: {'User-Agent': 'BabTaxi/0.1 (test)'}).timeout(const Duration(seconds: 8));
  if (res.statusCode != 200) return const [];
  final list = jsonDecode(res.body) as List;
  final places = [
    for (final r in list)
      Place(
        (r['name'] as String?)?.isNotEmpty == true
            ? r['name'] as String
            : (r['display_name'] as String).split(',').first,
        double.parse(r['lat'] as String),
        double.parse(r['lon'] as String),
        const [],
        subtitle: (r['display_name'] as String).split(',').skip(1).take(3).map((e) => e.trim()).join(', '),
      ),
  ];
  if (near != null) {
    const d = Distance();
    places.sort((a, b) => d(near, LatLng(a.lat, a.lng)).compareTo(d(near, LatLng(b.lat, b.lng))));
  }
  return places;
}
