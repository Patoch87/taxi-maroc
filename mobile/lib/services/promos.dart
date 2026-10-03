import 'package:flutter/material.dart';

import 'places.dart';
import 'rides.dart';

/// Offre contextuelle (données de démo). Les marques citées sont des exemples,
/// pas des partenaires : chaque carte porte la mention « Exemple publicitaire (démo) ».
class Promo {
  const Promo(
      {required this.id,
      required this.brand,
      required this.titleKey,
      required this.detailKey,
      required this.icon,
      required this.color});
  final String id;
  final String brand;

  /// Clés de traduction (S) du titre et du détail.
  final String titleKey;
  final String detailKey;
  final IconData icon;
  final Color color;
}

const zaraPromo = Promo(
  id: 'zara',
  brand: 'Zara',
  titleKey: 'promoZara',
  detailKey: 'promoZaraDetail',
  icon: Icons.shopping_bag_outlined,
  color: Color(0xFF14213D),
);

const koolsmoothiePromo = Promo(
  id: 'koolsmoothie',
  brand: 'Koolsmoothie',
  titleKey: 'promoKool',
  detailKey: 'promoKoolDetail',
  icon: Icons.local_drink_outlined,
  color: Color(0xFF006233),
);

const cafePromo = Promo(
  id: 'cafe',
  brand: 'Café de la Gare',
  titleKey: 'promoCafe',
  detailKey: 'promoCafeDetail',
  icon: Icons.coffee_outlined,
  color: Color(0xFF8A5A00),
);

const _shoppingPlaces = {'Morocco Mall', 'Anfa Place', 'Twin Center'};
const _seaPlaces = {'Ain Diab', 'Morocco Mall', 'Mosquée Hassan II', 'Anfa Place'};

/// Choisit une offre selon la destination, l'heure, le type de course et les trajets passés.
/// Jamais selon le revenu, le quartier d'habitation ou d'autres données personnelles.
Promo? pickPromo({
  required Place destination,
  required RideOption option,
  DateTime? now,
  List<TripRecord> history = const [],
}) {
  final h = (now ?? DateTime.now()).hour;
  // Course seule vers un centre commercial : offre mode.
  if (destination.name == 'Morocco Mall' && option.seul && !option.electric) return zaraPromo;
  // Gare tôt le matin : café.
  if (destination.name.startsWith('Gare') && h >= 6 && h < 11) return cafePromo;
  // Bord de mer, centres commerciaux l'après-midi, ou habitué de ces lieux : smoothie.
  final regular = history.where((t) => !t.scheduled && _seaPlaces.contains(t.destination)).length >= 2;
  if (_seaPlaces.contains(destination.name) ||
      (_shoppingPlaces.contains(destination.name) && h >= 12 && h < 20) ||
      regular) {
    return koolsmoothiePromo;
  }
  return null;
}
