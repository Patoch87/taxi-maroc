/// Compteur du chauffeur : passagers à bord, places libres et bilan de la journée.
/// Indépendant de l'affichage pour être testé facilement.
class ShiftRider {
  ShiftRider({required this.name, required this.pickupIdx, required this.dropIdx, required this.fare, this.seats = 1});
  final String name;

  /// Positions sur l'itinéraire du taxi (indices des points).
  final int pickupIdx;
  final int dropIdx;
  final double fare;
  final int seats;
  bool onBoard = false;
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

  /// Met à jour les montées et descentes quand le taxi atteint la position [pos].
  /// Renvoie les passagers montés et descendus à cette étape.
  ({List<ShiftRider> pickedUp, List<ShiftRider> dropped}) advance(int pos) {
    final pickedUp = <ShiftRider>[];
    final dropped = <ShiftRider>[];
    for (final r in riders) {
      if (!r.onBoard && pos >= r.pickupIdx) {
        r.onBoard = true;
        passengersToday += r.seats;
        pickedUp.add(r);
      }
    }
    for (final r in riders.where((r) => r.onBoard && pos >= r.dropIdx).toList()) {
      riders.remove(r);
      ridesToday++;
      earningsToday += r.fare;
      dropped.add(r);
    }
    return (pickedUp: pickedUp, dropped: dropped);
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
