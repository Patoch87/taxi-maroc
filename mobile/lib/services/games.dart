import 'dart:math';

import 'package:flutter/material.dart';

import 'coupons.dart';
import 'promos.dart';

/// Petits jeux pendant le trajet (passager à bord). Gagner donne un cadeau offert par un partenaire
/// fictif (exemples de démonstration), enregistré dans « Mes offres ». Une partie par jeu et par course.
enum TripGame { scratch, wheel, quiz }

/// Cadeaux des partenaires fictifs de la démo (marques inventées, tourisme au Maroc).
const riadTeaGift = Promo(
  id: 'KSARBAHJA',
  brand: 'Riad Ksar Bahja',
  initials: 'KB',
  titleKey: 'giftRiadTea',
  detailKey: 'giftDetail',
  address: 'Riad Ksar Bahja, médina de Marrakech (exemple fictif)',
  icon: Icons.emoji_food_beverage_outlined,
  color: Color(0xFF8D3B2A),
  partnerGift: true,
);

const desertNightGift = Promo(
  id: 'SAHARALUNE',
  brand: 'Sahara Lune',
  initials: 'SL',
  titleKey: 'giftDesertNight',
  detailKey: 'giftDetail',
  address: 'Sahara Lune, excursions Merzouga (exemple fictif)',
  icon: Icons.nightlight_round,
  color: Color(0xFFC8742A),
  partnerGift: true,
);

const sharedRideGift = Promo(
  id: 'BABRIDE',
  brand: 'Bab Taxi',
  initials: 'BT',
  titleKey: 'giftSharedRide',
  detailKey: 'giftDetail',
  address: 'Application Bab Taxi',
  icon: Icons.local_taxi_outlined,
  color: Color(0xFFC1272D),
  partnerGift: true,
);

const tripGifts = [riadTeaGift, desertNightGift, sharedRideGift];

/// Parties déjà jouées : identifiant de la course → jeux joués.
final _played = <String, Set<TripGame>>{};

bool hasPlayed(String tripId, TripGame game) => _played[tripId]?.contains(game) ?? false;

void markPlayed(String tripId, TripGame game) => (_played[tripId] ??= <TripGame>{}).add(game);

/// Pour les tests.
void resetGames() => _played.clear();

/// Cadeau tiré au hasard parmi ceux des partenaires.
Promo randomGift([Random? rnd]) => tripGifts[(rnd ?? Random()).nextInt(tripGifts.length)];

/// Enregistre le cadeau gagné dans « Mes offres » et le renvoie.
Coupon awardGift(Promo gift, String tripId, TripGame game) {
  final c = Coupon(promo: gift, tripId: '$tripId${game.name.substring(0, 1).toUpperCase()}', issuedAt: DateTime.now());
  saveCoupon(c);
  return c;
}

/// Questions du quiz : clé de la question, réponses (noms propres, les mêmes dans toutes les langues),
/// index de la bonne réponse.
const quizQuestions = [
  ('quizQ1', ['Casablanca', 'Rabat', 'Fès'], 0),
  ('quizQ2', ['Koutoubia', 'Hassan II', 'Karaouiyine'], 1),
  ('quizQ3', ['Marrakech', 'Tanger', 'Rabat'], 2),
];
