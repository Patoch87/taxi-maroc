import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart';
import '../services/live.dart';
import '../theme.dart';

/// Entraide entre chauffeurs Bab Taxi : en panne ou après un accident, le chauffeur appelle les taxis
/// proches. Ils peuvent venir l'aider et l'un d'eux peut reprendre ses passagers, au même prix.
/// Même style que le rappel des feux de détresse : bandeau sombre, pastille orange.

const helpOrange = Color(0xFFFFB300);

/// Voix arabe pour le chauffeur qui reçoit l'appel (même règle que les demandes : taxi vide seulement).
const helpAnnouncementAr = 'زميل من باب طاكسي يحتاج إلى مساعدة قريباً منك';

String helpDistance(double? m) {
  if (m == null) return '';
  return m < 1000 ? '${(m / 10).round() * 10} m' : '${(m / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
}

Future<void> _call(String number) => launchUrl(Uri(scheme: 'tel', path: number)).then((_) {}, onError: (_) {});

/// « Que se passe-t-il ? » : panne ou accident, blessés, numéros des secours, puis l'appel aux collègues.
/// [riders] : places de passagers de l'application dans le taxi (ou attendus).
Future<({bool accident, bool injured})?> showRoadsideHelpSheet(BuildContext context, {required int riders}) =>
    showModalBottomSheet<({bool accident, bool injured})>(
      context: context,
      backgroundColor: AppColors.sand,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _HelpSheet(riders: riders),
    );

class _HelpSheet extends StatefulWidget {
  const _HelpSheet({required this.riders});
  final int riders;

  @override
  State<_HelpSheet> createState() => _HelpSheetState();
}

class _HelpSheetState extends State<_HelpSheet> {
  bool? _accident;
  bool _injured = false;

  Widget _choice({required bool accident, required IconData icon}) {
    final selected = _accident == accident;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          key: ValueKey(accident ? 'helpAccident' : 'helpBreakdown'),
          borderRadius: BorderRadius.circular(18),
          onTap: () => setState(() => _accident = accident),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
            decoration: BoxDecoration(
              color: selected ? AppColors.ink : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: selected ? AppColors.ink : AppColors.line, width: 2),
            ),
            child: Column(children: [
              Icon(icon, size: 40, color: selected ? helpOrange : AppColors.ink),
              const SizedBox(height: 8),
              Text(s.t(accident ? 'helpAccident' : 'helpBreakdown'),
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900, color: selected ? Colors.white : AppColors.ink)),
              Text(s.t(accident ? 'helpAccidentDesc' : 'helpBreakdownDesc'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: selected ? Colors.white70 : AppColors.muted)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _emergency(String key, String number, IconData icon) => Expanded(
        child: OutlinedButton(
          key: ValueKey('call-$number'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.taxiRed,
            side: const BorderSide(color: AppColors.taxiRed, width: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            minimumSize: const Size(0, 56),
          ),
          onPressed: () => _call(number),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 22),
            const SizedBox(height: 2),
            FittedBox(child: Text(s.t(key), style: const TextStyle(fontWeight: FontWeight.w800))),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final accident = _accident;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(s.t('helpTitle'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          Text(s.t('helpButtonDesc'), style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 14),
          Row(children: [
            _choice(accident: false, icon: Icons.car_repair),
            const SizedBox(width: 12),
            _choice(accident: true, icon: Icons.car_crash),
          ]),
          if (accident == true) ...[
            const SizedBox(height: 10),
            SwitchListTile(
              key: const ValueKey('helpInjured'),
              contentPadding: EdgeInsets.zero,
              title: Text(s.t('helpInjured'), style: const TextStyle(fontWeight: FontWeight.w800)),
              value: _injured,
              activeThumbColor: AppColors.taxiRed,
              onChanged: (v) => setState(() => _injured = v),
            ),
            if (_injured)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(s.t('helpInjuredHint'),
                    style: const TextStyle(color: AppColors.taxiRed, fontWeight: FontWeight.w700)),
              ),
            // Les numéros des secours, toujours visibles en cas d'accident.
            Row(children: [
              _emergency('helpAmbulance', '15', Icons.local_hospital_outlined),
              const SizedBox(width: 8),
              _emergency('helpPolice', '19', Icons.local_police_outlined),
              const SizedBox(width: 8),
              _emergency('helpGendarmerie', '177', Icons.shield_outlined),
            ]),
          ],
          if (widget.riders > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.greenSoft, borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                const Icon(Icons.people_alt_outlined, color: AppColors.moroccoGreen),
                const SizedBox(width: 10),
                Expanded(child: Text('${widget.riders} ${s.t('helpRidersHint')}')),
              ]),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const ValueKey('helpSend'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.ink,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 56),
            ),
            onPressed: accident == null ? null : () => Navigator.pop(context, (accident: accident, injured: _injured)),
            icon: const Icon(Icons.campaign_rounded, color: helpOrange, size: 26),
            label: Text(s.t('helpSend'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ),
        ]),
      ),
    );
  }
}

/// Pastille orange qui clignote (comme les feux de détresse).
class HelpBlink extends StatefulWidget {
  const HelpBlink({super.key, this.icon = Icons.car_repair});
  final IconData icon;

  @override
  State<HelpBlink> createState() => _HelpBlinkState();
}

class _HelpBlinkState extends State<HelpBlink> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween(begin: .45, end: 1.0).animate(_c),
        child: Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(color: helpOrange, shape: BoxShape.circle),
          child: Icon(widget.icon, size: 24, color: AppColors.ink),
        ),
      );
}

BoxDecoration get _dark => BoxDecoration(
      color: AppColors.ink,
      borderRadius: BorderRadius.circular(18),
      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
    );

/// Chauffeur qui a appelé : qui est prévenu, qui arrive, qui reprend les passagers, « Problème réglé ».
class HelpCallCard extends StatelessWidget {
  const HelpCallCard({super.key, required this.alert, required this.onSolved});
  final HelpAlert alert;
  final VoidCallback onSolved;

  @override
  Widget build(BuildContext context) {
    final taker = alert.replies.where((r) => r.takesRiders).firstOrNull;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        key: const ValueKey('helpCallCard'),
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        padding: const EdgeInsets.all(14),
        decoration: _dark,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            HelpBlink(icon: alert.accident ? Icons.car_crash : Icons.car_repair),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${s.t('helpSent')} · ${s.t(alert.accident ? 'helpAccident' : 'helpBreakdown')}',
                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
                Text(alert.notified > 0 ? '${alert.notified} ${s.t('helpNotified')}' : s.t('helpNobody'),
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          if (alert.replies.isEmpty)
            Text(s.t('helpWaiting'), style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic))
          else
            for (final r in alert.replies)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Icon(r.takesRiders ? Icons.people_alt : Icons.local_taxi,
                      color: r.takesRiders ? const Color(0xFF7BD389) : helpOrange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        '${r.name}${r.plate.isEmpty ? '' : ' (${r.plate})'} ${s.t(r.takesRiders ? 'helpTakesRiders' : 'helpComing')}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
          if (taker == null && alert.riders > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('${alert.riders} ${s.t('helpRidersHint')}',
                  style: const TextStyle(color: Colors.white60, fontSize: 12.5)),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(s.t('helpNoRequests'), style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            key: const ValueKey('helpSolved'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.moroccoGreen, minimumSize: const Size(0, 50)),
            onPressed: onSolved,
            icon: const Icon(Icons.check_circle_outline),
            label: Text(s.t('helpSolved'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
        ]),
      ),
    );
  }
}

/// Chauffeur qui reçoit l'appel d'un collègue proche : « J'arrive », « Je prends les passagers », « Pas possible ».
class HelpAlertCard extends StatelessWidget {
  const HelpAlertCard({
    super.key,
    required this.alert,
    required this.canTakeRiders,
    required this.onGo,
    required this.onTake,
    required this.onDismiss,
  });
  final HelpAlert alert;

  /// Assez de places libres pour reprendre ses passagers (et personne ne les reprend déjà).
  final bool canTakeRiders;
  final VoidCallback onGo;
  final VoidCallback onTake;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final details = [
      s.t(alert.accident ? 'helpAccident' : 'helpBreakdown'),
      if (alert.injured) s.t('helpInjured'),
      if (alert.distanceM != null) helpDistance(alert.distanceM),
    ].join(' · ');
    final takenByOther = alert.takenBy != null;
    return Semantics(
      liveRegion: true,
      container: true,
      label: s.t('helpIncoming'),
      child: Container(
        key: const ValueKey('helpAlertCard'),
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        padding: const EdgeInsets.all(14),
        decoration: _dark,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            HelpBlink(icon: alert.accident ? Icons.car_crash : Icons.car_repair),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.t('helpIncoming'),
                    style: const TextStyle(color: helpOrange, fontSize: 13, fontWeight: FontWeight.w800)),
                Text('${alert.name}${alert.plate.isEmpty ? '' : ' · ${alert.plate}'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                Text(details, style: TextStyle(color: alert.injured ? const Color(0xFFFF8A80) : Colors.white70)),
              ]),
            ),
          ]),
          if (alert.riders > 0 && !takenByOther) ...[
            const SizedBox(height: 8),
            Text(
                '${alert.riders} ${s.t('helpRidersToTake')}'
                '${alert.destinations.isEmpty ? '' : ' → ${alert.destinations.join(', ')}'}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ],
          if (takenByOther && alert.riders > 0) ...[
            const SizedBox(height: 8),
            Text(s.t('helpTakenByOther'), style: const TextStyle(color: Colors.white60, fontSize: 12.5)),
          ],
          const SizedBox(height: 12),
          if (alert.riders > 0 && canTakeRiders && !takenByOther) ...[
            FilledButton.icon(
              key: const ValueKey('helpTake'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.moroccoGreen, minimumSize: const Size(0, 52)),
              onPressed: onTake,
              icon: const Icon(Icons.people_alt),
              label: Text(s.t('helpTake'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 8),
          ],
          Row(children: [
            Expanded(
              child: OutlinedButton(
                key: const ValueKey('helpDismiss'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    minimumSize: const Size(0, 50)),
                onPressed: onDismiss,
                child: Text(s.t('helpNotPossible')),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                key: const ValueKey('helpGo'),
                style: FilledButton.styleFrom(
                    backgroundColor: helpOrange, foregroundColor: AppColors.ink, minimumSize: const Size(0, 50)),
                onPressed: onGo,
                icon: const Icon(Icons.local_taxi),
                label: Text(s.t('helpGo'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

/// Le chauffeur a répondu « J'arrive » : bandeau compact en haut de l'écran.
class HelpGoingBanner extends StatelessWidget {
  const HelpGoingBanner(
      {super.key, required this.alert, this.distanceM, required this.onRoute, required this.onCancel});
  final HelpAlert alert;
  final double? distanceM;
  final VoidCallback onRoute;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => Container(
        key: const ValueKey('helpGoingBanner'),
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsetsDirectional.fromSTEB(10, 8, 6, 8),
        decoration: _dark,
        child: Row(children: [
          HelpBlink(icon: alert.accident ? Icons.car_crash : Icons.car_repair),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('${s.t('helpGoingTo')} ${alert.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
              Text(
                  [
                    s.t(alert.accident ? 'helpAccident' : 'helpBreakdown'),
                    if (distanceM != null) helpDistance(distanceM)
                  ].join(' · '),
                  style: const TextStyle(fontSize: 12.5, color: Colors.white70)),
            ]),
          ),
          TextButton(
            key: const ValueKey('helpRoute'),
            style: TextButton.styleFrom(foregroundColor: helpOrange, minimumSize: const Size(48, 40)),
            onPressed: onRoute,
            child: Text(s.t('helpRoute'), style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          IconButton(
            key: const ValueKey('helpCancelGoing'),
            tooltip: s.t('helpCantCome'),
            color: Colors.white54,
            onPressed: onCancel,
            icon: const Icon(Icons.close),
          ),
        ]),
      );
}
