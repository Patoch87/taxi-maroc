import 'dart:math';

/// Mode démo : fonctionne sans serveur, pour essayer l'application sur un téléphone.
/// Reprend les mêmes règles de prix que le serveur (backend/src/domain/fare.ts).
class Demo {
  static const priseEnCharge = 2.0;
  static const parKm = 3.5;
  static const minimum = 12.0;
  static const facteurRoute = 1.3;

  static double _distanceKm(Map<String, double> a, Map<String, double> b) {
    const r = 6371.0;
    double rad(double d) => d * pi / 180;
    final dLat = rad(b['lat']! - a['lat']!);
    final dLng = rad(b['lng']! - a['lng']!);
    final h = pow(sin(dLat / 2), 2) + cos(rad(a['lat']!)) * cos(rad(b['lat']!)) * pow(sin(dLng / 2), 2);
    return 2 * r * asin(sqrt(h));
  }

  static double _round(double v) => (v * 100).round() / 100;

  /// Frais Bab Taxi ajoutés à la course seule.
  static const fraisBab = 3.0;

  /// Compensation minimale du chauffeur quand elle n'est pas nulle.
  static const compensationMin = 10.0;

  /// Supplément premium : 5 MAD pour le chauffeur et 5 MAD pour Bab.
  static const supplementPremium = 10.0;

  /// Places d'un petit taxi.
  static const placesPetitTaxi = 3;

  /// Compteur estimé (avec la majoration de nuit) pour une distance réelle par la route.
  static double meter({required double routeKm, DateTime? date}) {
    var total = max(priseEnCharge + routeKm * parKm, minimum);
    final h = (date ?? DateTime.now()).hour;
    if (h >= 20 || h < 6) total *= 1.5;
    return _round(total);
  }

  /// Course seule : compteur + compensation chauffeur + 3 MAD de frais Bab.
  /// Compensation = places libres bloquées × 50 % × compteur (2 places libres pour 1 passager,
  /// 1 pour un groupe de 2, aucune pour 3), au moins 10 MAD quand elle n'est pas nulle.
  static SeulPrice seulPrice({required double compteur, int passengers = 1}) {
    final blocked = max(0, placesPetitTaxi - passengers.clamp(1, placesPetitTaxi));
    var compensation = blocked * 0.5 * compteur;
    if (compensation > 0) compensation = max(compensation, compensationMin);
    compensation = _round(compensation);
    return SeulPrice(compteur, compensation, fraisBab, _round(compteur + compensation + fraisBab));
  }

  /// Taxi premium : prix « Seul » (même calcul, même nombre de personnes) + 10 MAD de supplément premium.
  /// Toujours plus cher que « Seul ».
  static SeulPrice premiumPrice({required double compteur, int passengers = 1}) {
    final b = seulPrice(compteur: compteur, passengers: passengers);
    return SeulPrice(b.compteur, b.compensation, b.frais, _round(b.total + supplementPremium),
        premium: supplementPremium);
  }

  /// Prix du petit taxi pour une distance réelle par la route.
  /// Seul : compteur + compensation + frais. Premium : prix « Seul » + 10 MAD de supplément premium.
  static double petitTaxiPrice(
      {required double routeKm, required bool seul, required bool premium, DateTime? date, int passengers = 1}) {
    final compteur = meter(routeKm: routeKm, date: date);
    if (premium) return premiumPrice(compteur: compteur, passengers: passengers).total;
    if (seul) return seulPrice(compteur: compteur, passengers: passengers).total;
    return compteur;
  }

  static Map<String, dynamic> estimatePetitTaxi({
    required Map<String, double> depart,
    required Map<String, double> destination,
    required bool seul,
    required bool premium,
    DateTime? date,
    int passengers = 1,
  }) {
    final km = _distanceKm(depart, destination) * facteurRoute;
    final total = petitTaxiPrice(routeKm: km, seul: seul, premium: premium, date: date, passengers: passengers);
    return {'montantMad': total, 'details': <dynamic>[]};
  }

  /// Taxis fictifs qui passent sur la route du passager.
  static List<dynamic> findTaxis({required bool premium}) {
    final rnd = Random();
    final n = 1 + rnd.nextInt(3);
    return List.generate(n, (i) {
      final num = 1000 + rnd.nextInt(9000);
      return {
        'taxiId': premium ? 'PREMIUM-$num' : 'CASA-$num',
        'ecartDepartM': 20 + rnd.nextInt(250),
        'distanceAvantPriseEnChargeM': 200 + rnd.nextInt(1500),
      };
    })
      ..sort((a, b) => (a['distanceAvantPriseEnChargeM'] as int).compareTo(b['distanceAvantPriseEnChargeM'] as int));
  }
}

/// Détail du prix d'une course seule (ou premium : [premium] = supplément premium, 0 sinon).
class SeulPrice {
  const SeulPrice(this.compteur, this.compensation, this.frais, this.total, {this.premium = 0});
  final double compteur;
  final double compensation;
  final double frais;
  final double premium;
  final double total;
}
