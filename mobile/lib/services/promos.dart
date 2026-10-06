import 'package:flutter/material.dart';

import 'places.dart';
import 'rides.dart';

/// Offre contextuelle (données de démo), montrée seulement pendant la course, passager à bord.
/// Chaque carte porte la mention « Exemple publicitaire (démo) » : ces enseignes ne sont pas partenaires.
///
/// Logos : la démo ne reproduit aucun logo de marque. Elle dessine un badge sobre (initiales sur la
/// couleur de l'annonceur). En production, les vrais logos sont fournis par les annonceurs sous contrat.
class Promo {
  const Promo({
    required this.id,
    required this.brand,
    required this.initials,
    required this.titleKey,
    required this.detailKey,
    required this.address,
    required this.icon,
    required this.color,
  });

  /// Identifiant court, repris dans le code du bon (lettres majuscules).
  final String id;
  final String brand;

  /// Initiales du badge qui remplace le logo.
  final String initials;

  /// Clés de traduction (S) du titre et des conditions de l'offre.
  final String titleKey;
  final String detailKey;

  /// Adresse du magasin où présenter le bon.
  final String address;
  final IconData icon;
  final Color color;
}

const fashionPromo = Promo(
  id: 'MODE',
  brand: 'Zara',
  initials: 'Z',
  titleKey: 'offerFashion',
  detailKey: 'offerFashionDetail',
  address: 'Morocco Mall, niveau 1, Boulevard de la Corniche, Aïn Diab',
  icon: Icons.shopping_bag_outlined,
  color: Color(0xFF14213D),
);

const koolsmoothiePromo = Promo(
  id: 'KOOL',
  brand: 'Koolsmoothie',
  initials: 'KS',
  titleKey: 'offerKool',
  detailKey: 'offerKoolDetail',
  address: 'Morocco Mall, espace restauration, Aïn Diab',
  icon: Icons.local_drink_outlined,
  color: Color(0xFF2E9E44),
);

const portCafePromo = Promo(
  id: 'PORT',
  brand: 'Café du Port',
  initials: 'CP',
  titleKey: 'offerPortCafe',
  detailKey: 'offerPortCafeDetail',
  address: 'Gare Casa Port, hall principal, Boulevard des Almohades',
  icon: Icons.coffee_outlined,
  color: Color(0xFF8A5A00),
);

const sportPromo = Promo(
  id: 'SPORT',
  brand: 'Anfa Sport',
  initials: 'AS',
  titleKey: 'offerSport',
  detailKey: 'offerSportDetail',
  address: 'Anfa Place, rez-de-chaussée, Boulevard de la Corniche',
  icon: Icons.sports_soccer_outlined,
  color: Color(0xFFC1272D),
);

const lunchPromo = Promo(
  id: 'TWIN',
  brand: 'Le Comptoir du Twin',
  initials: 'CT',
  titleKey: 'offerLunch',
  detailKey: 'offerLunchDetail',
  address: 'Twin Center, tour Ouest, rez-de-chaussée, Maârif',
  icon: Icons.restaurant_outlined,
  color: Color(0xFF5B3A8E),
);

const teaPromo = Promo(
  id: 'CORNICHE',
  brand: 'Café Corniche Bleue',
  initials: 'CB',
  titleKey: 'offerTea',
  detailKey: 'offerTeaDetail',
  address: 'Boulevard de la Corniche, Aïn Diab',
  icon: Icons.emoji_food_beverage_outlined,
  color: Color(0xFF1565C0),
);

/// Toutes les offres de la démo.
const allPromos = [fashionPromo, koolsmoothiePromo, portCafePromo, sportPromo, lunchPromo, teaPromo];

/// Bandeau générique, non personnalisé (quand aucune offre ne correspond au trajet).
const genericPromo = Promo(
  id: 'GEN',
  brand: 'Bab Taxi',
  initials: 'TM',
  titleKey: 'promoGeneric',
  detailKey: 'promoGenericDetail',
  address: '',
  icon: Icons.campaign_outlined,
  color: Color(0xFFC1272D),
);

const _seaPlaces = {'Ain Diab', 'Morocco Mall', 'Mosquée Hassan II', 'Anfa Place'};

/// Offres pertinentes selon la destination, l'heure et les trajets passés, la meilleure d'abord.
/// Jamais selon le revenu, le quartier d'habitation ou d'autres données personnelles.
List<Promo> promosFor({
  required Place destination,
  required RideOption option,
  DateTime? now,
  List<TripRecord> history = const [],
}) {
  final t = now ?? DateTime.now();
  final h = t.hour;
  final weekday = t.weekday <= DateTime.friday;
  final regular = history.where((r) => !r.scheduled && _seaPlaces.contains(r.destination)).length >= 2;
  final name = destination.name;
  return [
    if (name == 'Morocco Mall') fashionPromo,
    if (name == 'Anfa Place') sportPromo,
    if (name == 'Twin Center' && weekday && h >= 11 && h < 15) lunchPromo,
    if (name.startsWith('Gare') && h >= 6 && h < 11) portCafePromo,
    if (name == 'Ain Diab' || name == 'Mosquée Hassan II') teaPromo,
    // Koolsmoothie avant 18 h : bord de mer et centres commerciaux, ou habitué de ces lieux.
    if (h < 18 && (_seaPlaces.contains(name) || name == 'Twin Center' || regular)) koolsmoothiePromo,
  ];
}

/// La meilleure offre pour ce trajet, ou aucune.
Promo? pickPromo({
  required Place destination,
  required RideOption option,
  DateTime? now,
  List<TripRecord> history = const [],
}) =>
    promosFor(destination: destination, option: option, now: now, history: history).firstOrNull;
