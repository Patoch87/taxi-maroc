/// Tableau de bord des gains du chauffeur : ce qu'il gagnait avant Bab Taxi (moyenne qu'il indique)
/// et ce que Bab Taxi lui rapporte en plus, semaine par semaine et mois par mois.
/// Indépendant de l'affichage pour être testé facilement. En démo, l'historique est simulé.
enum ExtraSource { rides, tips, ads, fuel }

class EarningsPeriod {
  EarningsPeriod({required this.start, required this.before, required this.extra});

  /// Premier jour de la période (lundi de la semaine, ou 1er du mois).
  final DateTime start;

  /// Ce que le chauffeur aurait gagné sans Bab Taxi sur la période (sa moyenne déclarée).
  final double before;

  /// Gains en plus grâce à Bab Taxi, par origine.
  final Map<ExtraSource, double> extra;

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
    return {
      ExtraSource.rides: (250 + 9 * i + wobble).roundToDouble(),
      ExtraSource.tips: (24 + 2 * i + wobble / 6).roundToDouble(),
      ExtraSource.ads: (38 + i).toDouble(),
      ExtraSource.fuel: (48 + 2 * i + wobble / 4).roundToDouble(),
    };
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
          return EarningsPeriod(start: start, before: beforePerDay * days, extra: {
            for (final e in base.entries) e.key: (e.value * f).roundToDouble(),
          }
            ..update(ExtraSource.rides, (v) => v + todayRides)
            ..update(ExtraSource.tips, (v) => v + todayTips));
        }(),
    ];
  }

  /// Les [count] derniers mois, du plus ancien au mois en cours (partiel).
  List<EarningsPeriod> months(DateTime now, {int count = 6, double todayRides = 0, double todayTips = 0}) {
    final current = monthStart(now);
    final perMonth = beforePerDay * workDaysPerWeek * 52 / 12;
    return [
      for (var k = count - 1; k >= 0; k--)
        () {
          final start = DateTime(current.year, current.month - k);
          // Un mois de démo ≈ 4,33 semaines de la même période d'utilisation.
          final w = demoWeek((count - 1 - k) * 4 ~/ 3);
          final full = {for (final e in w.entries) e.key: (e.value * 52 / 12).roundToDouble()};
          if (k > 0) return EarningsPeriod(start: start, before: perMonth, extra: full);
          final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
          final f = now.day / daysInMonth;
          return EarningsPeriod(start: start, before: (perMonth * f).roundToDouble(), extra: {
            for (final e in full.entries) e.key: (e.value * f).roundToDouble(),
          }
            ..update(ExtraSource.rides, (v) => v + todayRides)
            ..update(ExtraSource.tips, (v) => v + todayTips));
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
