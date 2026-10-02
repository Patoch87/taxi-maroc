import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/strings.dart';
import '../main.dart';
import '../services/location.dart';
import '../services/places.dart';
import '../services/rides.dart';
import '../services/routing.dart';
import '../services/trip_share.dart';
import '../theme.dart';
import '../widgets/driver_card.dart';
import '../widgets/map_parts.dart';
import '../widgets/sheets.dart';
import 'driver_home.dart';
import 'history_screen.dart';
import 'search_screen.dart';

enum RiderStep { idle, choosing, dispatching, arriving, arrived, onTrip, done }

enum _Answer { waiting, declined, accepted, blocked }

/// Chauffeur sur la route du passager qui a reçu la demande.
class _Candidate {
  _Candidate(this.driver, this.start);
  final DemoDriver driver;
  final LatLng start;
  _Answer answer = _Answer.waiting;
}

/// Vitesse moyenne d'un taxi en ville : 25 km/h.
const _cityMps = 25000 / 3600;

/// Écran principal du passager : carte plein écran et panneau en bas, comme sur Uber.
class RiderHome extends StatefulWidget {
  const RiderHome({super.key, this.locate = true});

  /// Désactivé dans les tests (pas de GPS).
  final bool locate;

  @override
  State<RiderHome> createState() => _RiderHomeState();
}

class _RiderHomeState extends State<RiderHome> {
  final _map = MapController();
  final _rnd = Random();
  bool _mapReady = false;

  LatLng _me = casablancaCenter;
  late List<LatLng> _ambient = ambientTaxis(_me, _rnd);
  Timer? _ambientTimer;

  RiderStep _step = RiderStep.idle;
  Place? _dest;
  List<LatLng> _route = [];
  double _routeM = 0;
  List<RideOption> _options = [];
  RideOption? _selected;
  bool _cash = true;
  TimeOfDay? _scheduledAt;

  // Envoi de la demande : le premier chauffeur qui accepte bloque les autres.
  List<_Candidate> _candidates = [];
  final _dispatchTimers = <Timer>[];

  // Course
  DemoDriver? _driver;
  List<LatLng> _path = [];
  List<double> _cum = [];
  Duration _legDuration = Duration.zero;
  Duration _elapsed = Duration.zero;
  int _speed = 1;
  Timer? _moveTimer;
  int _rating = 0;
  double _tip = 0;

  @override
  void initState() {
    super.initState();
    if (widget.locate) _locate();
    _ambientTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted || _step.index >= RiderStep.arriving.index) return;
      setState(() {
        _ambient = _ambient
            .map((p) =>
                LatLng(p.latitude + (_rnd.nextDouble() - .5) * .0006, p.longitude + (_rnd.nextDouble() - .5) * .0006))
            .toList();
      });
    });
  }

  @override
  void dispose() {
    _ambientTimer?.cancel();
    _moveTimer?.cancel();
    for (final t in _dispatchTimers) {
      t.cancel();
    }
    super.dispose();
  }

  Future<void> _locate() async {
    final p = await currentLatLng();
    if (!mounted) return;
    setState(() {
      _me = p;
      _ambient = ambientTaxis(p, _rnd);
    });
    if (_mapReady) _map.move(p, 15);
  }

  void _fit(List<LatLng> pts) {
    if (!_mapReady || pts.length < 2) return;
    _map.fitCamera(CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(pts),
      padding: const EdgeInsets.fromLTRB(60, 130, 60, 480),
    ));
  }

  // ---------------------------------------------------------------- Destination

  Future<void> _openSearch({bool voice = false}) async {
    final place =
        await Navigator.push<Place>(context, MaterialPageRoute(builder: (_) => SearchScreen(startWithVoice: voice)));
    if (place != null) await _chooseDestination(place);
  }

  Future<void> _chooseDestination(Place place) async {
    final route = await fetchRoute(_me, LatLng(place.lat, place.lng));
    final routeM = routeLengthM(route);
    if (!mounted) return;
    final options = rideOptions(destination: place, routeM: routeM);
    setState(() {
      _dest = place;
      _route = route;
      _routeM = routeM;
      _options = options;
      _selected = options.first;
      _step = RiderStep.choosing;
    });
    _fit(route);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(DateTime.now().add(const Duration(minutes: 30))),
    );
    setState(() => _scheduledAt = t);
  }

  // ---------------------------------------------------------------- Commande

  void _request() {
    if (_scheduledAt != null) {
      final now = DateTime.now();
      tripHistory.insert(
        0,
        TripRecord(
          destination: _dest!.name,
          option: _selected!.title,
          price: _selected!.priceMad,
          date: DateTime(now.year, now.month, now.day, _scheduledAt!.hour, _scheduledAt!.minute),
          scheduled: true,
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${s.t('tripBooked')} ${_scheduledAt!.format(context)} · ${_dest!.name}'),
      ));
      _reset();
      return;
    }

    // La demande part aux taxis les plus proches qui passent sur la route du passager.
    const d = Distance();
    final nearest = [..._ambient]..sort((a, b) => d(a, _me).compareTo(d(b, _me)));
    final candidates = [
      for (final p in nearest.take(3 + _rnd.nextInt(2))) _Candidate(DemoDriver.random(_selected!.kind, _rnd), p),
    ];
    setState(() {
      _candidates = candidates;
      _step = RiderStep.dispatching;
    });

    // Un seul gagnant : le premier qui accepte. Les autres refusent avant lui ou sont bloqués.
    final winner = _rnd.nextInt(candidates.length);
    final winAt = 2500 + _rnd.nextInt(2500);
    for (var i = 0; i < candidates.length; i++) {
      if (i == winner) {
        _dispatchTimers.add(Timer(Duration(milliseconds: winAt), () => _onAccepted(candidates[i])));
      } else if (_rnd.nextBool()) {
        _dispatchTimers.add(Timer(Duration(milliseconds: 800 + _rnd.nextInt(winAt - 900)), () {
          if (mounted && candidates[i].answer == _Answer.waiting) {
            setState(() => candidates[i].answer = _Answer.declined);
          }
        }));
      }
    }
  }

  Future<void> _onAccepted(_Candidate c) async {
    if (!mounted || _step != RiderStep.dispatching) return;
    setState(() {
      c.answer = _Answer.accepted;
      for (final o in _candidates) {
        if (o != c && o.answer == _Answer.waiting) o.answer = _Answer.blocked;
      }
      _driver = c.driver;
    });
    final path = await fetchRoute(c.start, _me);
    await Future.delayed(const Duration(milliseconds: 1600));
    if (!mounted || _step != RiderStep.dispatching) return;
    final realSeconds = routeLengthM(path) / _cityMps;
    // Dans la démo, le taxi arrive en 30 à 75 secondes au plus pour ne pas attendre trop longtemps.
    _startLeg(path, Duration(seconds: realSeconds.clamp(30, 75).round()), RiderStep.arriving,
        onEnd: () => setState(() => _step = RiderStep.arrived));
    _fit([...path, _me]);
  }

  void _startLeg(List<LatLng> path, Duration duration, RiderStep step, {required VoidCallback onEnd}) {
    _moveTimer?.cancel();
    final cum = <double>[0];
    for (var i = 1; i < path.length; i++) {
      cum.add(cum.last + const Distance()(path[i - 1], path[i]));
    }
    setState(() {
      _path = path;
      _cum = cum;
      _legDuration = duration;
      _elapsed = Duration.zero;
      _speed = 1;
      _step = step;
    });
    const tick = Duration(milliseconds: 250);
    _moveTimer = Timer.periodic(tick, (t) {
      if (!mounted) return t.cancel();
      setState(() => _elapsed += tick * _speed);
      if (_elapsed >= _legDuration) {
        t.cancel();
        onEnd();
      }
    });
  }

  /// Position du taxi : interpolée le long du trajet selon le temps écoulé.
  LatLng? get _taxiPos {
    if (_path.length < 2 || _cum.isEmpty) return _path.isEmpty ? null : _path.first;
    final f = (_elapsed.inMilliseconds / max(1, _legDuration.inMilliseconds)).clamp(0.0, 1.0);
    final target = _cum.last * f;
    var i = 1;
    while (i < _cum.length - 1 && _cum[i] < target) {
      i++;
    }
    final segLen = _cum[i] - _cum[i - 1];
    final r = segLen == 0 ? 0.0 : (target - _cum[i - 1]) / segLen;
    final a = _path[i - 1], b = _path[i];
    return LatLng(a.latitude + (b.latitude - a.latitude) * r, a.longitude + (b.longitude - a.longitude) * r);
  }

  int get _taxiIndex {
    if (_cum.isEmpty) return 0;
    final f = (_elapsed.inMilliseconds / max(1, _legDuration.inMilliseconds)).clamp(0.0, 1.0);
    final target = _cum.last * f;
    var i = 0;
    while (i < _cum.length - 1 && _cum[i] < target) {
      i++;
    }
    return i;
  }

  Duration get _remaining {
    final r = _legDuration - _elapsed;
    return r.isNegative ? Duration.zero : r;
  }

  String get _countdown {
    final r = _remaining;
    return '${r.inMinutes.toString().padLeft(2, '0')}:${(r.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  DateTime get _arrivalTime => DateTime.now().add(_remaining ~/ _speed);

  String _clock(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  void _startTrip() {
    // Durée réelle du trajet à 25 km/h, décomptée en temps réel.
    _startLeg(_route, Duration(seconds: (_routeM / _cityMps).round()), RiderStep.onTrip,
        onEnd: () => setState(() => _step = RiderStep.done));
    _fit(_route);
  }

  Future<void> _share() => shareTrip(
        position: _taxiPos ?? _me,
        destination: _dest?.name ?? '',
        driver: _driver,
        arrival: _step == RiderStep.onTrip ? _arrivalTime : null,
      );

  void _finish() {
    tripHistory.insert(
      0,
      TripRecord(
        destination: _dest!.name,
        option: _selected!.title,
        price: _selected!.priceMad,
        date: DateTime.now(),
        driver: _driver,
        tip: _tip,
        rating: _rating,
      ),
    );
    _reset();
  }

  void _reset() {
    _moveTimer?.cancel();
    for (final t in _dispatchTimers) {
      t.cancel();
    }
    _dispatchTimers.clear();
    setState(() {
      _step = RiderStep.idle;
      _dest = null;
      _route = [];
      _path = [];
      _cum = [];
      _driver = null;
      _candidates = [];
      _rating = 0;
      _tip = 0;
      _scheduledAt = null;
    });
    if (_mapReady) _map.move(_me, 15);
  }

  // ---------------------------------------------------------------- Carte

  Widget _buildMap() {
    final showAmbient = _step.index < RiderStep.arriving.index;
    final taxi = _taxiPos;
    final routeToShow = switch (_step) {
      RiderStep.choosing || RiderStep.dispatching => _route,
      RiderStep.arriving => [if (taxi != null) taxi, ..._path.skip(_taxiIndex)],
      RiderStep.onTrip => [if (taxi != null) taxi, ..._path.skip(_taxiIndex)],
      _ => <LatLng>[],
    };
    return FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: _me,
        initialZoom: 15,
        onMapReady: () {
          _mapReady = true;
          _map.move(_me, 15);
        },
      ),
      children: [
        baseTiles(),
        if (routeToShow.length > 1) PolylineLayer(polylines: [routeLine(routeToShow)]),
        MarkerLayer(markers: [
          if (showAmbient)
            for (final p in _ambient) taxiMarker(p, TaxiKind.petit),
          if (_step == RiderStep.idle) meMarker(_me),
          if (_dest != null && _step != RiderStep.idle) ...[
            if (_step != RiderStep.onTrip) stopMarker(_me, destination: false),
            stopMarker(LatLng(_dest!.lat, _dest!.lng), destination: true),
          ],
          if (taxi != null && _step.index >= RiderStep.arriving.index && _step != RiderStep.done)
            taxiMarker(taxi, _selected!.kind),
        ]),
        mapAttribution(),
      ],
    );
  }

  // ---------------------------------------------------------------- Panneaux

  Widget _panel() => switch (_step) {
        RiderStep.idle => _idlePanel(),
        RiderStep.choosing => _choosePanel(),
        RiderStep.dispatching => _dispatchPanel(),
        RiderStep.arriving || RiderStep.arrived || RiderStep.onTrip => _tripPanel(),
        RiderStep.done => _donePanel(),
      };

  Widget _idlePanel() {
    final recent = {for (final t in tripHistory.where((t) => !t.scheduled)) t.destination}.take(3).toList();
    final suggestions = [
      for (final name in recent) casablancaPlaces.where((p) => p.name == name).firstOrNull,
      ...casablancaPlaces.take(4),
    ].whereType<Place>().toSet().take(4);
    return Column(
      key: const ValueKey('idle'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(s.t('hello'), style: const TextStyle(fontSize: 15, color: AppColors.muted, fontWeight: FontWeight.w600)),
        Text(s.t('whereTo'), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        // Barre de recherche avec le micro : la commande vocale est dans l'écran de commande.
        Material(
          color: const Color(0xFFF3F3F3),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _openSearch,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 6, 6, 6),
              child: Row(children: [
                const Icon(Icons.search, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(s.t('searchPlace'), style: const TextStyle(fontSize: 17, color: AppColors.muted)),
                ),
                IconButton.filled(
                  tooltip: s.t('speakNow'),
                  style: IconButton.styleFrom(backgroundColor: AppColors.ink, foregroundColor: Colors.white),
                  iconSize: 26,
                  onPressed: () => _openSearch(voice: true),
                  icon: const Icon(Icons.mic),
                ),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _savedPlace(Icons.home_rounded, s.t('home'), homePlace)),
          const SizedBox(width: 10),
          Expanded(child: _savedPlace(Icons.work_rounded, s.t('work'), workPlace)),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final p in suggestions)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ActionChip(
                    avatar: const Icon(Icons.history, size: 18),
                    label: Text(p.name),
                    shape: StadiumBorder(side: BorderSide(color: Colors.grey.shade300)),
                    backgroundColor: Colors.white,
                    onPressed: () => _chooseDestination(p),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _savedPlace(IconData icon, String label, Place p) => Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AppColors.line, width: 1.5)),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _chooseDestination(p),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFF3F3F3),
                  foregroundColor: AppColors.ink,
                  child: Icon(icon, size: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(p.subtitle,
                      style: const TextStyle(fontSize: 12, color: AppColors.muted), overflow: TextOverflow.ellipsis),
                ]),
              ),
            ]),
          ),
        ),
      );

  Widget _safetyButton() => IconButton.filledTonal(
        tooltip: s.t('safety'),
        style: IconButton.styleFrom(backgroundColor: const Color(0xFFE8F3EC), foregroundColor: AppColors.moroccoGreen),
        onPressed: () => showSafetySheet(context, taxiId: _driver?.taxiNumber, onShare: _share),
        icon: const Icon(Icons.shield_rounded),
      );

  Widget _choosePanel() => Column(
        key: const ValueKey('choose'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.t('chooseRide'), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                Row(children: [
                  const Icon(Icons.flag_rounded, size: 16, color: AppColors.muted),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                        '${_dest!.name} · ${distanceText(_routeM)} · ${(_routeM / _cityMps / 60).ceil()} ${s.t('minutes')}',
                        style: const TextStyle(color: AppColors.muted),
                        overflow: TextOverflow.ellipsis),
                  ),
                ]),
              ]),
            ),
            _safetyButton(),
          ]),
          const SizedBox(height: 10),
          for (final o in _options) _optionTile(o),
          Row(children: [
            const Icon(Icons.verified_user_outlined, size: 16, color: AppColors.moroccoGreen),
            const SizedBox(width: 6),
            Expanded(
              child: Text(s.t('officialPrice'), style: const TextStyle(fontSize: 12, color: AppColors.moroccoGreen)),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _pill(
              icon: _cash ? Icons.payments_outlined : Icons.credit_card,
              label: _cash ? s.t('cash') : s.t('card'),
              onTap: () => setState(() => _cash = !_cash),
            ),
            const SizedBox(width: 8),
            _pill(
              icon: Icons.schedule,
              label: _scheduledAt == null ? s.t('now') : '${s.t('scheduledFor')} ${_scheduledAt!.format(context)}',
              onTap: _scheduledAt == null ? _pickTime : () => setState(() => _scheduledAt = null),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            SizedBox(
              width: 56,
              height: 56,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(56, 56)),
                onPressed: _reset,
                child: const Icon(Icons.close),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: _request,
                child: Text('${s.t('confirm')} · ${dh(_selected!.priceMad)}', overflow: TextOverflow.ellipsis),
              ),
            ),
          ]),
        ],
      );

  Widget _pill({required IconData icon, required String label, required VoidCallback onTap}) => Material(
        color: const Color(0xFFF3F3F3),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 18),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
              const Icon(Icons.expand_more, size: 18),
            ]),
          ),
        ),
      );

  Widget _optionTile(RideOption o) {
    final selected = o.id == _selected?.id;
    return GestureDetector(
      onTap: () => setState(() => _selected = o),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFAFAFA) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? AppColors.ink : AppColors.line, width: selected ? 2 : 1.5),
        ),
        child: Row(children: [
          Container(
            width: 54,
            height: 42,
            decoration: BoxDecoration(color: taxiColor(o.kind), borderRadius: BorderRadius.circular(11)),
            child: Icon(Icons.local_taxi, color: o.kind == TaxiKind.grand ? AppColors.ink : Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(o.title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.person, size: 14, color: AppColors.muted),
                Text('${o.seats}', style: const TextStyle(fontSize: 13, color: AppColors.muted)),
              ]),
              Text(o.description, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
            ]),
          ),
          Text(dh(o.priceMad), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
        ]),
      ),
    );
  }

  Widget _dispatchPanel() {
    final accepted = _candidates.where((c) => c.answer == _Answer.accepted).firstOrNull;
    return Column(
      key: const ValueKey('dispatch'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(accepted == null ? s.t('searching') : '${accepted.driver.name} ${s.t('acceptedFirst')} ✅',
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text('${s.t('sentTo')} ${_candidates.length} ${s.t('drivers')}',
            style: const TextStyle(color: AppColors.muted)),
        const SizedBox(height: 12),
        if (accepted == null)
          const LinearProgressIndicator(minHeight: 4, color: AppColors.ink, backgroundColor: AppColors.line),
        const SizedBox(height: 8),
        for (final c in _candidates)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              Opacity(
                opacity: c.answer == _Answer.declined || c.answer == _Answer.blocked ? .4 : 1,
                child: SizedBox(
                    width: 44,
                    height: 44,
                    child: ClipOval(
                        child: Image.network(c.driver.photoUrl,
                            errorBuilder: (_, __, ___) => CircleAvatar(child: Text(c.driver.name[0]))))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('${c.driver.name}  ${c.driver.languages.map((l) => l.flag).join(' ')}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              _answerChip(c.answer),
            ]),
          ),
        const SizedBox(height: 6),
        Row(children: [
          const Icon(Icons.lock_clock, size: 16, color: AppColors.muted),
          const SizedBox(width: 6),
          Expanded(child: Text(s.t('firstWins'), style: const TextStyle(fontSize: 12, color: AppColors.muted))),
        ]),
        const SizedBox(height: 10),
        OutlinedButton(onPressed: _reset, child: Text(s.t('cancel'))),
      ],
    );
  }

  Widget _answerChip(_Answer a) {
    final (label, color) = switch (a) {
      _Answer.waiting => ('…', AppColors.muted),
      _Answer.declined => (s.t('declined'), AppColors.muted),
      _Answer.accepted => ('✓ ${s.t('accept')}', AppColors.moroccoGreen),
      _Answer.blocked => ('🔒 ${s.t('blocked')}', AppColors.taxiRed),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: .1), borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
    );
  }

  Widget _tripPanel() {
    final d = _driver!;
    final title = switch (_step) {
      RiderStep.arriving => s.t('arrivingIn'),
      RiderStep.arrived => s.t('arrived'),
      _ => '${s.t('onTrip')} ${_dest!.name}',
    };
    return Column(
      key: const ValueKey('trip'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              if (_step != RiderStep.arrived)
                Text('${s.t('arrivalAt')} ${_clock(_arrivalTime)}', style: const TextStyle(color: AppColors.muted)),
            ]),
          ),
          // Compte à rebours en temps réel
          if (_step != RiderStep.arrived)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(14)),
              child: Text(_countdown,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      fontFeatures: [FontFeature.tabularFigures()])),
            ),
          const SizedBox(width: 8),
          _safetyButton(),
        ]),
        const SizedBox(height: 14),
        DriverCard(driver: d),
        const SizedBox(height: 14),
        Row(children: [
          _action(Icons.call, s.t('call'), () => launchUrl(Uri(scheme: 'tel', path: '0600000000'))),
          _action(Icons.chat_bubble_outline, s.t('message'), () => showChatSheet(context, driverName: d.name)),
          _action(Icons.ios_share, s.t('share'), _share),
          _action(Icons.flag_outlined, s.t('complain'),
              () => showSafetySheet(context, taxiId: d.taxiNumber, onShare: _share),
              color: AppColors.taxiRed),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFF7F7F7), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Icon(_cash ? Icons.payments_outlined : Icons.credit_card, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(_selected!.title, style: const TextStyle(fontWeight: FontWeight.w600))),
            Text(dh(_selected!.priceMad), style: const TextStyle(fontWeight: FontWeight.w900)),
          ]),
        ),
        if (_step == RiderStep.arrived) ...[
          const SizedBox(height: 10),
          FilledButton(onPressed: _startTrip, child: Text(s.t('startTrip'))),
        ],
        if (_step != RiderStep.arrived)
          Row(children: [
            if (_step == RiderStep.arriving)
              TextButton(onPressed: _reset, child: Text(s.t('cancel'), style: const TextStyle(color: AppColors.muted))),
            const Spacer(),
            TextButton.icon(
              onPressed: () => setState(() => _speed = _speed == 1 ? 10 : 1),
              icon: Icon(_speed == 1 ? Icons.fast_forward : Icons.play_arrow, size: 18, color: AppColors.muted),
              label: Text(s.t('fastForward'), style: const TextStyle(color: AppColors.muted)),
            ),
          ]),
      ],
    );
  }

  Widget _action(IconData icon, String label, VoidCallback onTap, {Color color = AppColors.ink}) => Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(children: [
              CircleAvatar(
                  radius: 22, backgroundColor: const Color(0xFFF3F3F3), foregroundColor: color, child: Icon(icon)),
              const SizedBox(height: 4),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
            ]),
          ),
        ),
      );

  Widget _donePanel() => Column(
        key: const ValueKey('done'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.t('tripDone'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFF7F7F7), borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              DriverPhoto(driver: _driver!, size: 54),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.t('pay'), style: const TextStyle(color: AppColors.muted)),
                  Text(dh(_selected!.priceMad + _tip),
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
                  Text('${_driver!.name} · ${_driver!.taxiNumber}', style: const TextStyle(color: AppColors.muted)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          Text(s.t('tip'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Row(children: [
            for (final t in [0.0, 5.0, 10.0, 20.0])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: ChoiceChip(
                    label: SizedBox(
                        width: double.infinity, child: Text(t == 0 ? '—' : dh(t), textAlign: TextAlign.center)),
                    selected: _tip == t,
                    showCheckmark: false,
                    selectedColor: AppColors.ink,
                    labelStyle: TextStyle(color: _tip == t ? Colors.white : AppColors.ink, fontWeight: FontWeight.w700),
                    onSelected: (_) => setState(() => _tip = t),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 10),
          Text(s.t('rate'), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  iconSize: 38,
                  onPressed: () => setState(() => _rating = i),
                  icon: Icon(i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: const Color(0xFFF5B301)),
                ),
            ],
          ),
          FilledButton(onPressed: _finish, child: Text(s.t('done'))),
          TextButton(
            onPressed: () => showSafetySheet(context, taxiId: _driver?.taxiNumber, onShare: _share),
            child: Text(s.t('complain'), style: const TextStyle(color: AppColors.muted)),
          ),
        ],
      );

  // ---------------------------------------------------------------- Menu

  Widget _drawer() => Drawer(
        backgroundColor: Colors.white,
        child: SafeArea(
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(color: AppColors.taxiRed, borderRadius: BorderRadius.circular(13)),
                    child: const Icon(Icons.local_taxi, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Text(s.t('appTitle'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                ]),
              ),
              const Divider(color: AppColors.line),
              _menuItem(Icons.receipt_long, s.t('history'), () => const HistoryScreen()),
              _menuItem(Icons.drive_eta_outlined, s.t('driverMode'), () => const DriverHome()),
              ListTile(
                leading: const Icon(Icons.shield_outlined),
                title: Text(s.t('safety')),
                onTap: () {
                  Navigator.pop(context);
                  showSafetySheet(context, taxiId: _driver?.taxiNumber, onShare: _share);
                },
              ),
              const Divider(color: AppColors.line),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Text(s.t('language'), style: const TextStyle(color: AppColors.muted)),
              ),
              for (final code in S.supported)
                ListTile(
                  title: Text(S.names[code]!),
                  trailing: langNotifier.value == code ? const Icon(Icons.check) : null,
                  onTap: () {
                    Navigator.pop(context);
                    langNotifier.value = code;
                  },
                ),
            ],
          ),
        ),
      );

  Widget _menuItem(IconData icon, String label, Widget Function() page) => ListTile(
        leading: Icon(icon),
        title: Text(label),
        onTap: () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => page())).then((_) => setState(() {}));
        },
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _drawer(),
      body: Stack(
        children: [
          Positioned.fill(child: _buildMap()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Builder(
                    builder: (ctx) => MapCircleButton(icon: Icons.menu, onTap: () => Scaffold.of(ctx).openDrawer())),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: Text(s.t('demoBanner'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                const Spacer(),
                MapCircleButton(icon: Icons.my_location, onTap: _locate),
              ]),
            ),
          ),
          Align(alignment: Alignment.bottomCenter, child: BottomPanel(child: _panel())),
        ],
      ),
    );
  }
}
