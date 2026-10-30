import 'driver_shift.dart';

/// Tableau de bord des gains du chauffeur : ce qu'il gagnait avant Bab Taxi (moyenne qu'il indique)
/// et ce que Bab Taxi lui rapporte en plus, semaine par semaine et mois par mois.
/// Indépendant de l'affichage pour être testé facilement. En démo, l'historique est simulé.
enum ExtraSource { rides, rating, tips, ads, fuel }

/// Taxi conduit par le chauffeur (démo) : il peut en conduire plusieurs dans le mois, par exemple
/// un petit taxi en ville et un grand taxi le week-end. Les courses de tous ses taxis comptent
/// pour sa prime.
enum DemoTaxi {
  petit('2417'),
  grand('318');

  const DemoTaxi(this.number);
  final String number;

  /// Part des courses du mois faites avec ce taxi (démo).
  double get share => this == petit ? 2 / 3 : 1 / 3;
}

class EarningsPeriod {
  EarningsPeriod(
      {required this.start,
      required this.before,
      required this.extra,
      this.rating = 0,
      this.ratedRides = 0,
      this.rides = 0,
      this.ridesByTaxi = const {}});

  /// Premier jour de la période (lundi de la semaine, ou 1er du mois).
  final DateTime start;

  /// Ce que le chauffeur aurait gagné sans Bab Taxi sur la période (sa moyenne déclarée).
  final double before;

  /// Gains en plus grâce à Bab Taxi, par origine.
  final Map<ExtraSource, double> extra;

  /// Mois seulement : note moyenne des courses notées et nombre de courses du mois (prime qualité).
  final double rating;
  final int ratedRides;

  /// Mois seulement : toutes les courses du mois (notées ou non), tous taxis confondus, et leur
  /// répartition par taxi conduit (un chauffeur peut conduire plusieurs taxis dans le mois).
  final int rides;
  final Map<DemoTaxi, int> ridesByTaxi;

  double get extraTotal => extra.values.fold(0.0, (a, b) => a + b);
  double get withBab => before + extraTotal;

  /// Hausse par rapport à avant (0,27 = +27 %).
  double get increase => before <= 0 ? 0 : extraTotal / before;
}

class DriverEarnings {
  DriverEarnings({this.beforePerDay = 250, this.workDaysPerWeek = 6});

  /// Ce que le chauffeur gagnait par jour avant Bab Taxi (il peut le modifier).
  double beforePerDay;
  int workDaysPerWeek;

  static const minBefore = 100.0;
  static const maxBefore = 600.0;

  static DateTime weekStart(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - 1));
  static DateTime monthStart(DateTime d) => DateTime(d.year, d.month);

  /// Gains en plus d'une semaine de démo : ils montent à mesure que le chauffeur utilise
  /// l'application (indice 0 = la semaine la plus ancienne). Environ 1 500 à 2 000 DH par mois.
  static Map<ExtraSource, double> demoWeek(int i) {
    final wobble = [0, 18, -12, 26, 6, -8, 22, 10][i % 8].toDouble();
    // La prime qualité n'apparaît pas ici : elle est versée en fin de mois (voir [months]).
    return {
      ExtraSource.rides: (232 + 7 * i + wobble).roundToDouble(),
      ExtraSource.tips: (24 + 2 * i + wobble / 6).roundToDouble(),
      ExtraSource.ads: (38 + i).toDouble(),
      ExtraSource.fuel: (48 + 2 * i + wobble / 4).roundToDouble(),
    };
  }

  /// Note moyenne, nombre de courses notées et nombre total de courses Bab Taxi d'un mois de démo
  /// (indice 0 = le plus ancien) : la note et le nombre de courses montent à mesure que le
  /// chauffeur utilise l'application. Environ 1 course sur 13 n'est pas notée.
  static (double, int, int) demoMonthRating(int j) {
    const avg = [4.62, 4.71, 4.78, 4.83, 4.86, 4.91, 4.92, 4.93, 4.94];
    final rated = 95 + 6 * j;
    return (avg[j.clamp(0, avg.length - 1)], rated, (rated * 1.08).round());
  }

  /// Répartition des courses d'un mois entre les taxis conduits (démo) ; les courses du service
  /// en cours vont au taxi choisi aujourd'hui.
  static Map<DemoTaxi, int> splitByTaxi(int rides, {int today = 0, DemoTaxi todayTaxi = DemoTaxi.petit}) {
    final petit = (rides * DemoTaxi.petit.share).round();
    final m = {DemoTaxi.petit: petit, DemoTaxi.grand: rides - petit};
    m.update(todayTaxi, (v) => v + today);
    return m;
  }

  /// Les [count] dernières semaines, de la plus ancienne à la semaine en cours.
  /// La semaine en cours est partielle (jours écoulés) et compte les gains du service du jour.
  List<EarningsPeriod> weeks(DateTime now, {int count = 8, double todayRides = 0, double todayTips = 0}) {
    final current = weekStart(now);
    final perWeek = beforePerDay * workDaysPerWeek;
    return [
      for (var k = count - 1; k >= 0; k--)
        () {
          final start = DateTime(current.year, current.month, current.day - 7 * k);
          final base = demoWeek(count - 1 - k);
          if (k > 0) return EarningsPeriod(start: start, before: perWeek, extra: base);
          // Semaine en cours : au prorata des jours travaillés jusqu'à aujourd'hui.
          final days = now.weekday.clamp(1, workDaysPerWeek);
          final f = days / workDaysPerWeek;
          return EarningsPeriod(
              start: start,
              before: beforePerDay * days,
              extra: {
                for (final e in base.entries) e.key: (e.value * f).roundToDouble(),
              }
                ..update(ExtraSource.rides, (v) => v + todayRides)
                ..update(ExtraSource.tips, (v) => v + todayTips));
        }(),
    ];
  }

  /// Les [count] derniers mois, du plus ancien au mois en cours (partiel).
  List<EarningsPeriod> months(DateTime now,
      {int count = 6,
      double todayRides = 0,
      double todayTips = 0,
      int todayRatingSum = 0,
      int todayRated = 0,
      int todayRideCount = 0,
      DemoTaxi todayTaxi = DemoTaxi.petit}) {
    final current = monthStart(now);
    final perMonth = beforePerDay * workDaysPerWeek * 52 / 12;
    return [
      for (var k = count - 1; k >= 0; k--)
        () {
          final start = DateTime(current.year, current.month - k);
          // Un mois de démo ≈ 4,33 semaines de la même période d'utilisation.
          final j = (count - 1 - k) * 4 ~/ 3;
          final w = demoWeek(j);
          final full = {for (final e in w.entries) e.key: (e.value * 52 / 12).roundToDouble()};
          final (avg, rated, rides) = demoMonthRating(j);
          if (k > 0) {
            return EarningsPeriod(
                start: start,
                before: perMonth,
                extra: {...full, ExtraSource.rating: RatingBonus.forMonth(average: avg, rides: rides, rated: rated)},
                rating: avg,
                ratedRides: rated,
                rides: rides,
                ridesByTaxi: splitByTaxi(rides));
          }
          // Mois en cours : prime estimée avec la note moyenne et les courses jusqu'à aujourd'hui
          // (versée en fin de mois).
          final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
          final f = now.day / daysInMonth;
          final soFar = (rated * f).round();
          final n = soFar + todayRated;
          final average = n == 0 ? 0.0 : (avg * soFar + todayRatingSum) / n;
          final ridesSoFar = (rides * f).round();
          final total = ridesSoFar + todayRideCount;
          return EarningsPeriod(
              start: start,
              before: (perMonth * f).roundToDouble(),
              extra: {
                for (final e in full.entries) e.key: (e.value * f).roundToDouble(),
                ExtraSource.rating: RatingBonus.forMonth(average: average, rides: total, rated: n),
              }
                ..update(ExtraSource.rides, (v) => v + todayRides)
                ..update(ExtraSource.tips, (v) => v + todayTips),
              rating: average,
              ratedRides: n,
              rides: total,
              ridesByTaxi: splitByTaxi(ridesSoFar, today: todayRideCount, todayTaxi: todayTaxi));
        }(),
    ];
  }

  /// Nombre de périodes complètes de suite (en partant de la plus récente) où le gain en plus a monté.
  static int risingStreak(List<EarningsPeriod> periods) {
    final done = periods.length > 1 ? periods.sublist(0, periods.length - 1) : periods;
    var n = 0;
    for (var i = done.length - 1; i > 0 && done[i].extraTotal > done[i - 1].extraTotal; i--) {
      n++;
    }
    return n;
  }

  /// Total gagné en plus sur toutes les périodes.
  static double totalExtra(List<EarningsPeriod> periods) => periods.fold(0.0, (a, p) => a + p.extraTotal);
}

/// Gains du chauffeur de cette session (démo : en mémoire).
final driverEarnings = DriverEarnings();
