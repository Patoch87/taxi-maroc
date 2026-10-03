import 'package:latlong2/latlong.dart';

import 'places.dart';

/// Restaurant proposé aux touristes près de leur destination (données de démo, noms fictifs).
class Restaurant {
  const Restaurant(this.name, this.cuisineKey, this.priceMad, this.lat, this.lng);
  final String name;

  /// Clé de traduction (S) de la cuisine.
  final String cuisineKey;

  /// Prix moyen d'un repas, en dirhams.
  final String priceMad;
  final double lat;
  final double lng;

  Place get place => Place(name, lat, lng, [name.toLowerCase()], subtitle: 'Restaurant');
}

const demoRestaurants = [
  Restaurant('Dar Tajine', 'cuisineMoroccan', '120-200 DH', 33.6045, -7.6230),
  Restaurant('Le Pêcheur de la Corniche', 'cuisineSeafood', '180-300 DH', 33.5935, -7.6690),
  Restaurant('Riad Saveurs', 'cuisineMoroccan', '150-250 DH', 33.5925, -7.6140),
  Restaurant('Café Zellige', 'cuisineCafe', '40-80 DH', 33.5880, -7.5950),
  Restaurant('Sushi Anfa', 'cuisineJapanese', '200-350 DH', 33.5975, -7.6600),
  Restaurant('Grill Maârif', 'cuisineGrill', '90-160 DH', 33.5860, -7.6340),
  Restaurant('Mama Rfissa', 'cuisineMoroccan', '70-130 DH', 33.5800, -7.6085),
  Restaurant('Pasta Mall', 'cuisineItalian', '110-190 DH', 33.5770, -7.7020),
  Restaurant('Le Petit Port', 'cuisineSeafood', '160-280 DH', 33.6000, -7.6170),
];

/// Les 3 restaurants les plus proches de la destination, avec leur distance en mètres.
List<(Restaurant, double)> restaurantsNear(Place destination, {int count = 3}) {
  const d = Distance();
  final here = LatLng(destination.lat, destination.lng);
  final list = [for (final r in demoRestaurants) (r, d(here, LatLng(r.lat, r.lng)))]
    ..sort((a, b) => a.$2.compareTo(b.$2));
  return list.take(count).toList();
}
