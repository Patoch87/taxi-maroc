import 'package:flutter/material.dart';

import '../main.dart';
import '../l10n/strings.dart';
import '../services/driver_earnings.dart';
import '../services/driver_shift.dart';
import '../services/rides.dart';
import '../theme.dart';
import '../widgets/app_logo.dart';

/// « Mes gains » : ce que le chauffeur gagne de plus avec Bab Taxi, comparé à ce qu'il gagnait
/// avant (moyenne qu'il indique), par semaine ou par mois, et d'où viennent ces gains en plus.
class EarningsScreen extends StatefulWidget {
  const EarningsScreen(
      {super.key,
      this.todayRides = 0,
      this.todayTips = 0,
      this.todayRatingSum = 0,
      this.todayRated = 0,
      this.todayRideCount = 0,
      this.todayTaxi = DemoTaxi.petit,
      this.now});

  /// Gains du service en cours (courses Bab Taxi et pourboires), ajoutés à la période en cours.
  final double todayRides;
  final double todayTips;

  /// Notes du service en cours (somme et nombre), pour la prime qualité du mois.
  final int todayRatingSum;
  final int todayRated;

  /// Courses du service en cours et taxi conduit aujourd'hui : les courses de tous les taxis du
  /// chauffeur s'additionnent pour la prime du mois.
  final int todayRideCount;
  final DemoTaxi todayTaxi;

  /// Date du jour (tests).
  final DateTime? now;

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  bool _monthly = false;

  static const _sources = [
    (ExtraSource.rides, Icons.alt_route, 'earnSrcRides'),
    (ExtraSource.rating, Icons.star_rounded, 'earnSrcRating'),
    (ExtraSource.tips, Icons.volunteer_activism_outlined, 'earnSrcTips'),
    (ExtraSource.ads, Icons.campaign_outlined, 'earnSrcAds'),
    (ExtraSource.fuel, Icons.local_gas_station_outlined, 'earnSrcFuel'),
  ];

  List<EarningsPeriod> get _periods {
    final now = widget.now ?? DateTime.now();
    return _monthly
        ? driverEarnings.months(now,
            todayRides: widget.todayRides,
            todayTips: widget.todayTips,
            todayRatingSum: widget.todayRatingSum,
            todayRated: widget.todayRated,
            todayRideCount: widget.todayRideCount,
            todayTaxi: widget.todayTaxi)
        : driverEarnings.weeks(now, todayRides: widget.todayRides, todayTips: widget.todayTips);
  }

  String _label(EarningsPeriod p) {
    if (_monthly) return s.t('monthsShort').split(',')[p.start.month - 1];
    return '${p.start.day}/${p.start.month}';
  }

  String _pct(double v) => '+${(v * 100).round()} %';

  /// Montants arrondis au dirham : plus lisibles sur un tableau de bord.
  String _dh(double v) => dh(v.roundToDouble());

  @override
  Widget build(BuildContext context) {
    final periods = _periods;
    final cur = periods.last;
    final streak = DriverEarnings.risingStreak(periods);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('myEarnings'), style: const TextStyle(fontWeight: FontWeight.w800)),
        flexibleSpace: const Zellige(opacity: .06),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: false, label: Text(s.t('earnWeek'))),
              ButtonSegment(value: true, label: Text(s.t('earnMonth'))),
            ],
            selected: {_monthly},
            showSelectedIcon: false,
            onSelectionChanged: (v) => setState(() => _monthly = v.first),
          ),
          const SizedBox(height: 12),
          _hero(cur, streak),
          const SizedBox(height: 12),
          _compare(cur),
          const SizedBox(height: 12),
          _box(
            title: s.t('earnSources'),
            child: Column(children: [
              for (final (src, icon, key) in _sources)
                if (cur.extra.containsKey(src))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(color: AppColors.greenSoft, borderRadius: BorderRadius.circular(10)),
                        child: Icon(icon, size: 19, color: AppColors.moroccoGreen),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(s.t(key), style: const TextStyle(fontSize: 14))),
                      Text('+${_dh(cur.extra[src] ?? 0)}',
                          style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.moroccoGreen)),
                    ]),
                  ),
            ]),
          ),
          const SizedBox(height: 12),
          _ratingBonusBox(_monthly
              ? cur
              : driverEarnings
                  .months(widget.now ?? DateTime.now(),
                      todayRatingSum: widget.todayRatingSum,
                      todayRated: widget.todayRated,
                      todayRideCount: widget.todayRideCount,
                      todayTaxi: widget.todayTaxi)
                  .last),
          const SizedBox(height: 12),
          _box(title: s.t('earnHistory'), child: _chart(periods)),
          const SizedBox(height: 12),
          _beforeSetting(),
          const SizedBox(height: 10),
          Text(s.t('earnNote'), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _hero(EarningsPeriod cur, int streak) => Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(color: AppColors.moroccoGreen, borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_monthly ? s.t('earnThisMonth') : s.t('earnThisWeek'),
              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text('+${_dh(cur.extraTotal)}',
              key: const ValueKey('earnExtraTotal'),
              style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w900, height: 1.1)),
          Text(s.t('earnExtra'),
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 6, children: [
            _pill('${_pct(cur.increase)} ${s.t('earnVsBefore')}'),
            if (streak >= 2) _pill(s.t(_monthly ? 'earnStreakMonths' : 'earnStreakWeeks').replaceAll('{n}', '$streak')),
          ]),
          const SizedBox(height: 10),
          Text(s.t('earnKeepGoing'), style: const TextStyle(color: Colors.white, fontSize: 14)),
        ]),
      );

  Widget _pill(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
      );

  /// Deux barres : avant Bab Taxi, puis avec Bab Taxi (la part en plus en vert vif).
  Widget _compare(EarningsPeriod cur) {
    Widget bar(String label, double value, {double extra = 0}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
              Text(_dh(value + extra), style: const TextStyle(fontWeight: FontWeight.w900)),
            ]),
            const SizedBox(height: 5),
            LayoutBuilder(builder: (_, c) {
              final max = cur.withBab <= 0 ? 1 : cur.withBab;
              return Row(children: [
                Container(
                  width: c.maxWidth * value / max,
                  height: 16,
                  decoration: BoxDecoration(
                    color: extra > 0
                        ? AppColors.moroccoGreen.withValues(alpha: .45)
                        : AppColors.muted.withValues(alpha: .35),
                    borderRadius: BorderRadius.horizontal(
                        left: const Radius.circular(8), right: Radius.circular(extra > 0 ? 0 : 8)),
                  ),
                ),
                if (extra > 0)
                  Container(
                    width: c.maxWidth * extra / max,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: AppColors.moroccoGreen,
                      borderRadius: BorderRadius.horizontal(right: Radius.circular(8)),
                    ),
                  ),
              ]);
            }),
          ]),
        );
    return _box(
      child: Column(children: [
        bar(s.t('earnBefore'), cur.before),
        bar(s.t('earnWithBab'), cur.before, extra: cur.extraTotal),
      ]),
    );
  }

  /// Gains en plus de chaque période : barres vertes, la période en cours en doré.
  Widget _chart(List<EarningsPeriod> periods) {
    final done = periods.sublist(0, periods.length - 1);
    final max = periods.map((p) => p.extraTotal).fold(1.0, (a, b) => b > a ? b : a);
    return Column(children: [
      SizedBox(
        height: 150,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (final p in periods)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  FittedBox(
                    child: Text('+${p.extraTotal.round()}',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: identical(p, periods.last) ? AppColors.gold : AppColors.moroccoGreen)),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    height: 110 * p.extraTotal / max,
                    decoration: BoxDecoration(
                      color: identical(p, periods.last) ? AppColors.gold : AppColors.moroccoGreen,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    ),
                  ),
                ]),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 4),
      Row(children: [
        for (final p in periods)
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(_label(p), style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            ),
          ),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: Text(s.t('earnTotal'), style: const TextStyle(color: AppColors.muted))),
        Text('+${_dh(DriverEarnings.totalExtra(done))}',
            style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.moroccoGreen)),
      ]),
    ]);
  }

  /// Prime qualité du mois : note moyenne de toutes les courses du mois, prime estimée (versée en
  /// fin de mois) et paliers.
  Widget _ratingBonusBox(EarningsPeriod month) {
    final dec = S(langNotifier.value).decimalPoint;
    String num(double v, int d) => dec ? v.toStringAsFixed(d) : v.toStringAsFixed(d).replaceAll('.', ',');
    final per = RatingBonus.perRide(month.rating);
    final bonus = month.extra[ExtraSource.rating] ?? 0;
    final next = RatingBonus.tiers.reversed.where((t) => t.$1 > month.rating + 1e-9).firstOrNull;
    final factor = RatingBonus.volumeFactor(month.rides);
    final nextVolume = RatingBonus.volumeTiers.reversed.where((t) => t.$1 > month.rides).firstOrNull;
    String x(double f) => '×${num(f, f == f.roundToDouble() ? 0 : (f * 10 - (f * 10).round()).abs() < 1e-9 ? 1 : 2)}';
    return Container(
      key: const ValueKey('ratingBonus'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold, width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.star_rounded, color: AppColors.gold, size: 26),
          const SizedBox(width: 8),
          Expanded(
              child: Text(s.t('ratingBonusTitle'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
          Text('+${_dh(bonus)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.gold)),
        ]),
        const SizedBox(height: 6),
        Text(
          s
              .t('ratingBonusStatus')
              .replaceAll('{avg}', num(month.rating, 2))
              .replaceAll('{rides}', '${month.ratedRides}')
              .replaceAll('{per}', dh(per)),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          s.t('ratingBonusVolume').replaceAll('{rides}', '${month.rides}').replaceAll('{x}', x(factor)),
          key: const ValueKey('ratingBonusVolume'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        if (month.ridesByTaxi.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              [
                for (final e in month.ridesByTaxi.entries)
                  '🚕 ${s.t(e.key == DemoTaxi.grand ? 'grandTaxi' : 'petitTaxi')} n° ${e.key.number} : ${e.value}',
              ].join(' · '),
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ),
        if (nextVolume != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              s
                  .t('ratingBonusVolumeNext')
                  .replaceAll('{n}', '${nextVolume.$1 - month.rides}')
                  .replaceAll('{x}', x(nextVolume.$2)),
              style: const TextStyle(color: AppColors.moroccoGreen, fontWeight: FontWeight.w700),
            ),
          ),
        if (next != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              s.t('ratingBonusNext').replaceAll('{avg}', num(next.$1, 1)).replaceAll('{per}', dh(next.$2)),
              style: const TextStyle(color: AppColors.moroccoGreen, fontWeight: FontWeight.w700),
            ),
          ),
        const SizedBox(height: 6),
        Text(
          '${s.t('ratingBonusRule').replaceAll('{rides}', '${RatingBonus.minRides}')}'
          '${RatingBonus.tiers.map((t) => '\n★ ${num(t.$1, 1)} → ${dh(t.$2)}').join()}'
          '\n\n${s.t('ratingBonusVolumeRule')}'
          '${RatingBonus.volumeTiers.reversed.map((t) => '\n🚕 ${t.$1}+ → ${x(t.$2)}').join()}',
          style: const TextStyle(fontSize: 13, color: AppColors.muted),
        ),
      ]),
    );
  }

  Widget _beforeSetting() => _box(
        title: s.t('earnBeforeSetting'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.t('earnBeforeHelp'), style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          Row(children: [
            Expanded(
              child: Slider(
                value: driverEarnings.beforePerDay,
                min: DriverEarnings.minBefore,
                max: DriverEarnings.maxBefore,
                divisions: ((DriverEarnings.maxBefore - DriverEarnings.minBefore) / 10).round(),
                label: dh(driverEarnings.beforePerDay),
                onChanged: (v) => setState(() => driverEarnings.beforePerDay = v),
              ),
            ),
            Text(dh(driverEarnings.beforePerDay), style: const TextStyle(fontWeight: FontWeight.w900)),
          ]),
        ]),
      );

  Widget _box({String? title, required Widget child}) => Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line, width: 1.5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (title != null) ...[
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
          ],
          child,
        ]),
      );
}
