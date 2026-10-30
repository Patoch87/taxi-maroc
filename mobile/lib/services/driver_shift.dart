/// Compteur du chauffeur : passagers à bord, places libres et bilan de la journée.
/// Indépendant de l'affichage pour être testé facilement.
class ShiftRider {
  ShiftRider(
      {required this.name,
      required this.pickupIdx,
      required this.dropIdx,
      required this.fare,
      this.seats = 1,
      this.tip = 0,
      this.rating = 0});
  final String name;

  /// Positions sur l'itinéraire du taxi (indices des points).
  final int pickupIdx;
  final int dropIdx;
  final double fare;

  /// Pourboire laissé par carte à la fin de la course (démo).
  final double tip;

  /// Note laissée par le passager à la fin de la course (démo ; 0 = pas de note).
  final int rating;
  final int seats;
  bool onBoard = false;
}

/// Prime qualité payée par Bab Taxi au chauffeur en fin de mois (rien n'est demandé au passager).
/// Elle dépend de deux choses :
/// - la note moyenne de toutes les courses notées du mois, qui fixe la prime par course ;
/// - le nombre de courses faites dans le mois, qui multiplie cette prime (plus il roule avec
///   Bab Taxi, plus chaque course rapporte).
/// La prime suit le chauffeur (sa carte professionnelle), pas le véhicule : un chauffeur qui
/// conduit plusieurs taxis dans le mois additionne les courses et les notes de tous ses taxis.
class RatingBonus {
  /// Paliers : note moyenne minimale → prime par course du mois.
  static const tiers = [(4.9, 2.0), (4.8, 1.5), (4.6, 1.0)];

  /// Paliers de volume : courses du mois (tous taxis confondus) → multiplicateur de la prime.
  static const volumeTiers = [(200, 1.3), (150, 1.2), (100, 1.1)];

  /// Nombre minimum de courses notées dans le mois pour toucher la prime.
  static const minRides = 20;

  /// Prime par course pour une note moyenne donnée (0 sous le dernier palier).
  static double perRide(double average) {
    for (final (min, amount) in tiers) {
      if (average >= min - 1e-9) return amount;
    }
    return 0;
  }

  /// Multiplicateur selon le nombre de courses du mois (×1 sous le premier palier).
  static double volumeFactor(int rides) {
    for (final (min, factor) in volumeTiers) {
      if (rides >= min) return factor;
    }
    return 1;
  }

  /// Prime du mois : prime par course × multiplicateur de volume × nombre de courses du mois.
  /// [rated] = courses notées (minimum [minRides]) ; par défaut toutes les courses sont notées.
  static double forMonth({required double average, required int rides, int? rated}) =>
      (rated ?? rides) >= minRides ? perRide(average) * volumeFactor(rides) * rides : 0;
}

class DriverShift {
  DriverShift({this.capacity = 3});

  /// 3 places en petit taxi, 6 en grand taxi.
  int capacity;

  /// Passagers réservés par l'application (en attente ou à bord).
  final riders = <ShiftRider>[];

  /// Passagers pris dans la rue, sans l'application.
  int hailOnBoard = 0;

  int passengersToday = 0;
  int ridesToday = 0;
  double earningsToday = 0;

  /// Pourboires reçus aujourd'hui (payés par carte par les passagers).
  double tipsToday = 0;

  /// Notes reçues aujourd'hui (somme et nombre), pour la prime qualité du mois.
  int ratingSumToday = 0;
  int ratedToday = 0;

  void _rated(ShiftRider r) {
    if (r.rating <= 0) return;
    ratingSumToday += r.rating;
    ratedToday++;
  }

  int get onBoard => riders.where((r) => r.onBoard).fold(0, (n, r) => n + r.seats) + hailOnBoard;

  /// Places déjà promises (à bord + passagers acceptés en attente).
  int get reserved => riders.fold(0, (n, r) => n + r.seats) + hailOnBoard;

  int get freeSeats => capacity - reserved;
  bool get isFull => freeSeats <= 0;

  bool canAccept(int seats) => seats <= freeSeats;

  void accept(ShiftRider r) {
    if (!canAccept(r.seats)) throw StateError('Plus assez de places');
    riders.add(r);
  }

  /// Passager pris dans la rue : +1 à chaque personne qui monte.
  bool addHail() {
    if (isFull) return false;
    hailOnBoard++;
    passengersToday++;
    return true;
  }

  bool removeHail() {
    if (hailOnBoard == 0) return false;
    hailOnBoard--;
    return true;
  }

  /// Le chauffeur a touché « Démarrer la course » : le passager est à bord.
  void pickUp(ShiftRider r) {
    if (r.onBoard) return;
    r.onBoard = true;
    passengersToday += r.seats;
  }

  /// Test réel : le passager est descendu.
  void dropOff(ShiftRider r) {
    if (!riders.remove(r)) return;
    ridesToday++;
    earningsToday += r.fare;
    tipsToday += r.tip;
    _rated(r);
  }

  /// Passagers dont le taxi a atteint le point de prise en charge, pas encore à bord :
  /// le taxi les attend jusqu'à ce que le chauffeur démarre la course ([pickUp]).
  List<ShiftRider> waitingAt(int pos) => [
        for (final r in riders)
          if (!r.onBoard && pos >= r.pickupIdx) r
      ];

  /// Met à jour les descentes quand le taxi atteint la position [pos] et renvoie les passagers déposés.
  /// Les montées ne sont jamais automatiques : c'est le chauffeur qui démarre chaque course.
  List<ShiftRider> advance(int pos) {
    final dropped = <ShiftRider>[];
    for (final r in riders.where((r) => r.onBoard && pos >= r.dropIdx).toList()) {
      riders.remove(r);
      ridesToday++;
      earningsToday += r.fare;
      tipsToday += r.tip;
      _rated(r);
      dropped.add(r);
    }
    return dropped;
  }

  /// Prochains arrêts, dans l'ordre de la route : (est une montée, passager, indice).
  List<({bool pickup, ShiftRider rider, int idx})> nextStops() {
    final stops = [
      for (final r in riders) ...[
        if (!r.onBoard) (pickup: true, rider: r, idx: r.pickupIdx),
        (pickup: false, rider: r, idx: r.dropIdx),
      ],
    ]..sort((a, b) => a.idx.compareTo(b.idx));
    return stops;
  }
}
