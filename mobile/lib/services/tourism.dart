import 'package:latlong2/latlong.dart';

import 'places.dart';

/// Restaurant proposé aux touristes près de leur destination (données de démo, noms fictifs).
///
/// Note façon TripAdvisor : données fictives de démo, affichées « Note TripAdvisor (démo) ».
/// En production : TripAdvisor Content API (location search + location details) avec une clé partenaire,
/// en respectant leurs règles d'affichage (logo officiel, lien vers l'avis, mise en cache limitée).
class Restaurant {
  const Restaurant(this.name, this.cuisineKey, this.priceMad, this.lat, this.lng, this.rating, this.reviews);
  final String name;

  /// Note sur 5 (par demi-point) et nombre d'avis.
  final double rating;
  final int reviews;

  /// Clé de traduction (S) de la cuisine.
  final String cuisineKey;

  /// Prix moyen d'un repas, en dirhams.
  final String priceMad;
  final double lat;
  final double lng;

  Place get place => Place(name, lat, lng, [name.toLowerCase()], subtitle: 'Restaurant');
}

const demoRestaurants = [
  Restaurant('Dar Tajine', 'cuisineMoroccan', '120-200 DH', 33.6045, -7.6230, 4.5, 1284),
  Restaurant('Le Pêcheur de la Corniche', 'cuisineSeafood', '180-300 DH', 33.5935, -7.6690, 4.0, 862),
  Restaurant('Riad Saveurs', 'cuisineMoroccan', '150-250 DH', 33.5925, -7.6140, 5.0, 412),
  Restaurant('Café Zellige', 'cuisineCafe', '40-80 DH', 33.5880, -7.5950, 4.0, 233),
  Restaurant('Sushi Anfa', 'cuisineJapanese', '200-350 DH', 33.5975, -7.6600, 4.5, 577),
  Restaurant('Grill Maârif', 'cuisineGrill', '90-160 DH', 33.5860, -7.6340, 3.5, 318),
  Restaurant('Mama Rfissa', 'cuisineMoroccan', '70-130 DH', 33.5800, -7.6085, 4.5, 941),
  Restaurant('Pasta Mall', 'cuisineItalian', '110-190 DH', 33.5770, -7.7020, 4.0, 689),
  Restaurant('Le Petit Port', 'cuisineSeafood', '160-280 DH', 33.6000, -7.6170, 4.5, 1052),
];

/// Les 3 restaurants les plus proches de la destination, avec leur distance en mètres, les mieux notés d'abord.
List<(Restaurant, double)> restaurantsNear(Place destination, {int count = 3}) {
  const d = Distance();
  final here = LatLng(destination.lat, destination.lng);
  final list = [for (final r in demoRestaurants) (r, d(here, LatLng(r.lat, r.lng)))]
    ..sort((a, b) => a.$2.compareTo(b.$2));
  return list.take(count).toList()
    ..sort((a, b) => b.$1.rating != a.$1.rating ? b.$1.rating.compareTo(a.$1.rating) : a.$2.compareTo(b.$2));
}
