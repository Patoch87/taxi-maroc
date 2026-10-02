import 'dart:math';

/// Mode démo : fonctionne sans serveur, pour essayer l'application sur un téléphone.
/// Reprend les mêmes règles de prix que le serveur (backend/src/domain/fare.ts).
class Demo {
  static const priseEnCharge = 2.0;
  static const parKm = 3.5;
  static const minimum = 7.5;
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

  /// Prix du petit taxi pour une distance réelle par la route.
  static double petitTaxiPrice({required double routeKm, required bool seul, required bool premium, DateTime? date}) {
    var total = max(priseEnCharge + routeKm * parKm, minimum);
    final h = (date ?? DateTime.now()).hour;
    if (h >= 20 || h < 6) total *= 1.5;
    if (seul) total *= 1.3;
    if (premium) total *= 1.5;
    return _round(total);
  }

  static Map<String, dynamic> estimatePetitTaxi({
    required Map<String, double> depart,
    required Map<String, double> destination,
    required bool seul,
    required bool premium,
    DateTime? date,
  }) {
    final km = _distanceKm(depart, destination) * facteurRoute;
    final total = petitTaxiPrice(routeKm: km, seul: seul, premium: premium, date: date);
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
