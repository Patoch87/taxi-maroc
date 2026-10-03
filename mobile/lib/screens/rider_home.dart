import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/strings.dart';
import '../main.dart';
import '../services/location.dart';
import '../services/places.dart';
import '../services/rides.dart';
import '../services/routing.dart';
import '../services/schedule.dart';
import '../services/settings.dart';
import '../services/trip_share.dart';
import '../services/voice.dart';
import '../theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/driver_card.dart';
import '../widgets/map_parts.dart';
import '../widgets/senior.dart';
import '../widgets/sheets.dart';
import 'driver_home.dart';
import 'history_screen.dart';
import 'search_screen.dart';
import 'trusted_contacts_screen.dart';

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

  /// Réservation à l'avance : date et heure de prise en charge (null = maintenant).
  DateTime? _scheduledAt;

  /// Course commandée pour quelqu'un d'autre (null = pour moi).
  TrustedContact? _forOther;

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

  // Annonces vocales pour les passagers malvoyants.
  Voice? _voiceEngine;
  Voice get _voice => _voiceEngine ??= Voice();
  int _lastAnnouncedMin = -1;

  @override
  void initState() {
    super.initState();
    settings.addListener(_onSettings);
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

  void _onSettings() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    settings.removeListener(_onSettings);
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
    final place = await Navigator.push<Place>(
        context, MaterialPageRoute(builder: (_) => SearchScreen(startWithVoice: voice, senior: settings.senior)));
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

  /// Réserver pour plus tard : une date (aujourd'hui jusqu'à 30 jours), puis une heure (15 minutes au moins).
  Future<void> _pickSchedule() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(minScheduleDelay),
      firstDate: today,
      lastDate: today.add(const Duration(days: maxScheduleDays)),
      helpText: s.t('later'),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(minutes: 30))),
      helpText: s.t('pickupAt'),
    );
    if (time == null || !mounted) return;
    final wanted = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    final at = clampSchedule(wanted);
    if (at != wanted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('tooSoon'))));
    }
    _setSchedule(at);
  }

  /// Les prix dépendent de l'heure (tarif de nuit) : les options sont recalculées.
  void _setSchedule(DateTime? at) {
    if (_dest == null) return;
    final options = rideOptions(destination: _dest!, routeM: _routeM, date: at);
    setState(() {
      _scheduledAt = at;
      _options = options;
      _selected = options.firstWhere((o) => o.id == _selected?.id, orElse: () => options.first);
    });
  }

  Future<void> _pickPassenger() async {
    final r = await showPassengerSheet(context, current: _forOther);
    if (r != null && mounted) setState(() => _forOther = r.other);
  }

  /// Envoie les informations de la course à la personne pour qui le taxi a été commandé.
  Future<void> _sharePassenger() async {
    final p = _forOther;
    if (p == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${s.t('passengerInformed')} ${p.name}')));
    await shareTrip(
      position: _me,
      destination: _dest?.name ?? '',
      driver: _driver,
      arrival: _driver != null && _step == RiderStep.arriving ? _arrivalTime : null,
      pickupAt: _scheduledAt,
      forName: p.name,
    );
  }

  // ---------------------------------------------------------------- Annonces vocales

  /// Annonces minute par minute : pour les malvoyants, le mode senior ou un lecteur d'écran actif.
  bool get _announceMinutes =>
      settings.voiceAnnounce &&
      (settings.lowVision || settings.senior || MediaQuery.maybeOf(context)?.accessibleNavigation == true);

  void _say(String text) {
    if (settings.voiceAnnounce) _voice.say(text);
  }

  String _minutesText(int m) => m <= 1 ? s.t('minuteOne') : '$m ${s.t('minutesLong')}';

  void _announceDriver(DemoDriver d) {
    final mins = (_remaining.inSeconds / 60).ceil();
    _lastAnnouncedMin = mins;
    final plate = d.plate.replaceAll('|', ' ');
    _say('${s.t('taxiFound')}. ${d.car} ${s.t(carColorKey(_selected!.kind))}, ${s.t('plate')} $plate. '
        '${s.t('driverInfo')} : ${d.name}. ${s.t('arrivingIn')} ${_minutesText(mins)}.');
  }

  void _announceMinute() {
    if (_step != RiderStep.arriving || !_announceMinutes) return;
    final mins = (_remaining.inSeconds / 60).ceil();
    if (mins >= 1 && mins < _lastAnnouncedMin) {
      _lastAnnouncedMin = mins;
      _say('${s.t('arrivingIn')} ${_minutesText(mins)}');
    }
  }

  /// Taxi arrivé : vibration forte répétée et annonce vocale.
  Future<void> _announceArrival() async {
    _say('${s.t('arrived')}. ${s.t('plate')} ${_driver?.plate.replaceAll('|', ' ') ?? ''}');
    for (var i = 0; i < 3; i++) {
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 350));
    }
  }

  // ---------------------------------------------------------------- Commande

  void _request() {
    if (_scheduledAt != null) {
      tripHistory.insert(
        0,
        TripRecord(
          destination: _dest!.name,
          option: _selected!.title,
          price: _selected!.priceMad,
          date: _scheduledAt!,
          scheduled: true,
          passengerName: _forOther?.name,
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${s.t('tripBooked')} ${scheduleLabel(_scheduledAt!, lang: s.lang)} · ${_dest!.name}'
            '${_forOther == null ? '' : ' · ${_forOther!.name}'}'),
      ));
      if (_forOther != null) _sharePassenger();
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
    _startLeg(path, Duration(seconds: realSeconds.clamp(30, 75).round()), RiderStep.arriving, onEnd: () {
      setState(() => _step = RiderStep.arrived);
      _announceArrival();
    });
    _fit([...path, _me]);
    _announceDriver(c.driver);
    // Course pour quelqu'un d'autre : il reçoit le chauffeur, la plaque et l'heure d'arrivée.
    if (_forOther != null) _sharePassenger();
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
      _announceMinute();
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
    _autoShare();
  }

  /// Partage automatique avec les contacts de confiance (toujours, ou la nuit de 21 h à 6 h).
  void _autoShare() {
    if (!settings.shouldAutoShare(DateTime.now())) return;
    final n = settings.contacts.length;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.moroccoGreen,
      content: Row(children: [
        const Icon(Icons.share_location, color: Colors.white),
        const SizedBox(width: 10),
        Expanded(
          child: Text('${s.t('sharedWith')} $n ${s.t('contactsShort')}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ]),
    ));
    _share();
  }

  // ---------------------------------------------------------------- Mode senior

  Future<void> _seniorGoHome() async {
    await _chooseDestination(homePlace);
    if (!mounted || _step != RiderStep.choosing) return;
    setState(() => _selected = _options.first); // petit taxi partagé
    _request();
  }

  Future<void> _callContact() async {
    final contacts = settings.contacts;
    if (contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('seniorNoContact'))));
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const TrustedContactsScreen()));
      return;
    }
    try {
      await launchUrl(Uri(scheme: 'tel', path: contacts.first.phone));
    } catch (_) {}
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
        passengerName: _forOther?.name,
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
      _forOther = null;
      _lastAnnouncedMin = -1;
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
          color: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.line, width: 1.5)),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _openSearch,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 6, 6, 6),
              child: Row(children: [
                const Icon(Icons.search, size: 26, color: AppColors.moroccoGreen),
                const SizedBox(width: 12),
                Expanded(
                  child: Semantics(
                    button: true,
                    label: s.t('searchPlace'),
                    excludeSemantics: true,
                    child: Text(s.t('searchPlace'), style: const TextStyle(fontSize: 17, color: AppColors.muted)),
                  ),
                ),
                IconButton.filled(
                  tooltip: s.t('speakNow'),
                  style: IconButton.styleFrom(backgroundColor: AppColors.moroccoGreen, foregroundColor: Colors.white),
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
                    shape: const StadiumBorder(side: BorderSide(color: AppColors.line)),
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

  Widget _savedPlace(IconData icon, String label, Place p) => Semantics(
      button: true,
      label: '$label, ${p.subtitle}',
      excludeSemantics: true,
      child: Material(
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
                  backgroundColor: AppColors.greenSoft,
                  foregroundColor: AppColors.moroccoGreen,
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
      ));

  Widget _safetyButton() => IconButton.filledTonal(
        tooltip: s.t('safety'),
        style: IconButton.styleFrom(backgroundColor: AppColors.greenSoft, foregroundColor: AppColors.moroccoGreen),
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
          Wrap(spacing: 8, runSpacing: 8, children: [
            _pill(
              icon: _cash ? Icons.payments_outlined : Icons.credit_card,
              label: _cash ? s.t('cash') : s.t('card'),
              semantics: '${s.t('payment')} : ${_cash ? s.t('cash') : s.t('card')}',
              onTap: () => setState(() => _cash = !_cash),
            ),
            _pill(
              icon: _scheduledAt == null ? Icons.schedule : Icons.event_available,
              label: _scheduledAt == null ? s.t('now') : scheduleLabel(_scheduledAt!, lang: s.lang),
              semantics: _scheduledAt == null
                  ? '${s.t('now')}, ${s.t('later')}'
                  : '${s.t('scheduledFor')} ${scheduleLabel(_scheduledAt!, lang: s.lang)}',
              selected: _scheduledAt != null,
              onTap: _scheduledAt == null ? _pickSchedule : () => _setSchedule(null),
            ),
            _pill(
              icon: _forOther == null ? Icons.person : Icons.group,
              label: _forOther == null ? s.t('forMe') : _forOther!.name,
              semantics: '${s.t('whoRides')} ${_forOther == null ? s.t('forMe') : _forOther!.name}',
              selected: _forOther != null,
              onTap: _pickPassenger,
            ),
            _pill(
              icon: Icons.visibility_off_outlined,
              label: s.t('lowVisionShort'),
              semantics: s.t('lowVisionDesc'),
              selected: settings.lowVision,
              toggle: true,
              onTap: () => settings.lowVision = !settings.lowVision,
            ),
          ]),
          if (settings.lowVision) ...[
            const SizedBox(height: 8),
            _infoNote(Icons.record_voice_over, s.t('lowVisionDesc')),
          ],
          if (_forOther != null) ...[
            const SizedBox(height: 8),
            _infoNote(Icons.sms_outlined, '${s.t('passenger')} : ${_forOther!.name} · ${_forOther!.phone}'),
          ],
          const SizedBox(height: 10),
          Row(children: [
            SizedBox(
              width: 56,
              height: 56,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(56, 56)),
                onPressed: _reset,
                child: Icon(Icons.close, semanticLabel: s.t('cancel')),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Semantics(
                button: true,
                label: '${s.t('confirm')} ${_selected!.title}, ${dh(_selected!.priceMad)}'
                    '${_scheduledAt == null ? '' : ', ${scheduleLabel(_scheduledAt!, lang: s.lang)}'}',
                excludeSemantics: true,
                child: FilledButton(
                  onPressed: _request,
                  child: Text('${s.t('confirm')} · ${dh(_selected!.priceMad)}', overflow: TextOverflow.ellipsis),
                ),
              ),
            ),
          ]),
        ],
      );

  Widget _pill({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    String? semantics,
    bool selected = false,
    bool toggle = false,
  }) {
    final fg = selected ? Colors.white : AppColors.ink;
    return Semantics(
      button: true,
      toggled: toggle ? selected : null,
      label: semantics ?? label,
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.moroccoGreen : Colors.white,
        shape: StadiumBorder(side: BorderSide(color: selected ? AppColors.moroccoGreen : AppColors.line, width: 1.5)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: fg)),
              if (!toggle) Icon(selected ? Icons.close : Icons.expand_more, size: 18, color: fg),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _infoNote(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: AppColors.greenSoft, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(icon, size: 18, color: AppColors.moroccoGreen),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 13, color: AppColors.moroccoGreen, fontWeight: FontWeight.w600)),
          ),
        ]),
      );

  Widget _optionTile(RideOption o) {
    final selected = o.id == _selected?.id;
    return Semantics(
        button: true,
        selected: selected,
        label: '${o.title}, ${dh(o.priceMad)}, ${o.description}',
        excludeSemantics: true,
        child: GestureDetector(
          onTap: () => setState(() => _selected = o),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFF4FAF6) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: selected ? AppColors.moroccoGreen : AppColors.line, width: selected ? 2 : 1.5),
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
        ));
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
          const LinearProgressIndicator(minHeight: 4, color: AppColors.moroccoGreen, backgroundColor: AppColors.line),
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
            Semantics(
              liveRegion: true,
              label: '$title ${_minutesText((_remaining.inSeconds / 60).ceil())}',
              excludeSemantics: true,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: AppColors.moroccoGreen, borderRadius: BorderRadius.circular(14)),
                child: Text(_countdown,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        fontFeatures: [FontFeature.tabularFigures()])),
              ),
            ),
          const SizedBox(width: 8),
          _safetyButton(),
        ]),
        const SizedBox(height: 14),
        DriverCard(driver: d, passengerName: _forOther?.name, lowVision: settings.lowVision),
        if (_forOther != null) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.moroccoGreen, side: const BorderSide(color: AppColors.moroccoGreen)),
            onPressed: _sharePassenger,
            icon: const Icon(Icons.sms_outlined),
            label: Text('${s.t('sendToPassenger')} ${_forOther!.name}', overflow: TextOverflow.ellipsis),
          ),
        ],
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
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
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
            Flexible(
              child: TextButton.icon(
                onPressed: () => setState(() => _speed = _speed == 1 ? 10 : 1),
                icon: Icon(_speed == 1 ? Icons.fast_forward : Icons.play_arrow, size: 18, color: AppColors.muted),
                label: Text(s.t('fastForward'),
                    overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted)),
              ),
            ),
          ]),
      ],
    );
  }

  Widget _action(IconData icon, String label, VoidCallback onTap, {Color color = AppColors.ink}) => Expanded(
          child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(children: [
              CircleAvatar(radius: 22, backgroundColor: Colors.white, foregroundColor: color, child: Icon(icon)),
              const SizedBox(height: 4),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
            ]),
          ),
        ),
      ));

  Widget _donePanel() => Column(
        key: const ValueKey('done'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.t('tripDone'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
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
                    selectedColor: AppColors.moroccoGreen,
                    backgroundColor: Colors.white,
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
                  tooltip: '$i / 5',
                  onPressed: () => setState(() => _rating = i),
                  icon: Icon(i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded, color: AppColors.gold),
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
        backgroundColor: AppColors.sand,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // En-tête vert décoré de zellige, avec le logo.
            Container(
              color: AppColors.moroccoGreen,
              child: Zellige(
                color: Colors.white,
                opacity: .12,
                cell: 40,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(color: AppColors.sand, shape: BoxShape.circle),
                        child: const AppLogo(size: 44),
                      ),
                      const SizedBox(width: 12),
                      Text(s.t('appTitle'),
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
                    ]),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _menuItem(Icons.receipt_long, s.t('history'), () => const HistoryScreen()),
            _menuItem(Icons.people_alt_outlined, s.t('trustedContacts'), () => const TrustedContactsScreen()),
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
              child: Text(s.t('accessibility'), style: const TextStyle(color: AppColors.muted)),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.elderly),
              title: Text(s.t('seniorMode')),
              subtitle: Text(s.t('seniorModeDesc'), style: const TextStyle(color: AppColors.muted)),
              value: settings.senior,
              onChanged: (v) {
                Navigator.pop(context);
                settings.senior = v;
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.visibility_off_outlined),
              title: Text(s.t('lowVision')),
              subtitle: Text(s.t('lowVisionDesc'), style: const TextStyle(color: AppColors.muted)),
              value: settings.lowVision,
              onChanged: (v) => settings.lowVision = v,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.record_voice_over_outlined),
              title: Text(s.t('voiceAnnounce')),
              value: settings.voiceAnnounce,
              onChanged: (v) => settings.voiceAnnounce = v,
            ),
            const Divider(color: AppColors.line),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Text(s.t('language'), style: const TextStyle(color: AppColors.muted)),
            ),
            for (final code in S.supported)
              ListTile(
                title: Text(S.names[code]!),
                trailing: langNotifier.value == code ? const Icon(Icons.check, color: AppColors.moroccoGreen) : null,
                onTap: () {
                  Navigator.pop(context);
                  langNotifier.value = code;
                },
              ),
          ],
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

  // ---------------------------------------------------------------- Écrans du mode senior

  Widget _seniorBody() {
    switch (_step) {
      case RiderStep.idle:
        return SeniorHome(
          onOrder: _openSearch,
          onGoHome: _seniorGoHome,
          onCall: _callContact,
          onExit: () => settings.senior = false,
          contactName: settings.contacts.firstOrNull?.name,
        );
      case RiderStep.choosing:
        return SeniorScaffold(children: [
          Text(s.t('goTo'), style: seniorSmall.copyWith(color: AppColors.muted)),
          Text(_dest!.name, style: seniorText.copyWith(fontSize: 32)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.line, width: 2),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 64,
                  height: 52,
                  decoration: BoxDecoration(color: taxiColor(_selected!.kind), borderRadius: BorderRadius.circular(14)),
                  child: Icon(Icons.local_taxi,
                      size: 34, color: _selected!.kind == TaxiKind.grand ? AppColors.ink : Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(child: Text(_selected!.title, style: seniorText)),
              ]),
              const SizedBox(height: 10),
              Text(dh(_selected!.priceMad), style: seniorText.copyWith(fontSize: 40)),
            ]),
          ),
          const SizedBox(height: 22),
          SeniorButton(
            icon: Icons.check_circle,
            label: s.t('confirm'),
            subtitle: dh(_selected!.priceMad),
            onTap: _request,
          ),
          SeniorTextButton(label: s.t('cancel'), onTap: _reset),
        ]);
      case RiderStep.dispatching:
        final accepted = _candidates.where((c) => c.answer == _Answer.accepted).firstOrNull;
        return SeniorScaffold(children: [
          Semantics(
            liveRegion: true,
            child: Text(accepted == null ? s.t('searching') : '${accepted.driver.name} ${s.t('acceptedFirst')} ✅',
                style: seniorText.copyWith(fontSize: 30)),
          ),
          const SizedBox(height: 28),
          if (accepted == null)
            const Center(
              child: SizedBox.square(
                dimension: 110,
                child: CircularProgressIndicator(strokeWidth: 10, color: AppColors.moroccoGreen),
              ),
            )
          else
            Center(child: DriverPhoto(driver: accepted.driver, size: 120)),
          const SizedBox(height: 32),
          SeniorTextButton(label: s.t('cancel'), onTap: _reset),
        ]);
      case RiderStep.arriving || RiderStep.arrived || RiderStep.onTrip:
        final title = switch (_step) {
          RiderStep.arriving => s.t('arrivingIn'),
          RiderStep.arrived => s.t('arrived'),
          _ => '${s.t('onTrip')} ${_dest!.name}',
        };
        return SeniorTrip(
          title: title,
          driver: _driver!,
          countdown: _step == RiderStep.arrived ? null : _countdown,
          countdownLabel: _step == RiderStep.onTrip ? '${s.t('arrivalAt')} ${_clock(_arrivalTime)}' : null,
          onStart: _step == RiderStep.arrived ? _startTrip : null,
          onSos: () => showSafetySheet(context, taxiId: _driver?.taxiNumber, onShare: _share),
          onFastForward: _step == RiderStep.arrived ? null : () => setState(() => _speed = _speed == 1 ? 10 : 1),
        );
      case RiderStep.done:
        return SeniorScaffold(children: [
          Text(s.t('tripDone'), style: seniorText.copyWith(fontSize: 32)),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
            child: Row(children: [
              DriverPhoto(driver: _driver!, size: 80),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.t('pay'), style: seniorSmall.copyWith(color: AppColors.muted)),
                  Text(dh(_selected!.priceMad), style: seniorText.copyWith(fontSize: 44)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 22),
          SeniorButton(icon: Icons.check, label: s.t('done'), onTap: _finish),
        ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (settings.senior) return _seniorBody();
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
                    builder: (ctx) => MapCircleButton(
                        icon: Icons.menu,
                        tooltip: MaterialLocalizations.of(ctx).openAppDrawerTooltip,
                        onTap: () => Scaffold.of(ctx).openDrawer())),
                const SizedBox(width: 8),
                // Logo et nom de l'application, sur une pastille sable.
                Expanded(
                    child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  heightFactor: 1,
                  child: Container(
                    padding: const EdgeInsetsDirectional.fromSTEB(8, 5, 14, 5),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: AppColors.sand,
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
                    ),
                    child: AppBrand(title: s.t('appTitle'), subtitle: s.t('demoShort')),
                  ),
                )),
                const SizedBox(width: 8),
                MapCircleButton(
                  icon: Icons.elderly,
                  tooltip: s.t('seniorMode'),
                  onTap: () => settings.senior = true,
                ),
                const SizedBox(width: 8),
                MapCircleButton(icon: Icons.my_location, tooltip: s.t('myPosition'), onTap: _locate),
              ]),
            ),
          ),
          Align(alignment: Alignment.bottomCenter, child: BottomPanel(child: _panel())),
        ],
      ),
    );
  }
}
