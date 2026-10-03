import 'dart:math';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../main.dart';
import '../theme.dart';
import 'demo.dart';
import 'places.dart';

enum TaxiKind { petit, premium, grand }

/// Une option de course proposée au passager, avec son prix affiché à l'avance.
class RideOption {
  const RideOption({
    required this.id,
    required this.title,
    required this.description,
    required this.kind,
    required this.priceMad,
    required this.seats,
    this.seul = false,
  });
  final String id;
  final String title;
  final String description;
  final TaxiKind kind;
  final double priceMad;
  final int seats;
  final bool seul;
}

/// Prix fixes par place des grands taxis (mêmes valeurs que backend/src/domain/tariffs.ts).
const grandTaxiPrixPlace = {'casa-mohammedia': 12.0, 'casa-berrechid': 15.0, 'casa-eljadida': 40.0};

List<RideOption> rideOptions({required Place destination, required double routeM, DateTime? date}) {
  if (destination.intercity) {
    final prix = grandTaxiPrixPlace[destination.ligne]!;
    return [
      RideOption(
          id: 'grand',
          title: s.t('grandSeat'),
          description: s.t('grandDesc'),
          kind: TaxiKind.grand,
          priceMad: prix,
          seats: 1),
      RideOption(
          id: 'grand-entier',
          title: s.t('grandWhole'),
          description: s.t('aloneDesc'),
          kind: TaxiKind.grand,
          priceMad: prix * 6,
          seats: 6,
          seul: true),
    ];
  }
  double price(bool seul, bool premium) =>
      Demo.petitTaxiPrice(routeKm: routeM / 1000, seul: seul, premium: premium, date: date);
  return [
    RideOption(
        id: 'partage',
        title: s.t('petitTaxi'),
        description: s.t('sharedDesc'),
        kind: TaxiKind.petit,
        priceMad: price(false, false),
        seats: 3),
    RideOption(
        id: 'seul',
        title: s.t('aloneTitle'),
        description: s.t('aloneDesc'),
        kind: TaxiKind.petit,
        priceMad: price(true, false),
        seats: 3,
        seul: true),
    RideOption(
        id: 'premium',
        title: s.t('premium'),
        description: s.t('premiumDesc'),
        kind: TaxiKind.premium,
        priceMad: price(true, true),
        seats: 3,
        seul: true),
  ];
}

/// Montant en dirhams, avec la virgule en français et en arabe (8,44 DH) et le point en anglais.
String dh(double v) {
  final txt = v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
  return '${langNotifier.value == 'en' ? txt : txt.replaceAll('.', ',')} DH';
}

/// Distance lisible : « 850 m » ou « 2,2 km ».
String distanceText(double m) {
  if (m < 1000) return '${m.round()} m';
  final km = (m / 1000).toStringAsFixed(1);
  return '${langNotifier.value == 'en' ? km : km.replaceAll('.', ',')} km';
}

Color taxiColor(TaxiKind k) => switch (k) {
      TaxiKind.petit => AppColors.taxiRed,
      TaxiKind.premium => AppColors.ink,
      TaxiKind.grand => AppColors.grandTaxi,
    };

/// Couleur de la voiture, annoncée à voix haute (clé de traduction) : petits taxis rouges à Casablanca,
/// taxis premium noirs, grands taxis beiges.
String carColorKey(TaxiKind k) => switch (k) {
      TaxiKind.petit => 'colorRed',
      TaxiKind.premium => 'colorBlack',
      TaxiKind.grand => 'colorBeige',
    };

/// Langue parlée par un chauffeur, avec son petit drapeau.
class DriverLanguage {
  const DriverLanguage(this.flag, this.name);
  final String flag;
  final String name;
}

const darija = DriverLanguage('🇲🇦', 'Darija');
const arabe = DriverLanguage('🇲🇦', 'العربية');
const tamazight = DriverLanguage('ⵣ', 'Tamazight');
const francais = DriverLanguage('🇫🇷', 'Français');
const anglais = DriverLanguage('🇬🇧', 'English');
const espagnol = DriverLanguage('🇪🇸', 'Español');

/// Chauffeur fictif pour la démo.
class DemoDriver {
  DemoDriver(this.name, this.taxiNumber, this.plate, this.rating, this.car, this.languages, this.rides);
  final String name;
  final String taxiNumber;
  final String plate;
  final double rating;
  final String car;
  final List<DriverLanguage> languages;
  final int rides;

  /// Avatar illustré (pas de vraie photo dans la démo) ; les vrais chauffeurs auront leur photo vérifiée.
  String get photoUrl =>
      'https://api.dicebear.com/9.x/avataaars/png?size=160&backgroundColor=e8e2d0&seed=${Uri.encodeComponent(name)}';

  static DemoDriver random(TaxiKind kind, Random rnd) {
    const names = [
      'Youssef B.',
      'Abdelkader M.',
      'Hicham E.',
      'Rachid T.',
      'Said A.',
      'Mustapha K.',
      'Khadija L.',
      'Nabil O.'
    ];
    const langSets = [
      [darija, francais],
      [darija, francais, anglais],
      [darija, tamazight, francais],
      [darija, arabe, espagnol],
      [darija, francais, anglais, espagnol],
    ];
    final car = switch (kind) {
      TaxiKind.petit => 'Dacia Logan',
      TaxiKind.premium => 'Toyota Corolla Hybride',
      TaxiKind.grand => 'Dacia Lodgy',
    };
    return DemoDriver(
      names[rnd.nextInt(names.length)],
      'Taxi n° ${1000 + rnd.nextInt(9000)}',
      // Marque de gauche à droite après la lettre arabe : la plaque se lit « 12345 | أ | 6 » dans toutes les langues.
      '${10000 + rnd.nextInt(89999)} | أ\u200E | 6',
      4.5 + rnd.nextInt(5) / 10,
      car,
      langSets[rnd.nextInt(langSets.length)],
      200 + rnd.nextInt(4000),
    );
  }
}

/// Course enregistrée dans l'historique.
class TripRecord {
  TripRecord(
      {required this.destination,
      required this.option,
      required this.price,
      required this.date,
      this.driver,
      this.scheduled = false,
      this.tip = 0,
      this.rating = 0,
      this.passengerName});
  final String destination;
  final String option;
  final double price;
  final DateTime date;
  final DemoDriver? driver;
  final bool scheduled;

  /// Course commandée pour quelqu'un d'autre : nom du passager.
  final String? passengerName;
  double tip;
  int rating;
}

/// Historique des courses de la session.
final tripHistory = <TripRecord>[];

/// Taxis fictifs autour d'un point, pour animer la carte en mode démo.
List<LatLng> ambientTaxis(LatLng center, Random rnd, {int count = 7}) => List.generate(count, (_) {
      final r = 0.004 + rnd.nextDouble() * 0.012;
      final a = rnd.nextDouble() * 2 * pi;
      return LatLng(center.latitude + r * sin(a), center.longitude + r * cos(a));
    });
