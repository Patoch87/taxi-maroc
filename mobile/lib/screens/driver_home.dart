import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:latlong2/latlong.dart';

import 'earnings_screen.dart';
import 'premium_driver_screen.dart';
import 'search_screen.dart';
import '../main.dart';
import '../services/demo.dart';
import '../services/driver_earnings.dart';
import '../services/driver_profile.dart';
import '../services/account.dart';
import '../services/driver_shift.dart';
import '../services/live.dart';
import '../services/location.dart';
import '../services/navigation_apps.dart';
import '../services/places.dart';
import '../services/quartiers.dart';
import '../services/rides.dart';
import '../services/routing.dart';
import '../services/driver_notifications.dart';
import '../services/request_chime.dart';
import '../services/settings.dart';
import '../services/voice.dart';
import '../theme.dart';
import '../widgets/google_taxi_map.dart';
import '../widgets/map_parts.dart';
import '../widgets/roadside_help.dart';

/// Demande d'un passager qui se trouve sur la route du chauffeur.
class _Request {
  _Request(this.rider, this.destination, this.rating,
      {this.takenAfter, this.lowVision = false, this.bookedBy, this.babySeat = false});
  final ShiftRider rider;
  final String destination;
  final double rating;

  /// Test réel : identifiant de la demande sur le serveur.
  String? liveId;

  /// Test réel : point où attend le passager.
  LatLng? pickup;

  /// Test réel : destination du passager.
  LatLng? drop;

  /// Passager malvoyant : le chauffeur se présente et le guide jusqu'à la portière.
  final bool lowVision;

  /// Siège bébé demandé : la démo considère que ce chauffeur en a un, il reçoit donc ces demandes.
  final bool babySeat;

  /// Course commandée par quelqu'un d'autre pour ce passager.
  final String? bookedBy;
  final DateTime shownAt = DateTime.now();

  /// La même demande est envoyée à plusieurs chauffeurs : si un autre accepte avant,
  /// elle est bloquée pour celui-ci (démo : après ce délai).
  final Duration? takenAfter;
  DateTime? takenAt;
}

/// Écran chauffeur : carte en mode navigation, compteur de passagers à bord,
/// demandes des passagers qui sont devant le taxi et vont dans sa direction.
class DriverHome extends StatefulWidget {
  const DriverHome({super.key, this.driverApp = false});

  /// Application « Bab Taxi Chauffeur » : écran principal (pas de retour vers le passager), taxi et
  /// plaque pris dans le dossier validé par Bab Taxi.
  final bool driverApp;

  /// Écart minimum entre deux demandes (horloge réelle). Les tests le mettent à zéro pour ne pas
  /// dépendre de la vitesse de la machine.
  @visibleForTesting
  static Duration requestGap = const Duration(seconds: 7);

  @override
  State<DriverHome> createState() => _DriverHomeState();
}

class _DriverHomeState extends State<DriverHome> {
  static const _requestSeconds = 15;
  static const _metersPerTick = 14.0; // vitesse de la simulation (tick de 100 ms)

  final _map = MapController();
  final _rnd = Random();
  final _shift = DriverShift();
  bool _mapReady = false;
  bool _follow = true;
  gm.GoogleMapController? _gmap;
  DateTime _programmaticMoveAt = DateTime(0);

  /// Guidage dans l'application vers ce passager (prise en charge ou dépose), sinon rien.
  ShiftRider? _guideRider;

  bool _online = false;
  late TaxiKind _kind = widget.driverApp && driverProfileStore.profile.grand ? TaxiKind.grand : TaxiKind.petit;
  LatLng _me = casablancaCenter;
  Place? _heading;

  /// Destination du chauffeur (ex. : il rentre chez lui). Il ne reçoit alors que les passagers
  /// pris et déposés sur son trajet, avant sa destination ; arrivé, il passe hors ligne.
  Place? _myDest;

  /// La destination est un quartier dit à voix haute (ou touché) en service : une fois arrivé,
  /// le chauffeur reste en ligne et redevient libre.
  bool _areaDest = false;
  Voice? _voiceEngine;
  Voice get _voice => _voiceEngine ??= Voice();
  List<LatLng> _route = [];
  int _pos = 0;
  double _carry = 0;
  Timer? _tick;
  _Request? _request;

  /// Son doux à chaque nouvelle demande (réglage « Son des demandes »).
  final _chime = RequestChime();

  /// Feux de détresse : rappel affiché une fois par prise en charge, à 50 m ou moins.
  final _pickupAlerts = PickupAlerts();
  ShiftRider? _hazardFor;
  Timer? _hazardTimer;

  void _showHazard(ShiftRider r) {
    _hazardTimer?.cancel();
    setState(() => _hazardFor = r);
    // Pas besoin de toucher l'écran en conduisant : le rappel disparaît seul.
    _hazardTimer = Timer(const Duration(seconds: 6), _hideHazard);
    _chime.alert(r,
        enabled: settings.requestSound,
        voice: settings.requestVoice,
        empty: _shift.onBoard == 0,
        speakText: hazardAnnouncementAr);
    // Navigation dans Waze ou Google Maps : le rappel arrive aussi en notification.
    _notifications.showHazard(title: s.t('hazardLights'), body: '${s.t('hazardNear')} · ${r.name}');
  }

  void _hideHazard() {
    _hazardTimer?.cancel();
    if (mounted && _hazardFor != null) setState(() => _hazardFor = null);
  }

  DateTime _lastRequest = DateTime.now();
  int _requestCount = 0;

  final _notifications = DriverNotifications.instance;
  _Request? _notified;

  @override
  void initState() {
    super.initState();
    _notifications.onAction = _onNotificationAction;
    _notifications.init();
    // Test réel : appels à l'aide des collègues proches (et suivi de son propre appel) toutes les 4 s.
    if (live.enabled) _helpTimer = Timer.periodic(const Duration(seconds: 4), (_) => _pollHelp());
    currentLatLng().then((p) {
      if (!mounted) return;
      setState(() => _me = p);
      _moveCamera(p, 16);
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _stopLive();
    _hazardTimer?.cancel();
    _helpTimer?.cancel();
    for (final t in _helpDemoTimers) {
      t.cancel();
    }
    _chime.cancel();
    if (_notifications.onAction == _onNotificationAction) _notifications.onAction = null;
    _notifications.cancel(DriverNotifications.requestId);
    super.dispose();
  }

  LatLng get _taxi => _liveOn || _route.isEmpty ? _me : _route[_pos];

  double _bearing() {
    if (_route.length < 2) return 0;
    final a = _route[min(_pos, _route.length - 2)];
    final b = _route[min(_pos + 3, _route.length - 1)];
    // Angle mesuré à l'écran (projection de la carte) : 0 = vers le haut, sens des aiguilles d'une montre.
    if (!_mapReady) return const Distance().bearing(a, b) * pi / 180;
    final pa = _map.camera.projectAtZoom(a), pb = _map.camera.projectAtZoom(b);
    return atan2(pb.dx - pa.dx, -(pb.dy - pa.dy));
  }

  /// Le taxi est placé dans le haut de l'écran pour rester visible au-dessus des panneaux.
  static const _followOffset = Offset(0, -170);

  /// Centre la carte (OpenStreetMap ou Google Maps) sur [p] ; [zoom] nul garde le zoom actuel.
  void _moveCamera(LatLng p, double? zoom) {
    if (useGoogleMaps) {
      final c = _gmap;
      if (c == null) return;
      // Suivi du taxi : au plus 3 fois par seconde, la carte Google ne suit pas plus vite.
      final now = DateTime.now();
      if (zoom == null && now.difference(_programmaticMoveAt) < const Duration(milliseconds: 350)) return;
      _programmaticMoveAt = now;
      if (zoom == null) {
        c.animateCamera(gm.CameraUpdate.newLatLng(toGoogle(p)), duration: const Duration(milliseconds: 350));
      } else {
        c.moveCamera(gm.CameraUpdate.newLatLngZoom(toGoogle(p), zoom));
      }
      return;
    }
    if (_mapReady) _map.move(p, zoom ?? _map.camera.zoom, offset: _followOffset);
  }

  double _metersTo(int idx) => idx <= _pos ? 0 : routeLengthM(_route.sublist(_pos, idx + 1));

  /// Distance exacte jusqu'au point [idx] : la partie déjà parcourue du segment en cours est retirée.
  double _exactMetersTo(int idx) => idx <= _pos ? 0 : max(0, _metersTo(idx) - _carry);

  // ---------------------------------------------------------------- Simulation

  bool _routing = false;

  Future<void> _newRoute() async {
    if (_routing) return;
    _routing = true;
    const d = Distance();
    final from = _taxi;
    final far = casablancaPlaces.where((p) => !p.intercity && d(from, LatLng(p.lat, p.lng)) > 2500).toList();
    // Destination choisie par le chauffeur (retour à la maison) : la route y va directement.
    final dest = _myDest ??
        (far.isEmpty ? casablancaPlaces.take(6).toList() : far)[_rnd.nextInt(max(1, far.isEmpty ? 6 : far.length))];
    var route = await fetchRoute(from, LatLng(dest.lat, dest.lng));
    if (route.length < 20) route = interpolate(from, LatLng(dest.lat, dest.lng), 80);
    _routing = false;
    if (!mounted || !_online) return;
    setState(() {
      _heading = dest;
      _route = route;
      _pos = 0;
      _carry = 0;
    });
  }

  Future<void> _goOnline() async {
    _shift.capacity = _kind == TaxiKind.grand ? 6 : 3;
    if (live.enabled) return _goOnlineLive();
    setState(() => _online = true);
    await _newRoute();
    _lastRequest = DateTime.now().subtract(DriverHome.requestGap * 4 ~/ 7);
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(milliseconds: 100), (_) => _onTick());
  }

  void _goOffline() {
    _tick?.cancel();
    _stopLive();
    setState(() {
      _online = false;
      if (_areaDest) {
        _myDest = null;
        _areaDest = false;
      }
      _request = null;
      _route = [];
      _shift.riders.clear();
      _shift.hailOnBoard = 0;
    });
  }

  void _openEarnings() => Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => EarningsScreen(
              todayRides: _shift.earningsToday,
              todayTips: _shift.tipsToday,
              todayRatingSum: _shift.ratingSumToday,
              todayRated: _shift.ratedToday,
              todayRideCount: _shift.ridesToday,
              todayTaxi: _kind == TaxiKind.grand ? DemoTaxi.grand : DemoTaxi.petit)));

  /// « Passager déposé : Salma · +11,25 DH · ★ 5 » : la note compte pour la prime qualité du mois.
  String _droppedText(ShiftRider r) {
    final txt = '${s.t('riderDropped')} : ${r.name} · +${dh(r.fare)}';
    return r.rating > 0 ? '$txt · ★ ${r.rating}' : txt;
  }

  void _onTick() {
    if (!mounted || _route.length < 2) return;
    // En panne ou accidenté : le taxi est arrêté, pas de nouvelle demande.
    if (_myHelp != null) return;
    _demoHelpArrival();
    // Avancer le taxi d'une distance fixe le long de la route.
    // Le taxi ralentit en approchant d'un passager à prendre (démo : environ 5 s pour les 50 derniers mètres).
    final nextPickup = _shift.riders
        .where((r) => !r.onBoard)
        .map((r) => _exactMetersTo(r.pickupIdx))
        .fold<double?>(null, (m, v) => m == null || v < m ? v : m);
    // Passager au point de prise en charge : le taxi l'attend jusqu'à « Démarrer la course ».
    final waiting = _shift.waitingAt(_pos).isNotEmpty;
    _carry = waiting ? 0 : _carry + (nextPickup != null && nextPickup <= 60 ? 1.0 : _metersPerTick);
    const d = Distance();
    var moved = false;
    while (!waiting && _pos < _route.length - 1) {
      if (_shift.waitingAt(_pos).isNotEmpty) break;
      final seg = d(_route[_pos], _route[_pos + 1]);
      if (_carry < seg) break;
      _carry -= seg;
      _pos++;
      moved = true;
    }
    if (moved) {
      // Démo : une Dacia Spring consomme environ 1 % tous les 2 km.
      for (final r in _shift.advance(_pos)) {
        _toast(Icons.check_circle, _droppedText(r));
      }
      if (_follow) _moveCamera(_taxi, null);
    }

    // Un autre chauffeur a accepté en premier : la demande est bloquée, puis disparaît.
    final req = _request;
    if (req != null &&
        req.takenAfter != null &&
        req.takenAt == null &&
        DateTime.now().difference(req.shownAt) >= req.takenAfter!) {
      req.takenAt = DateTime.now();
    }
    if (req != null && req.takenAt != null && DateTime.now().difference(req.takenAt!).inMilliseconds > 2500) {
      _request = null;
    }
    // Demande expirée, ou passager déjà dépassé : refus automatique.
    if (_request != null &&
        (DateTime.now().difference(_request!.shownAt).inSeconds >= _requestSeconds ||
            _pos >= _request!.rider.pickupIdx - 1)) {
      _request = null;
    }
    _maybeNewRequest();
    // Demande partie (acceptée, refusée, expirée) : on arrête l'annonce vocale.
    if (_request == null) _chime.cancel();
    // Demande partie ou prise par un autre chauffeur : la notification disparaît aussi.
    if (_notified != null && (_request != _notified || _notified!.takenAt != null)) {
      _notified = null;
      _notifications.cancel(DriverNotifications.requestId);
    }

    // Bientôt chez le passager : rappel des feux de détresse.
    for (final r in _shift.riders.where((r) => !r.onBoard)) {
      if (_pickupAlerts.check(r, _exactMetersTo(r.pickupIdx))) _showHazard(r);
    }

    // Fin de la route : nouvelle direction si plus personne à déposer.
    if (_pos >= _route.length - 1 && _shift.riders.isEmpty) {
      if (_myDest != null && !_areaDest) {
        // Arrivé chez lui : fin du service, plus de demandes.
        _toast(Icons.flag_rounded, '${s.t('driverDestReached')} : ${_myDest!.name}');
        _myDest = null;
        _goOffline();
        return;
      }
      if (_myDest != null) {
        // Arrivé dans le quartier annoncé : il reste en ligne, les demandes redeviennent libres.
        _toast(Icons.flag_rounded, '${s.t('areaReached')} : ${_myDest!.name}');
        _myDest = null;
        _areaDest = false;
      }
      _newRoute();
    }
    setState(() {});
  }

  void _maybeNewRequest() {
    if (_request != null || _shift.isFull) return;
    if (DateTime.now().difference(_lastRequest) < DriverHome.requestGap) return;
    final remaining = _route.length - 1 - _pos;
    if (remaining < 20) return;
    const names = ['Amina', 'Karim', 'Salma', 'Omar', 'Fatima Zahra', 'Mehdi', 'Hajar', 'Anas', 'Imane', 'Yassine'];
    var pickup = _pos + max<int>(3, (remaining * (0.08 + _rnd.nextDouble() * 0.1)).round());
    // Au moins 600 m devant le taxi, pour avoir le temps d'accepter.
    while (pickup < _route.length - 6 && routeLengthM(_route.sublist(_pos, pickup + 1)) < 600) {
      pickup++;
    }
    if (pickup >= _route.length - 6) return;
    final int drop = min<int>(_route.length - 1,
        pickup + max<int>(5, ((_route.length - 1 - pickup) * (0.35 + _rnd.nextDouble() * 0.5)).round()));
    final seats = _shift.freeSeats >= 2 && _rnd.nextInt(4) == 0 ? 2 : 1;
    final km = routeLengthM(_route.sublist(pickup, drop + 1)) / 1000;
    final fare =
        _kind == TaxiKind.grand ? 12.0 * seats : Demo.petitTaxiPrice(routeKm: km, seul: false, premium: false) * seats;
    _lastRequest = DateTime.now();
    final first = _requestCount++ == 0;
    final name = names[_rnd.nextInt(names.length)];
    _request = _Request(
      ShiftRider(
          name: name,
          pickupIdx: pickup,
          dropIdx: drop,
          fare: fare,
          seats: seats,
          // Démo : un passager sur deux laisse un pourboire par carte ; la plupart notent 5 étoiles.
          tip: _rnd.nextBool() ? const [5.0, 10.0, 20.0][_rnd.nextInt(3)] : 0,
          rating: _rnd.nextInt(10) < 7 ? 5 : 4),
      _nearestPlaceName(_route[drop]),
      4.5 + _rnd.nextInt(5) / 10,
      takenAfter: !first && _rnd.nextInt(4) == 0 ? Duration(milliseconds: 4000 + _rnd.nextInt(6000)) : null,
      // Démo : si le passager de l'application s'est déclaré malvoyant, la première demande l'est aussi.
      lowVision: (first && settings.lowVision) || _rnd.nextInt(5) == 0,
      babySeat: _rnd.nextInt(4) == 0,
      bookedBy: _rnd.nextInt(4) == 0 ? names.where((n) => n != name).elementAt(_rnd.nextInt(names.length - 1)) : null,
    );
    // Son doux ; taxi vide : la destination est aussi lue en arabe.
    _chime.onRequest(
      _request,
      enabled: settings.requestSound,
      voice: settings.requestVoice,
      empty: _shift.onBoard == 0,
      speakText: requestAnnouncementAr(arabicPlaceName(_request!.destination)),
    );
    _notifyRequest(_request!);
  }

  /// Chauffeur dans Waze ou Google Maps : la demande arrive en notification, avec Accepter et Refuser.
  void _notifyRequest(_Request r) {
    if (!_notifications.inBackground) return;
    _notified = r;
    final seats = r.rider.seats > 1 ? ' ×${r.rider.seats}' : '';
    _notifications.showRequest(
      key: '${identityHashCode(r)}',
      title: '${s.t('newRequest')} · ${dhRange(r.rider.fare)}',
      body: '${r.rider.name}$seats → ${r.destination} · ${s.t('pickUp')} : '
          '${_exactMetersTo(r.rider.pickupIdx).round()} m',
      accept: s.t('accept'),
      decline: s.t('decline'),
    );
  }

  @visibleForTesting
  String? get debugRequestKey => _request == null ? null : '${identityHashCode(_request)}';

  void _onNotificationAction(String action, String? key) {
    final r = _request;
    if (!mounted || r == null || key != '${identityHashCode(r)}') return;
    _notified = null;
    if (action == acceptAction) _accept();
    if (action == declineAction) _decline();
  }

  String _nearestPlaceName(LatLng p) {
    const d = Distance();
    final near = casablancaPlaces
        .where((x) => !x.intercity)
        .reduce((a, b) => d(p, LatLng(a.lat, a.lng)) < d(p, LatLng(b.lat, b.lng)) ? a : b);
    return d(p, LatLng(near.lat, near.lng)) < 1500 ? near.name : (_heading?.name ?? '');
  }

  void _accept() {
    final r = _request!;
    if (r.takenAt != null || !_shift.canAccept(r.rider.seats)) return;
    if (r.liveId != null) {
      _acceptLive(r);
      return;
    }
    _chime.cancel();
    setState(() {
      _shift.accept(r.rider);
      _request = null;
    });
  }

  void _decline() {
    _chime.cancel();
    final id = _request?.liveId;
    if (id != null) {
      _declined.add(id);
      _liveApi.decline(id, live.deviceId).ignore();
      _dropPreviewRoute();
    }
    setState(() => _request = null);
  }

  // ---------------------------------------------------------------- Test réel

  /// Test réel : position GPS du téléphone, demandes du serveur, prise en charge à l'arrivée au point.
  bool get _liveOn => _online && _liveTimers.isNotEmpty;
  final _liveApi = LiveApi();
  final _liveTimers = <Timer>[];
  StreamSubscription<LatLng>? _gps;
  final _liveIds = <ShiftRider, String>{};

  /// Test réel : passagers dont le taxi est arrivé près du point de prise en charge (GPS).
  final _atPickup = <ShiftRider>{};

  /// Test réel : point exact où attend chaque passager (le point de l'itinéraire peut en être loin).
  final _pickupPoints = <ShiftRider, LatLng>{};

  /// Test réel : destination exacte de chaque passager ; elle peut changer pendant la course.
  final _dropPoints = <ShiftRider, LatLng>{};
  bool _destBusy = false;

  /// Toutes les 4 s : le passager a-t-il changé de destination ? Le tracé et le point de dépôt suivent.
  Future<void> _pollDestinations() async {
    if (_destBusy || !_liveOn || _liveIds.isEmpty) return;
    _destBusy = true;
    try {
      for (final e in _liveIds.entries.toList()) {
        final ride = await _liveApi.ride(e.value);
        final rider = e.key;
        final drop = ride.drop;
        if (!mounted || !_liveOn || _liveIds[rider] != e.value || drop == null) continue;
        final known = _dropPoints[rider];
        final renamed = ride.destinationName.isNotEmpty && ride.destinationName != rider.destination;
        if (!renamed && known != null && const Distance()(known, drop) < 30) continue;
        if (known == null && !renamed) {
          _dropPoints[rider] = drop;
          continue;
        }
        await _applyNewDestination(rider, drop, ride.destinationName, ride.fare);
      }
    } catch (_) {
      // Réseau coupé : nouvel essai dans 4 secondes.
    } finally {
      _destBusy = false;
    }
  }

  Future<void> _applyNewDestination(ShiftRider rider, LatLng drop, String name, double fare) async {
    _dropPoints[rider] = drop;
    if (_myDest == null && _shift.riders.length == 1) {
      // Un seul passager : nouvel itinéraire depuis la position du taxi (par le passager s'il attend encore).
      final pick = _pickupPoints[rider] ?? (_route.isEmpty ? _me : _route[min(rider.pickupIdx, _route.length - 1)]);
      final toPickup = rider.onBoard ? <LatLng>[_me] : await fetchRoute(_me, pick);
      final toDrop = await fetchRoute(rider.onBoard ? _me : pick, drop);
      if (!mounted || !_shift.riders.contains(rider)) return;
      setState(() {
        _route = [...toPickup, ...toDrop.skip(1)];
        _pos = 0;
        rider.pickupIdx = rider.onBoard ? 0 : toPickup.length - 1;
        rider.dropIdx = _route.length - 1;
      });
    } else {
      setState(() => rider.dropIdx = min(_route.length - 1,
          max(rider.pickupIdx + 1, _nearestIndex(drop, from: max(_pos, rider.pickupIdx)))));
    }
    setState(() {
      if (name.isNotEmpty) rider.destination = name;
      if (fare > 0) rider.fare = fare;
    });
    _publish();
    HapticFeedback.heavyImpact();
    _toast(Icons.edit_location_alt, '${s.t('destChangedBy')} ${rider.name} : ${name.isEmpty ? '?' : name}');
  }

  /// Le bouton « Démarrer la course » apparaît à 150 m du passager. Vérifié à chaque position GPS, à
  /// l'acceptation et toutes les 500 ms : un taxi déjà garé près du passager ne bouge pas, le GPS ne
  /// donne alors aucune nouvelle position.
  void _checkPickups() {
    const d = Distance();
    for (final r in _shift.riders) {
      if (r.onBoard || _atPickup.contains(r)) continue;
      final target = _pickupPoints[r] ?? (_route.isEmpty ? null : _route[min(r.pickupIdx, _route.length - 1)]);
      if (target != null && d(_me, target) <= 150) _atPickup.add(r);
    }
  }

  /// Passagers à prendre maintenant : le chauffeur démarre leur course quand ils sont à bord.
  List<ShiftRider> get _readyToStart => _liveOn
      ? [
          for (final r in _shift.riders)
            if (!r.onBoard && _atPickup.contains(r)) r
        ]
      : _shift.waitingAt(_pos);

  /// « Démarrer la course » : le passager est à bord, il voit la course commencer sur son téléphone.
  void _startRide(ShiftRider r) {
    setState(() {
      _shift.pickUp(r);
      // Le passager est à bord : le tracé repart du point de prise en charge.
      if (_liveOn) _pos = max(_pos, min(r.pickupIdx, _route.length - 1));
      _atPickup.remove(r);
      _pickupPoints.remove(r);
    });
    if (_hazardFor == r) _hideHazard();
    final id = _liveIds[r];
    if (id != null) _liveApi.pickedUp(id, live.deviceId).ignore();
    HapticFeedback.mediumImpact();
    _toast(Icons.play_circle_fill, '${s.t('riderPickedUp')} : ${r.name} · ${_shift.onBoard}/${_shift.capacity}');
  }

  /// Carte « Démarrer la course », toujours visible au-dessus du panneau : un seul grand bouton.
  Widget _startRideCard(ShiftRider r) => Container(
        key: ValueKey('startRide-${r.name}'),
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text('${r.name}${r.seats > 1 ? ' (${r.seats})' : ''} · ${s.t('boardThenStart')}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.moroccoGreen, minimumSize: const Size(0, 54)),
            onPressed: () => _startRide(r),
            icon: const Icon(Icons.play_arrow_rounded, size: 28),
            label: Text(s.t('startRide'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ),
        ]),
      );
  final _declined = <String>{};
  String _plate = '';

  /// Itinéraire proposé avec une demande quand le taxi n'en avait pas (sans destination) :
  /// il est retiré si la demande est refusée.
  bool _previewRoute = false;

  /// Dossier validé du chauffeur (application chauffeur).
  void _showProfile() {
    final p = driverProfileStore.profile;
    final a = accountStore.account;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${a?.firstName ?? ''} ${a?.lastName ?? ''}'.trim(),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.verified, color: AppColors.moroccoGreen, size: 20),
              const SizedBox(width: 6),
              Text(s.t('dsApproved'), style: const TextStyle(color: AppColors.moroccoGreen, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 12),
            Text('${s.t(p.grand ? 'grandTaxi' : 'petitTaxi')} n° ${p.taxiNumber} · ${p.plate}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(p.city, style: const TextStyle(color: AppColors.muted)),
          ]),
        ),
      ),
    );
  }

  Future<void> _goOnlineLive() async {
    final profile = driverProfileStore.profile;
    // Application chauffeur : la plaque vient du dossier validé, rien à saisir.
    final plate = widget.driverApp && profile.plate.isNotEmpty ? profile.plate : await _askPlate();
    if (plate == null || !mounted) return;
    _plate = plate;
    final here = await currentLatLng();
    if (!mounted) return;
    setState(() {
      _online = true;
      _me = here;
      _route = [];
      _pos = 0;
      _carry = 0;
    });
    _moveCamera(here, 16);
    final dest = _myDest;
    if (dest != null) {
      final route = await fetchRoute(here, LatLng(dest.lat, dest.lng));
      if (!mounted || !_online) return;
      setState(() {
        _heading = dest;
        _route = route;
      });
    }
    _gps = positionStream().listen(_onGps, onError: (_) {});
    _liveTimers
      ..add(Timer.periodic(const Duration(seconds: 3), (_) => _publish()))
      ..add(Timer.periodic(const Duration(seconds: 2), (_) => _pollOffers()))
      ..add(Timer.periodic(const Duration(seconds: 4), (_) => _pollDestinations()))
      ..add(Timer.periodic(const Duration(milliseconds: 500), (_) => _liveTick()));
    _publish();
  }

  Future<String?> _askPlate() {
    final ctrl = TextEditingController(text: _plate);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.t('goOnline')),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(s.t('liveDriverIntro')),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('plate'),
            controller: ctrl,
            decoration: InputDecoration(labelText: s.t('plateOptional'), hintText: '12345 | أ | 6'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.t('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: Text(s.t('goOnline'))),
        ],
      ),
    );
  }

  void _stopLive() {
    for (final t in _liveTimers) {
      t.cancel();
    }
    _liveTimers.clear();
    _gps?.cancel();
    _gps = null;
    _liveIds.clear();
    _atPickup.clear();
    _pickupPoints.clear();
    _dropPoints.clear();
    _previewRoute = false;
    if (live.enabled) _liveApi.goOffline(live.deviceId).ignore();
  }

  Future<void> _publish() async {
    try {
      await _liveApi.publishTaxi(
        id: live.deviceId,
        position: _me,
        route: _route.isEmpty || _previewRoute ? const [] : _route.sublist(min(_pos, _route.length - 1)),
        grand: _kind == TaxiKind.grand,
        onBoard: _shift.onBoard,
        plate: _plate,
      );
    } catch (_) {
      // Réseau coupé : nouvel essai dans 3 secondes.
    }
  }

  int _nearestIndex(LatLng p, {int from = 0}) {
    const d = Distance();
    var best = min(from, max(0, _route.length - 1));
    for (var i = best + 1; i < _route.length; i++) {
      if (d(p, _route[i]) < d(p, _route[best])) best = i;
    }
    return best;
  }

  void _onGps(LatLng p) {
    if (!mounted || !_liveOn) return;
    const d = Distance();
    setState(() {
      _me = p;
      // Avance sur l'itinéraire : point le plus proche dans les 300 m qui suivent (jamais en arrière). La limite
      // en mètres évite de sauter à la fin quand l'itinéraire repasse près de l'endroit où se trouve le taxi
      // (demi-tour, sens unique) : le tracé disparaissait et il ne restait que « 40 m ».
      if (_route.length > 1) {
        var best = _pos, along = 0.0;
        for (var i = _pos + 1; i < _route.length && along <= 300; i++) {
          along += d(_route[i - 1], _route[i]);
          if (d(p, _route[i]) < d(p, _route[best])) best = i;
        }
        _pos = best;
      }
    });
    if (_follow) _moveCamera(p, null);

    for (final r in _shift.riders.toList()) {
      final id = _liveIds[r];
      if (!r.onBoard) {
        final m = d(p, _route[min(r.pickupIdx, _route.length - 1)]);
        if (_pickupAlerts.check(r, m)) _showHazard(r);
        // Près du passager : le bouton « Démarrer la course » apparaît.
        if (!_atPickup.contains(r)) setState(_checkPickups);
      } else if (d(p, _route[min(r.dropIdx, _route.length - 1)]) <= 60 ||
          (_dropPoints[r] != null && d(p, _dropPoints[r]!) <= 60)) {
        setState(() => _shift.dropOff(r));
        _liveIds.remove(r);
        if (id != null) _liveApi.droppedOff(id, live.deviceId).ignore();
        _toast(Icons.check_circle, '${s.t('riderDropped')} : ${r.name} · +${dh(r.fare)}');
      }
    }

    // Plus personne à bord ni attendu : sans destination, le taxi redevient libre (demandes proches).
    if (_shift.riders.isEmpty && _route.isNotEmpty && !_previewRoute) {
      final dest = _myDest;
      if (dest == null) {
        setState(() {
          _route = [];
          _pos = 0;
        });
      } else if (d(p, LatLng(dest.lat, dest.lng)) <= (_areaDest ? 400 : 80)) {
        if (_areaDest) {
          // Quartier atteint : il reste en ligne, libre.
          _toast(Icons.flag_rounded, '${s.t('areaReached')} : ${dest.name}');
          setState(() {
            _myDest = null;
            _areaDest = false;
            _route = [];
            _pos = 0;
          });
          return;
        }
        _toast(Icons.flag_rounded, '${s.t('driverDestReached')} : ${dest.name}');
        _myDest = null;
        _goOffline();
      }
    }
  }

  /// Une demande proposée sans itinéraire : celui du passager est montré, puis retiré s'il est refusé.
  void _dropPreviewRoute() {
    if (!_previewRoute) return;
    _previewRoute = false;
    if (_shift.riders.isEmpty) {
      _route = [];
      _pos = 0;
    }
  }

  bool _offerBusy = false;

  Future<void> _pollOffers() async {
    if (_offerBusy || !_liveOn || _myHelp != null) return;
    _offerBusy = true;
    try {
      final offers = await _liveApi.offers(live.deviceId);
      if (!mounted || !_liveOn) return;
      final req = _request;
      if (req != null) {
        // La demande n'est plus proposée : un autre chauffeur l'a prise, ou le passager a annulé.
        if (req.takenAt == null && !offers.any((o) => o.id == req.liveId)) setState(() => req.takenAt = DateTime.now());
        return;
      }
      if (_shift.isFull) return;
      final o = offers.where((o) => !_declined.contains(o.id) && _shift.canAccept(o.seats)).firstOrNull;
      if (o != null) await _showOffer(o);
    } catch (_) {
      // Réseau coupé : nouvel essai dans 2 secondes.
    } finally {
      _offerBusy = false;
    }
  }

  Future<void> _showOffer(LiveOffer o) async {
    // Sans itinéraire : celui qui passe par le passager puis par sa destination.
    if (_route.length < 2) {
      final toPickup = await fetchRoute(_me, o.pickup);
      final toDrop = await fetchRoute(o.pickup, o.drop);
      if (!mounted || !_liveOn || _request != null) return;
      _route = [...toPickup, ...toDrop.skip(1)];
      _pos = 0;
      _previewRoute = true;
    }
    final pickupIdx = _nearestIndex(o.pickup, from: _pos);
    final dropIdx = max(pickupIdx + 1, _nearestIndex(o.drop, from: pickupIdx));
    setState(() {
      _request = _Request(
        ShiftRider(
          name: o.riderName,
          pickupIdx: pickupIdx,
          dropIdx: min(dropIdx, _route.length - 1),
          fare: o.fare,
          seats: o.seats,
          destination: o.destinationName,
        ),
        o.destinationName,
        5,
      )
        ..liveId = o.id
        ..pickup = o.pickup
        ..drop = o.drop;
    });
    _chime.onRequest(
      _request,
      enabled: settings.requestSound,
      voice: settings.requestVoice,
      empty: _shift.onBoard == 0,
      speakText: requestAnnouncementAr(arabicPlaceName(o.destinationName)),
    );
    _notifyRequest(_request!);
  }

  Future<void> _acceptLive(_Request r) async {
    _chime.cancel();
    final ok = await _liveApi.accept(r.liveId!, live.deviceId).catchError((_) => false);
    if (!mounted || _request != r) return;
    if (!ok) {
      setState(() => r.takenAt = DateTime.now());
      return;
    }
    setState(() {
      _shift.accept(r.rider);
      _liveIds[r.rider] = r.liveId!;
      if (r.pickup != null) _pickupPoints[r.rider] = r.pickup!;
      if (r.drop != null) _dropPoints[r.rider] = r.drop!;
      _checkPickups();
      _previewRoute = false;
      _request = null;
    });
    _publish();
  }

  /// Toutes les 500 ms : demande prise par un autre ou expirée, notification, rafraîchissement.
  void _liveTick() {
    if (!mounted) return;
    final req = _request;
    if (req != null && req.takenAt != null && DateTime.now().difference(req.takenAt!).inMilliseconds > 2500) {
      _request = null;
      _dropPreviewRoute();
    } else if (req != null && DateTime.now().difference(req.shownAt).inSeconds >= _requestSeconds) {
      // Sans réponse : refus automatique, la demande part aux autres chauffeurs.
      _decline();
      return;
    }
    if (_request == null) _chime.cancel();
    if (_notified != null && (_request != _notified || _notified!.takenAt != null)) {
      _notified = null;
      _notifications.cancel(DriverNotifications.requestId);
    }
    setState(_checkPickups);
  }

  void _toast(IconData icon, String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 300),
        backgroundColor: AppColors.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 2),
        content: Row(children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      ));
  }


  // ---------------------------------------------------------------- Panne ou accident (entraide)

  /// Appel à l'aide envoyé par ce chauffeur (panne ou accident), encore ouvert.
  HelpAlert? _myHelp;

  /// Appel d'un collègue proche, affiché à la place du panneau.
  HelpAlert? _incomingHelp;

  /// Collègue que ce chauffeur va aider (« J'arrive » ou passagers repris).
  HelpAlert? _helping;
  final _seenHelp = <String>{};
  Timer? _helpTimer;
  bool _helpBusy = false;

  /// Démo : réponses simulées des collègues, et point de la route où attend le collègue en panne.
  final _helpDemoTimers = <Timer>[];
  final _demoHelpIdx = <String, int>{};

  HelpAlert? get _helpTarget => _helping ?? _incomingHelp;

  int get _ridersSeats => _shift.riders.fold(0, (n, r) => n + r.seats);

  Widget _helpButton() => OutlinedButton.icon(
        key: const ValueKey('helpButton'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.taxiRed,
          side: const BorderSide(color: AppColors.taxiRed, width: 1.5),
          minimumSize: const Size(0, 46),
        ),
        onPressed: _myHelp == null ? _askForHelp : null,
        icon: const Icon(Icons.car_crash_outlined),
        label: Text(s.t('helpButton'), style: const TextStyle(fontWeight: FontWeight.w800)),
      );

  /// « Panne ou accident » : choix, secours, puis appel aux taxis Bab Taxi à moins de 5 km.
  Future<void> _askForHelp() async {
    if (_myHelp != null) return;
    final choice = await showRoadsideHelpSheet(context, riders: _ridersSeats);
    if (choice == null || !mounted) return;
    // Plus de nouvelle demande tant que l'appel est ouvert.
    if (_request != null) _decline();
    _incomingHelp = null;
    if (live.enabled) {
      try {
        final here = _liveOn ? _me : await currentLatLng();
        final a = await _liveApi.callForHelp(position: here, accident: choice.accident, injured: choice.injured);
        if (!mounted) return;
        setState(() => _myHelp = a);
      } catch (_) {
        if (mounted) _toast(Icons.wifi_off, s.t('liveUnreachable'));
        return;
      }
    } else {
      setState(() => _myHelp = HelpAlert(
            id: 'demo-mine',
            taxiId: 'demo',
            name: '',
            accident: choice.accident,
            injured: choice.injured,
            position: _taxi,
            riders: _ridersSeats,
            notified: 4 + _rnd.nextInt(5),
          ));
      _runDemoHelp();
    }
    HapticFeedback.heavyImpact();
  }

  /// Démo : un collègue arrive au bout de 3 s ; un autre reprend les passagers au bout de 6 s.
  void _runDemoHelp() {
    void reply(Duration after, HelpReply r) => _helpDemoTimers.add(Timer(after, () {
          final a = _myHelp;
          if (!mounted || a == null) return;
          if (r.takesRiders && _shift.riders.isEmpty) return;
          _updateMyHelp(a.copyWith(replies: [...a.replies, r], takenBy: r.takesRiders ? r.taxiId : null));
          if (r.takesRiders) {
            setState(() {
              _shift.riders.clear();
              _guideRider = null;
            });
            _hideHazard();
          }
        }));
    reply(const Duration(seconds: 3), HelpReply('demo-y', 'Youssef', false, plate: '41237 | أ | 6'));
    reply(const Duration(seconds: 6), HelpReply('demo-k', 'Karim', true, plate: '18560 | ب | 6'));
  }

  /// Nouvelles réponses des collègues : message et vibration ; passagers repris : ils quittent ce taxi.
  void _updateMyHelp(HelpAlert a) {
    final old = _myHelp;
    for (final r in a.replies) {
      if (old != null && old.replies.any((o) => o.taxiId == r.taxiId && o.takesRiders == r.takesRiders)) continue;
      HapticFeedback.mediumImpact();
      _toast(r.takesRiders ? Icons.people_alt : Icons.local_taxi,
          '${r.name} ${s.t(r.takesRiders ? 'helpTakesRiders' : 'helpComing')}');
    }
    _handOver(a.takenRides);
    setState(() => _myHelp = a);
  }

  /// Test réel : courses reprises par un collègue. Elles ne sont plus à ce taxi (ni gain ni dépose ici).
  void _handOver(List<String> rideIds) {
    if (rideIds.isEmpty) return;
    for (final e in _liveIds.entries.toList()) {
      if (!rideIds.contains(e.value)) continue;
      final r = e.key;
      _shift.riders.remove(r);
      _liveIds.remove(r);
      _atPickup.remove(r);
      _pickupPoints.remove(r);
      _dropPoints.remove(r);
      if (_guideRider == r) _guideRider = null;
      if (_hazardFor == r) _hideHazard();
    }
  }

  /// « Problème réglé » : l'appel est fermé, les demandes reprennent.
  void _solveHelp() {
    final a = _myHelp;
    if (a == null) return;
    for (final t in _helpDemoTimers) {
      t.cancel();
    }
    _helpDemoTimers.clear();
    setState(() => _myHelp = null);
    if (live.enabled) _liveApi.endHelp(a.id).ignore();
    _lastRequest = DateTime.now();
  }

  Future<void> _pollHelp() async {
    if (_helpBusy || !live.enabled) return;
    _helpBusy = true;
    try {
      final mine = _myHelp;
      if (mine != null) {
        final a = await _liveApi.helpAlert(mine.id);
        if (mounted && _myHelp?.id == mine.id) _updateMyHelp(a);
        return;
      }
      final going = _helping;
      if (going != null) {
        final a = await _liveApi.helpAlert(going.id);
        if (!mounted || _helping?.id != going.id) return;
        if (!a.open) {
          _helpClosed(a);
        } else {
          setState(() => _helping = a);
        }
        return;
      }
      if (!_liveOn) return;
      final list = await _liveApi.nearbyHelp(_me);
      if (!mounted || !_liveOn || _myHelp != null) return;
      final shown = _incomingHelp;
      if (shown != null) {
        // Toujours ouvert ? (fermé : la carte disparaît ; passagers repris par un autre : le bouton aussi.)
        setState(() => _incomingHelp = list.where((a) => a.id == shown.id).firstOrNull);
        return;
      }
      final next = list.where((a) => !_seenHelp.contains(a.id)).firstOrNull;
      if (next != null) _showIncomingHelp(next);
    } catch (_) {
      // Réseau coupé : nouvel essai dans 4 secondes.
    } finally {
      _helpBusy = false;
    }
  }

  void _showIncomingHelp(HelpAlert a) {
    _seenHelp.add(a.id);
    setState(() => _incomingHelp = a);
    _chime.alert(a,
        enabled: settings.requestSound,
        voice: settings.requestVoice,
        empty: _shift.onBoard == 0,
        speakText: helpAnnouncementAr);
    HapticFeedback.heavyImpact();
    _notifications.showHelp(
        title: s.t('helpIncoming'),
        body: [a.name, s.t(a.accident ? 'helpAccident' : 'helpBreakdown'), helpDistance(a.distanceM)]
            .where((x) => x.isNotEmpty)
            .join(' · '));
  }

  /// « J'arrive » : le chauffeur va aider son collègue (bandeau en haut, itinéraire).
  Future<void> _helpGo() async {
    final a = _incomingHelp;
    if (a == null) return;
    _chime.cancel();
    setState(() {
      _incomingHelp = null;
      _helping = a;
    });
    if (!live.enabled) return;
    try {
      await _liveApi.answerHelp(a.id, takeRiders: false);
    } on LiveConflict {
      if (mounted) _helpClosed(a);
    } catch (_) {
      // Réseau coupé : le collègue ne le voit pas encore, le bandeau reste.
    }
  }

  /// « Je prends les passagers » : leurs courses passent sur ce taxi ; ils attendent au taxi en panne.
  Future<void> _helpTake() async {
    final a = _incomingHelp;
    if (a == null) return;
    _chime.cancel();
    setState(() => _incomingHelp = null);
    if (live.enabled) {
      try {
        final rides = await _liveApi.answerHelp(a.id, takeRiders: true);
        if (!mounted) return;
        await _adoptLiveRiders(rides);
      } on LiveConflict {
        if (mounted) _toast(Icons.info_outline, s.t('helpTakenByOther'));
        return;
      } catch (_) {
        if (mounted) _toast(Icons.wifi_off, s.t('liveUnreachable'));
        return;
      }
    } else {
      _adoptDemoRiders(a);
    }
    if (!mounted) return;
    setState(() => _helping = a);
    HapticFeedback.mediumImpact();
    _toast(Icons.people_alt, s.t('helpRidersAdded'));
  }

  void _helpDismiss() {
    _chime.cancel();
    setState(() => _incomingHelp = null);
  }

  /// Test réel : courses reprises, comme des courses acceptées (prise en charge au taxi en panne).
  Future<void> _adoptLiveRiders(List<LiveOffer> rides) async {
    for (final o in rides) {
      if (!_shift.canAccept(o.seats)) continue;
      if (_route.length < 2 || _previewRoute) {
        final toPickup = await fetchRoute(_me, o.pickup);
        final toDrop = await fetchRoute(o.pickup, o.drop);
        if (!mounted) return;
        _route = [...toPickup, ...toDrop.skip(1)];
        _pos = 0;
        _previewRoute = false;
      }
      final pickupIdx = _nearestIndex(o.pickup, from: _pos);
      final dropIdx = min(_route.length - 1, max(pickupIdx + 1, _nearestIndex(o.drop, from: pickupIdx)));
      final r = ShiftRider(
          name: o.riderName,
          pickupIdx: pickupIdx,
          dropIdx: dropIdx,
          fare: o.fare,
          seats: o.seats,
          destination: o.destinationName);
      setState(() {
        _shift.accept(r);
        _liveIds[r] = o.id;
        _pickupPoints[r] = o.pickup;
        _dropPoints[r] = o.drop;
        _checkPickups();
      });
    }
    _publish();
  }

  /// Démo : les passagers du collègue attendent à son taxi, sur la route ; ils vont plus loin sur la route.
  void _adoptDemoRiders(HelpAlert a) {
    final at = max<int>(_pos + 3, _demoHelpIdx[a.id] ?? _pos + 10);
    if (at >= _route.length - 3) return;
    final names = ['Nadia', 'Rachid', 'Samira'];
    setState(() {
      for (var i = 0; i < a.riders && _shift.canAccept(1); i++) {
        final drop = min<int>(_route.length - 1, at + max<int>(5, ((_route.length - 1 - at) * (0.5 + 0.2 * i)).round()));
        final km = routeLengthM(_route.sublist(at, drop + 1)) / 1000;
        _shift.accept(ShiftRider(
          name: names[i % names.length],
          pickupIdx: at,
          dropIdx: drop,
          fare: Demo.petitTaxiPrice(routeKm: km, seul: false, premium: false),
          rating: 5,
          destination: _nearestPlaceName(_route[drop]),
        ));
      }
    });
  }

  /// Démo (menu) : un collègue tombe en panne un peu plus loin sur la route, avec 2 passagers.
  void _demoIncomingHelp() {
    if (!_online) _goOnline();
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (!mounted || _myHelp != null) return;
      final remaining = _route.length - 1 - _pos;
      if (remaining < 30) return;
      final idx = _pos + max<int>(10, (remaining * .25).round());
      final dropAt = min<int>(_route.length - 1, idx + (remaining * .5).round());
      final a = HelpAlert(
        id: 'demo-${DateTime.now().millisecondsSinceEpoch}',
        taxiId: 'demo-h',
        name: 'Hamid',
        plate: '28451 | ب | 6',
        accident: false,
        position: _route[idx],
        riders: min<int>(2, max<int>(1, _shift.freeSeats)),
        destinations: [_nearestPlaceName(_route[dropAt])].where((n) => n.isNotEmpty).toList(),
        notified: 5,
        distanceM: _exactMetersTo(idx),
      );
      _demoHelpIdx[a.id] = idx;
      if (_request != null) _decline();
      _showIncomingHelp(a);
    });
  }

  /// Démo : arrivé auprès du collègue, il le remercie et l'appel se ferme.
  void _demoHelpArrival() {
    final h = _helping;
    if (h == null || live.enabled) return;
    final idx = _demoHelpIdx[h.id];
    if (idx != null && _pos >= idx) _helpClosed(h);
  }

  void _helpClosed(HelpAlert a) {
    setState(() => _helping = null);
    _toast(Icons.volunteer_activism, '${a.name} ${s.t('helpClosedBy')}');
  }

  double? _helpDistanceM(HelpAlert a) {
    if (!live.enabled) {
      final idx = _demoHelpIdx[a.id];
      return idx == null ? null : _exactMetersTo(idx);
    }
    return const Distance()(_me, a.position);
  }

  Future<void> _routeToHelp(HelpAlert a) async {
    final app = settings.navApp == NavApp.waze ? NavApp.waze : NavApp.googleMaps;
    final result = await openNavigation(app, a.position);
    if (!mounted) return;
    if (result == NavOpenResult.store) _toast(Icons.download, '${navAppName(app)} : ${s.t('navNotInstalled')}');
    if (result == NavOpenResult.web) _toast(Icons.public, s.t('navWebFallback'));
    if (result == NavOpenResult.failed) _toast(Icons.error_outline, s.t('navFailed'));
  }

  /// « Je ne peux plus » : le collègue ne le compte plus parmi ceux qui arrivent.
  void _cancelHelping() {
    final a = _helping;
    if (a == null) return;
    setState(() => _helping = null);
    if (live.enabled) _liveApi.withdrawHelp(a.id).ignore();
  }

  // ---------------------------------------------------------------- Carte

  Widget _buildMap() {
    final pending = _shift.riders.where((r) => !r.onBoard);
    final req = _request?.rider;
    if (useGoogleMaps) {
      return GoogleTaxiMap(
        taxi: _taxi,
        taxiKind: _kind,
        bearingDeg: _bearing() * 180 / pi,
        route: _route.length > 1 && _pos < _route.length - 1 ? _route.sublist(_pos) : const [],
        pins: [
          for (final r in _shift.riders)
            GooglePin('drop-${r.name}', _route[min(r.dropIdx, _route.length - 1)], '${s.t('dropAt')} ${r.name}',
                gm.BitmapDescriptor.hueRed, style: PinStyle.dest),
          for (final r in pending)
            GooglePin(
                'pick-${r.name}', _route[r.pickupIdx], '${s.t('pickUp')} ${r.name}', gm.BitmapDescriptor.hueGreen,
                style: PinStyle.pickup),
          if (req != null) GooglePin('req-${req.name}', _route[req.pickupIdx], req.name, gm.BitmapDescriptor.hueYellow),
          if (_helpTarget case final h?)
            GooglePin('help-${h.id}', h.position, '${s.t('helpIncoming')} · ${h.name}', gm.BitmapDescriptor.hueOrange),
        ],
        onCreated: (c) {
          _gmap = c;
          _moveCamera(_taxi, 16);
        },
        onUserMove: () {
          // Google Maps ne distingue pas les gestes : on ignore les déplacements faits par l'application.
          if (DateTime.now().difference(_programmaticMoveAt) < const Duration(milliseconds: 400)) return;
          if (_follow) setState(() => _follow = false);
        },
      );
    }
    return FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: _me,
        initialZoom: 16,
        onMapReady: () {
          _mapReady = true;
          _map.move(_taxi, 16);
        },
        onPositionChanged: (_, hasGesture) {
          if (hasGesture && _follow) setState(() => _follow = false);
        },
      ),
      children: [
        baseTiles(),
        if (_route.length > 1 && _pos < _route.length - 1)
          PolylineLayer(polylines: [routeLine(_route.sublist(_pos), color: const Color(0xFF1A73E8))]),
        MarkerLayer(markers: [
          for (final r in _shift.riders) stopMarker(_route[min(r.dropIdx, _route.length - 1)], destination: true),
          for (final r in pending) _riderPin(_route[r.pickupIdx], r.name, AppColors.moroccoGreen),
          if (req != null) _riderPin(_route[req.pickupIdx], req.name, const Color(0xFFF5B301)),
          if (_helpTarget case final h?)
            Marker(
              point: h.position,
              width: 46,
              height: 46,
              child: Container(
                key: const ValueKey('helpMarker'),
                decoration: BoxDecoration(
                  color: helpOrange,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.ink, width: 3),
                  boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8)],
                ),
                child: Icon(h.accident ? Icons.car_crash : Icons.car_repair, color: AppColors.ink),
              ),
            ),
          Marker(
            point: _taxi,
            width: 52,
            height: 52,
            child: Container(
              decoration: BoxDecoration(
                color: _online ? const Color(0xFF1A73E8) : AppColors.muted,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 10)],
              ),
              child: Transform.rotate(
                angle: _bearing(),
                child: const CustomPaint(painter: _ArrowPainter()),
              ),
            ),
          ),
        ]),
        mapAttribution(),
      ],
    );
  }

  Marker _riderPin(LatLng p, String name, Color color) => Marker(
        point: p,
        width: 44,
        height: 44,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
          ),
          child: Center(
            child: Text(name.substring(0, 1),
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          ),
        ),
      );

  // ---------------------------------------------------------------- Interface

  Widget _topBar() => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Row(children: [
            widget.driverApp
                ? MapCircleButton(icon: Icons.badge_outlined, onTap: _showProfile)
                : MapCircleButton(icon: Icons.arrow_back, onTap: () => Navigator.pop(context)),
            const SizedBox(width: 8),
            // Interrupteur en ligne / hors ligne
            Expanded(
              child: Center(
                child: GestureDetector(
                  onTap: _online ? _goOffline : _goOnline,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                    decoration: BoxDecoration(
                      color: _online ? AppColors.moroccoGreen : AppColors.ink,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Flexible(
                        child: Text(_online ? s.t('online') : s.t('offline'),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: Icon(Icons.power_settings_new,
                            size: 18, color: _online ? AppColors.moroccoGreen : AppColors.ink),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Builder(
              builder: (ctx) => MapCircleButton(
                icon: Icons.tune,
                tooltip: s.t('driverSettings'),
                onTap: () => Scaffold.of(ctx).openEndDrawer(),
              ),
            ),
            const SizedBox(width: 8),
            MapCircleButton(
              icon: _follow ? Icons.navigation : Icons.navigation_outlined,
              onTap: () {
                setState(() => _follow = true);
                _moveCamera(_taxi, 16);
              },
            ),
          ]),
        ),
      );

  /// Rappel discret des feux de détresse : bandeau compact sombre, pastille orange clignotante, OK.
  Widget _hazardBanner() => Semantics(
        liveRegion: true,
        container: true,
        label: s.t('hazardLights'),
        child: Container(
          key: const ValueKey('hazardBanner'),
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsetsDirectional.fromSTEB(10, 8, 6, 8),
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
          ),
          child: Row(children: [
            const _HazardBlink(),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(s.t('hazardLights'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                Text('${s.t('hazardNear')} · ${_hazardFor!.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, color: Colors.white70)),
              ]),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFFFB300),
                minimumSize: const Size(48, 40),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              onPressed: _hideHazard,
              child: const Text('OK'),
            ),
          ]),
        ),
      );

  Widget _earningsCard() => Semantics(
        button: true,
        label: s.t('myEarnings'),
        child: GestureDetector(
          onTap: _openEarnings,
          child: _earningsBar(),
        ),
      );

  Widget _earningsBar() => Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
        ),
        child: Row(children: [
          Expanded(child: _stat(dh(_shift.earningsToday), s.t('earned'))),
          _divider(),
          Expanded(child: _stat(dh(_shift.tipsToday), s.t('tipsReceived'))),
          _divider(),
          Expanded(child: _stat('${_shift.passengersToday}', s.t('passengersShort'))),
          _divider(),
          Expanded(child: _stat('${_shift.ridesToday}', s.t('ridesShort'))),
        ]),
      );

  Widget _divider() => Container(width: 1, height: 24, color: Colors.white24);

  Widget _stat(String value, String label) => Column(children: [
        Text(value,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, height: 1.2)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.2)),
      ]);

  /// Compteur des personnes à bord : une icône de siège par place.
  /// Compteur des personnes à bord, sur une seule ligne : chiffre, sièges, boutons + et −.
  Widget _seatCounter() {
    final onBoard = _shift.onBoard;
    final reserved = _shift.reserved;
    final full = _shift.isFull;
    return Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.t('onBoard'),
              style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
              child: Text('$onBoard',
                  key: ValueKey(onBoard), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, height: 1)),
            ),
            Text(' / ${_shift.capacity}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.muted)),
            const SizedBox(width: 8),
            Flexible(
              child: full
                  // Petit écran : le badge « complet » se raccourcit au lieu de déborder.
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: AppColors.taxiRed, borderRadius: BorderRadius.circular(8)),
                      child: Text(s.t('taxiFull'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                    )
                  : Wrap(spacing: 2, children: [
                      for (var i = 0; i < _shift.capacity; i++)
                        Icon(
                          Icons.event_seat,
                          size: 18,
                          color: i < onBoard
                              ? AppColors.moroccoGreen
                              : i < reserved
                                  ? const Color(0xFFF5B301)
                                  : const Color(0xFFD9D9D9),
                        ),
                    ]),
            ),
          ]),
        ]),
      ),
      // Boutons pour les passagers pris dans la rue, sans l'application.
      _roundBtn(Icons.remove, _shift.hailOnBoard == 0 ? null : () => setState(_shift.removeHail)),
      const SizedBox(width: 8),
      _roundBtn(
          Icons.add,
          _shift.isFull
              ? null
              : () => setState(() {
                    if (_shift.addHail()) {
                      _toast(Icons.person_add_alt_1, '${s.t('riderPickedUp')} · ${_shift.onBoard}/${_shift.capacity}');
                    }
                  }),
          filled: true),
    ]);
  }

  Widget _roundBtn(IconData icon, VoidCallback? onTap, {bool filled = false}) => SizedBox(
        width: 44,
        height: 44,
        child: IconButton.filled(
          style: IconButton.styleFrom(
            backgroundColor: filled ? AppColors.ink : const Color(0xFFF1F1F1),
            foregroundColor: filled ? Colors.white : AppColors.ink,
            disabledBackgroundColor: const Color(0xFFF5F5F5),
          ),
          iconSize: 24,
          onPressed: onTap,
          icon: Icon(icon),
        ),
      );

  Widget _stops() {
    final stops = _shift.nextStops().take(2).toList();
    if (stops.isEmpty) {
      return Row(children: [
        const Icon(Icons.radar, color: AppColors.muted, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(s.t('noStops'), style: const TextStyle(color: AppColors.muted, fontSize: 13))),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(s.t('nextStops'), style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
      for (final st in stops)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: st.pickup ? AppColors.moroccoGreen : AppColors.ink,
                shape: st.pickup ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: st.pickup ? null : BorderRadius.circular(7),
              ),
              child: Icon(st.pickup ? Icons.person_add_alt_1 : Icons.logout, color: Colors.white, size: 15),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  '${st.pickup ? s.t('pickUp') : s.t('dropAt')} ${st.rider.name}'
                  '${st.rider.seats > 1 ? ' (${st.rider.seats})' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                // Test réel : destination et prix au compteur annoncé au passager.
                if (st.rider.destination.isNotEmpty)
                  Text(
                    '→ ${st.rider.destination}${st.rider.fare > 0 ? ' · ${dhRange(st.rider.fare)}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: AppColors.muted, fontWeight: FontWeight.w600),
                  ),
              ]),
            ),
            Text(distanceText(_exactMetersTo(st.idx)), style: const TextStyle(fontWeight: FontWeight.w700)),
            if (identical(st, stops.first)) ...[
              const SizedBox(width: 8),
              Semantics(
                button: true,
                label: '${s.t('navigateTo')} ${st.rider.name}',
                excludeSemantics: true,
                child: Tooltip(
                  message: '${s.t('navigateTo')} ${st.rider.name}',
                  child: FilledButton(
                    key: const ValueKey('navigate'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1A73E8),
                      minimumSize: const Size(44, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    onPressed: () => _navigate(st),
                    child: const Icon(Icons.navigation, size: 20),
                  ),
                ),
              ),
            ],
          ]),
        ),
    ]);
  }

  // ---------------------------------------------------------------- Navigation

  String _stopLabel(({bool pickup, ShiftRider rider, int idx}) st) =>
      '${st.pickup ? s.t('pickUp') : s.t('dropAt')} ${st.rider.name}';

  /// Guidage vers l'arrêt : selon le réglage du chauffeur, ou en lui demandant.
  Future<void> _navigate(({bool pickup, ShiftRider rider, int idx}) st) async {
    var app = settings.navApp;
    if (app == NavApp.ask) {
      final picked = await _pickNavApp(st);
      if (picked == null || !mounted) return;
      app = picked;
    }
    if (app == NavApp.inApp) {
      setState(() {
        _guideRider = st.rider;
        _follow = true;
      });
      _moveCamera(_taxi, 17);
      return;
    }
    final result = await openNavigation(app, _route[min(st.idx, _route.length - 1)]);
    if (!mounted) return;
    if (result == NavOpenResult.store) _toast(Icons.download, '${navAppName(app)} : ${s.t('navNotInstalled')}');
    if (result == NavOpenResult.web) _toast(Icons.public, s.t('navWebFallback'));
    if (result == NavOpenResult.failed) _toast(Icons.error_outline, s.t('navFailed'));
  }

  /// Choix : rester dans l'application, ouvrir Waze, ou Google Maps ; « toujours » l'enregistre.
  Future<NavApp?> _pickNavApp(({bool pickup, ShiftRider rider, int idx}) st) {
    var remember = false;
    return showModalBottomSheet<NavApp>(
      context: context,
      backgroundColor: AppColors.sand,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          void pick(NavApp a) {
            if (remember) settings.navApp = a;
            Navigator.pop(ctx, a);
          }

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('${s.t('navigateTo')} : ${_stopLabel(st)}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 14),
                _navChoice(
                  key: const ValueKey('nav-inApp'),
                  badge: _navBadge('TM', AppColors.moroccoGreen),
                  title: s.t('navStayInApp'),
                  subtitle: s.t('navStayInAppDesc'),
                  onTap: () => pick(NavApp.inApp),
                ),
                _navChoice(
                  key: const ValueKey('nav-waze'),
                  badge: _navBadge('W', const Color(0xFF33CCFF)),
                  title: '${s.t('navOpenIn')} Waze',
                  onTap: () => pick(NavApp.waze),
                ),
                _navChoice(
                  key: const ValueKey('nav-google'),
                  badge: _navBadge('G', const Color(0xFF1A73E8)),
                  title: '${s.t('navOpenIn')} Google Maps',
                  small: true,
                  onTap: () => pick(NavApp.googleMaps),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: remember,
                  onChanged: (v) => setSheet(() => remember = v ?? false),
                  title: Text(s.t('navRemember')),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  /// Pastille dessinée (pas de logo de marque).
  Widget _navBadge(String text, Color color) => Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
      );

  Widget _navChoice({
    required Key key,
    required Widget badge,
    required String title,
    String? subtitle,
    bool small = false,
    required VoidCallback onTap,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            key: key,
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.all(small ? 10 : 14),
              child: Row(children: [
                badge,
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: TextStyle(fontSize: small ? 15 : 17, fontWeight: FontWeight.w800)),
                    if (subtitle != null) Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                  ]),
                ),
                const Icon(Icons.chevron_right, color: AppColors.muted),
              ]),
            ),
          ),
        ),
      );

  /// Bandeau du guidage dans l'application : prochain arrêt de ce passager et distance.
  Widget _guideBanner() {
    final st = _shift.nextStops().where((x) => identical(x.rider, _guideRider)).firstOrNull;
    if (st == null) return const SizedBox.shrink();
    return Container(
      key: const ValueKey('guideBanner'),
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A73E8),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
      ),
      child: Row(children: [
        const Icon(Icons.navigation, color: Colors.white, size: 30),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${s.t('navGuiding')} : ${_stopLabel(st)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
            Text(distanceText(_exactMetersTo(st.idx)),
                style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
          ]),
        ),
        IconButton(
          tooltip: s.t('close'),
          onPressed: () => setState(() => _guideRider = null),
          icon: const Icon(Icons.close, color: Colors.white),
        ),
      ]),
    );
  }

  /// Demande de course compacte : qui, combien, où, puis Refuser / Accepter. La carte reste visible.
  Widget _requestCard() {
    final r = _request!;
    final left = _requestSeconds - DateTime.now().difference(r.shownAt).inMilliseconds / 1000;
    final seats = '${r.rider.seats} ${r.rider.seats > 1 ? s.t('seats') : s.t('seat')}';
    Widget chip(IconData icon, String text, Color bg, Color fg, {String? hint}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: fg, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 13)),
                if (hint != null) Text(hint, style: TextStyle(color: fg, fontSize: 12)),
              ]),
            ),
          ]),
        );
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 14)],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          LinearProgressIndicator(
            value: (left / _requestSeconds).clamp(0, 1),
            minHeight: 4,
            color: const Color(0xFFF5B301),
            backgroundColor: AppColors.line,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFF5B301),
                  child: Text(r.rider.name.substring(0, 1),
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Flexible(
                        child: Text(r.rider.name,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.star, size: 14, color: Color(0xFFF5B301)),
                      Text(r.rating.toStringAsFixed(1), style: const TextStyle(fontSize: 13)),
                    ]),
                    Text('${distanceText(_exactMetersTo(r.rider.pickupIdx))} ${s.t('pickupAhead')}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.moroccoGreen, fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ]),
                ),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(dhRange(r.rider.fare),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, height: 1.1)),
                  Text(seats,
                      style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.flag, color: AppColors.ink, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(r.destination,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ]),
              if (r.bookedBy != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('${s.t('bookedBy')} ${r.bookedBy} ${s.t('forPerson')} ${r.rider.name}',
                      style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              if (r.lowVision || r.babySeat)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(spacing: 6, runSpacing: 6, children: [
                    if (r.lowVision)
                      Semantics(
                        container: true,
                        child: chip(Icons.visibility_off, s.t('lowVisionBadge'), AppColors.ink, Colors.white,
                            hint: s.t('lowVisionHint')),
                      ),
                    if (r.babySeat)
                      chip(Icons.child_friendly, s.t('babySeatRequested'), AppColors.greenSoft, AppColors.moroccoGreen),
                  ]),
                ),
              const SizedBox(height: 10),
              if (r.takenAt != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFFBEAEA), borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    const Icon(Icons.lock, color: AppColors.taxiRed, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(s.t('takenByOther'),
                          style: const TextStyle(color: AppColors.taxiRed, fontWeight: FontWeight.w800)),
                    ),
                  ]),
                )
              else
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                      onPressed: _decline,
                      child: Text(s.t('decline')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.moroccoGreen, minimumSize: const Size(0, 44)),
                      onPressed: _accept,
                      child: Text(s.t('accept'), style: const TextStyle(fontSize: 17)),
                    ),
                  ),
                ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _offlinePanel() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _weekGainsChip(),
        const SizedBox(height: 12),
        Text(s.t('chooseTaxiType'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Row(children: [
          for (final k in [TaxiKind.petit, TaxiKind.grand]) ...[
            Expanded(
                child: Semantics(
              button: true,
              selected: _kind == k,
              child: GestureDetector(
                onTap: () => setState(() => _kind = k),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _kind == k ? AppColors.ink : AppColors.line, width: _kind == k ? 2 : 1.5),
                  ),
                  child: Column(children: [
                    Container(
                      width: 52,
                      height: 38,
                      decoration: BoxDecoration(color: taxiColor(k), borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.local_taxi, color: k == TaxiKind.grand ? AppColors.ink : Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                        switch (k) {
                          TaxiKind.grand => s.t('grandTaxi'),
                          _ => s.t('petitTaxi'),
                        },
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('${k == TaxiKind.grand ? 6 : 3} ${s.t('seats')}',
                        style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                  ]),
                ),
              ),
            )),
            if (k != TaxiKind.grand) const SizedBox(width: 8),
          ],
        ]),
        const SizedBox(height: 14),
        _myDestPicker(),
        const SizedBox(height: 14),
        FilledButton.icon(
          style:
              FilledButton.styleFrom(backgroundColor: AppColors.moroccoGreen, minimumSize: const Size.fromHeight(60)),
          onPressed: _goOnline,
          icon: const Icon(Icons.power_settings_new),
          label: Text(s.t('goOnline'), style: const TextStyle(fontSize: 18)),
        ),
      ]);

  /// Hors service : ce que Bab Taxi a rapporté en plus cette semaine, pour donner envie de continuer.
  Widget _weekGainsChip() {
    final week =
        driverEarnings.weeks(DateTime.now(), todayRides: _shift.earningsToday, todayTips: _shift.tipsToday).last;
    return Semantics(
      button: true,
      child: Material(
        color: AppColors.greenSoft,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _openEarnings,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              const Icon(Icons.trending_up, color: AppColors.moroccoGreen),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: '+${dh(week.extraTotal)} ',
                        style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.moroccoGreen)),
                    TextSpan(text: s.t('earnWeekChip')),
                  ]),
                  style: const TextStyle(fontSize: 15),
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.moroccoGreen),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _searchMyDest() async {
    final place = await Navigator.push<Place>(context, MaterialPageRoute(builder: (_) => SearchScreen(near: _me)));
    if (place != null && mounted) {
      setState(() {
        _myDest = place;
        _areaDest = false;
      });
    }
  }

  /// Hors ligne : « Ma destination » (facultatif). Avec une destination, seulement les passagers sur le trajet.
  Widget _myDestPicker() {
    final dest = _myDest;
    if (dest != null) return _myDestBanner();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.alt_route, color: AppColors.moroccoGreen),
          const SizedBox(width: 10),
          Expanded(child: Text(s.t('driverDest'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
        ]),
        const SizedBox(height: 4),
        Text(s.t('driverDestDesc'), style: const TextStyle(color: AppColors.muted)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              key: const ValueKey('myDestHome'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
              onPressed: () => setState(() {
                _myDest = homePlace;
                _areaDest = false;
              }),
              icon: const Icon(Icons.home_rounded),
              label: Text(s.t('goingHome'), overflow: TextOverflow.ellipsis),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              key: const ValueKey('myDestSearch'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
              onPressed: _searchMyDest,
              icon: const Icon(Icons.search),
              label: Text(s.t('otherDest'), overflow: TextOverflow.ellipsis),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _myDestBanner() => Container(
        key: const ValueKey('myDestBanner'),
        padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 4, 10),
        decoration: BoxDecoration(
          color: AppColors.moroccoGreen.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.moroccoGreen),
        ),
        child: Row(children: [
          const Icon(Icons.alt_route, color: AppColors.moroccoGreen),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${s.t('towards')} ${_myDest!.name}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              Text(s.t('onMyRouteOnly'), style: const TextStyle(color: AppColors.muted)),
            ]),
          ),
          if (_online && _areaDest)
            IconButton(
              key: const ValueKey('sayAreaAgain'),
              tooltip: s.t('changeArea'),
              onPressed: _openAreaSheet,
              icon: const Icon(Icons.mic, color: AppColors.moroccoGreen),
            ),
          IconButton(
            key: const ValueKey('myDestClear'),
            tooltip: s.t('clearDest'),
            onPressed: () {
              setState(() {
                _myDest = null;
                _areaDest = false;
              });
              // En service : le trajet en cours continue, la suite redevient libre.
            },
            icon: const Icon(Icons.close),
          ),
        ]),
      );

  // ---------------------------------------------------------------- Quartier dit à voix haute

  /// « Dire mon quartier » : le chauffeur (même avec des passagers pris dans la rue) dit où il va ;
  /// le quartier reconnu devient sa destination et seuls les passagers sur la route lui sont proposés.
  Future<void> _openAreaSheet() async {
    final place = await showModalBottomSheet<Place>(
      context: context,
      backgroundColor: AppColors.sand,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _AreaSheet(voice: _voice),
    );
    if (place != null && mounted) await _setArea(place);
  }

  Future<void> _setArea(Place area) async {
    setState(() {
      _myDest = area;
      _areaDest = true;
    });
    // Confirmation à voix haute, en arabe pour l'arabe et la darija.
    final name = s.lang == 'ar' || s.lang == 'dr' ? area.arabicName : area.name;
    _voice.say('${s.t('areaHeadingTo')} $name. ${s.t('onMyRouteOnly')}').ignore();
    _toast(Icons.alt_route, '${s.t('areaHeadingTo')} ${area.name} · ${s.t('onMyRouteOnly')}');
    await _routeToMyDest();
  }

  /// En service : la route continue jusqu'au dernier passager à déposer, puis va vers la destination.
  /// Les demandes (même mécanisme que « Ma destination ») ne viennent alors que de cette route.
  Future<void> _routeToMyDest() async {
    final dest = _myDest;
    if (!_online || dest == null) return;
    // Demande en attente sur l'ancienne route : elle n'est plus sur le trajet.
    if (_request != null) _decline();
    final keep = _route.isEmpty ? 0 : _shift.riders.fold<int>(_pos, (m, r) => max(m, r.dropIdx));
    final from = _route.isEmpty ? _taxi : _route[min(keep, _route.length - 1)];
    final to = LatLng(dest.lat, dest.lng);
    var tail = await fetchRoute(from, to);
    if (tail.length < 20) tail = interpolate(from, to, 80);
    if (!mounted || !_online || _myDest != dest) return;
    setState(() {
      _heading = dest;
      _previewRoute = false;
      if (_route.isEmpty) {
        _route = tail;
        _pos = 0;
        _carry = 0;
      } else {
        _route = [..._route.sublist(0, min(keep, _route.length - 1) + 1), ...tail.skip(1)];
      }
    });
    if (_liveOn) _publish();
  }

  /// Bouton bien visible en service : dire (ou toucher) le quartier vers lequel il va.
  Widget _sayAreaButton() => FilledButton.icon(
        key: const ValueKey('sayArea'),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.ink,
          minimumSize: const Size.fromHeight(50),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: _openAreaSheet,
        icon: const Icon(Icons.mic, size: 26),
        label: Row(children: [
          Text(s.t('sayMyArea'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(s.t('sayMyAreaDesc'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ),
        ]),
      );

  Widget _onlinePanel() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_myDest != null) ...[
          _myDestBanner(),
          const Divider(height: 14, color: AppColors.line)
        ] else ...[
          _sayAreaButton(),
          const SizedBox(height: 10)
        ],
        _seatCounter(),
        const Divider(height: 14, color: AppColors.line),
        _stops(),
        const SizedBox(height: 8),
        _helpButton(),
      ]);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      endDrawer: Drawer(
        backgroundColor: AppColors.sand,
        child: SafeArea(
          child: ListView(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(s.t('driverSettings'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            ),
            ListenableBuilder(
              listenable: settings,
              builder: (_, __) => SwitchListTile(
                secondary: const Icon(Icons.notifications_active_outlined),
                title: Text(s.t('requestSound')),
                subtitle: Text(s.t('requestSoundDesc'), style: const TextStyle(color: AppColors.muted)),
                value: settings.requestSound,
                onChanged: (v) => settings.requestSound = v,
              ),
            ),
            ListenableBuilder(
              listenable: settings,
              builder: (_, __) => SwitchListTile(
                secondary: const Icon(Icons.record_voice_over_outlined),
                title: Text(s.t('requestVoice')),
                subtitle: Text(s.t('requestVoiceDesc'), style: const TextStyle(color: AppColors.muted)),
                value: settings.requestVoice,
                onChanged: (v) => settings.requestVoice = v,
              ),
            ),
            const Divider(),
            const Divider(),
            // Ce que Bab Taxi rapporte en plus, comparé à avant.
            ListTile(
              key: const ValueKey('myEarnings'),
              leading: const Icon(Icons.trending_up, color: AppColors.moroccoGreen),
              title: Text(s.t('myEarnings'), style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(s.t('myEarningsDesc'), style: const TextStyle(color: AppColors.muted)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _openEarnings,
            ),
            // Critères, contrôles et gains du badge Premium.
            ListTile(
              key: const ValueKey('becomePremium'),
              leading: const Icon(Icons.workspace_premium_outlined, color: AppColors.gold),
              title: Text(s.t('becomePremium'), style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(s.t('becomePremiumDesc'), style: const TextStyle(color: AppColors.muted)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumDriverScreen())),
            ),
            const Divider(),
            ListTile(
              key: const ValueKey('mapEngine'),
              leading: const Icon(Icons.map_outlined),
              title: Text(s.t('mapLabel')),
              trailing: Text(useGoogleMaps ? 'Google Maps' : 'OpenStreetMap',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(s.t('navSetting'), style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            ListenableBuilder(
              listenable: settings,
              builder: (_, __) => RadioGroup<NavApp>(
                groupValue: settings.navApp,
                onChanged: (v) => settings.navApp = v ?? NavApp.ask,
                child: Column(children: [
                  for (final a in NavApp.values)
                    RadioListTile<NavApp>(
                      value: a,
                      title: Text(switch (a) {
                        NavApp.ask => s.t('navAsk'),
                        NavApp.inApp => s.t('navStayInApp'),
                        _ => '${s.t('navOpenIn')} ${navAppName(a)}',
                      }),
                    ),
                ]),
              ),
            ),
            const Divider(),
            // Panne ou accident : appeler les taxis Bab Taxi proches.
            ListTile(
              key: const ValueKey('helpDrawer'),
              leading: const Icon(Icons.car_crash_outlined, color: AppColors.taxiRed),
              title: Text(s.t('helpButton'), style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(s.t('helpButtonDesc'), style: const TextStyle(color: AppColors.muted)),
              onTap: () {
                Navigator.pop(context);
                _askForHelp();
              },
            ),
            if (!live.enabled)
              ListTile(
                key: const ValueKey('helpDemoIncoming'),
                leading: const Icon(Icons.campaign_outlined, color: Color(0xFFB37800)),
                title: Text(s.t('helpDemoIncoming')),
                onTap: () {
                  Navigator.pop(context);
                  _demoIncomingHelp();
                },
              ),
          ]),
        ),
      ),
      body: Stack(children: [
        Positioned.fill(child: _buildMap()),
        Column(children: [
          _topBar(),
          if (_online && _hazardFor == null) _earningsCard(),
          if (_online && _guideRider != null) _guideBanner(),
          if (_hazardFor != null) _hazardBanner(),
          if (_helping case final h?)
            HelpGoingBanner(
              alert: h,
              distanceM: _helpDistanceM(h),
              onRoute: () => _routeToHelp(h),
              onCancel: _cancelHelping,
            ),
        ]),
        Align(
          alignment: Alignment.bottomCenter,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Une demande remplace le panneau le temps de la réponse : la carte reste visible au maximum.
            // « Démarrer la course » reste visible, même quand une nouvelle demande arrive.
            if (_online) ..._readyToStart.map(_startRideCard),
            if (_myHelp case final h?)
              Flexible(child: SingleChildScrollView(child: HelpCallCard(alert: h, onSolved: _solveHelp)))
            else if (_incomingHelp case final h?)
              Flexible(
                child: SingleChildScrollView(
                  child: HelpAlertCard(
                    alert: h,
                    canTakeRiders: h.riders > 0 && _shift.freeSeats >= h.riders,
                    onGo: _helpGo,
                    onTake: _helpTake,
                    onDismiss: _helpDismiss,
                  ),
                ),
              )
            else if (_request != null)
              _requestCard()
            else
              Flexible(child: BottomPanel(child: _online ? _onlinePanel() : _offlinePanel())),
          ]),
        ),
      ]),
    );
  }
}

/// Flèche de navigation dessinée pointe vers le haut ; elle est tournée dans le sens de la route.
class _ArrowPainter extends CustomPainter {
  const _ArrowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final path = ui.Path()
      ..moveTo(w * .5, h * .2)
      ..lineTo(w * .76, h * .78)
      ..lineTo(w * .5, h * .64)
      ..lineTo(w * .24, h * .78)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Pastille orange des feux de détresse, qui clignote doucement comme les vrais feux.
class _HazardBlink extends StatefulWidget {
  const _HazardBlink();

  @override
  State<_HazardBlink> createState() => _HazardBlinkState();
}

class _HazardBlinkState extends State<_HazardBlink> with SingleTickerProviderStateMixin {
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
          width: 36,
          height: 36,
          decoration: const BoxDecoration(color: Color(0xFFFFB300), shape: BoxShape.circle),
          child: const Icon(Icons.warning_rounded, size: 22, color: AppColors.ink),
        ),
      );
}

/// « Je vais vers… » : le chauffeur dit le quartier, l'application le répète puis le choisit.
/// Sans micro (navigateur, permission refusée), il touche le quartier dans la liste.
class _AreaSheet extends StatefulWidget {
  const _AreaSheet({required this.voice});
  final Voice voice;

  @override
  State<_AreaSheet> createState() => _AreaSheetState();
}

class _AreaSheetState extends State<_AreaSheet> {
  bool _listening = false;
  String _heard = '';
  String? _status;
  Place? _found;
  Timer? _silence;

  @override
  void initState() {
    super.initState();
    // Un seul geste en conduisant : l'écoute commence tout de suite.
    WidgetsBinding.instance.addPostFrameCallback((_) => _listen());
  }

  @override
  void dispose() {
    _silence?.cancel();
    if (_listening) widget.voice.stop().ignore();
    super.dispose();
  }

  /// Lecture à voix haute sans bloquer l'écran si la synthèse vocale ne répond pas.
  Future<void> _say(String text) => widget.voice.say(text).timeout(const Duration(seconds: 4), onTimeout: () {});

  Future<void> _listen() async {
    if (_listening) {
      await widget.voice.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    if (!await widget.voice.init()) {
      if (mounted) setState(() => _status = s.t('micDenied'));
      return;
    }
    await _say(s.t('speakArea'));
    if (!mounted) return;
    setState(() {
      _listening = true;
      _heard = '';
      _found = null;
      _status = s.t('listening');
    });
    // Rien entendu : on arrête et on propose la liste.
    _silence?.cancel();
    _silence = Timer(const Duration(seconds: 10), () {
      if (!mounted || !_listening || _heard.isNotEmpty) return;
      widget.voice.stop().ignore();
      setState(() {
        _listening = false;
        _status = s.t('areaNotFound');
      });
    });
    try {
      await widget.voice.listen(onResult: (words, done) {
        if (!mounted) return;
        setState(() => _heard = words);
        if (done) _onHeard(words);
      });
    } catch (_) {
      if (mounted) setState(() => _listening = false);
    }
  }

  Future<void> _onHeard(String words) async {
    _silence?.cancel();
    setState(() => _listening = false);
    final area = findQuartier(words);
    if (area == null) {
      setState(() => _status = words.trim().isEmpty ? s.t('areaNotFound') : '« $words » : ${s.t('areaNotFound')}');
      await _say(s.t('areaNotFound'));
      return;
    }
    // Répète ce qui a été compris avant de le choisir (comme la commande vocale du passager).
    setState(() {
      _found = area;
      _status = '${s.t('youSaid')} : « $words »';
    });
    await _say('${s.t('youSaid')} : ${s.lang == 'ar' || s.lang == 'dr' ? area.arabicName : area.name}');
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (mounted) Navigator.pop(context, area);
  }

  @override
  Widget build(BuildContext context) {
    final found = _found;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .8),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(s.t('areaTitle'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            Text(s.t('onMyRouteOnly'), style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 14),
            Row(children: [
              SizedBox(
                width: 68,
                height: 68,
                child: IconButton.filled(
                  key: const ValueKey('areaMic'),
                  tooltip: s.t('sayMyArea'),
                  style: IconButton.styleFrom(
                    backgroundColor: _listening ? AppColors.taxiRed : AppColors.moroccoGreen,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _listen,
                  icon: Icon(_listening ? Icons.graphic_eq : Icons.mic, size: 36),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (found != null)
                      Text('${s.t('areaHeadingTo')} ${found.name}',
                          key: const ValueKey('areaFound'),
                          style:
                              const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.moroccoGreen))
                    else
                      Text(
                        _listening && _heard.isNotEmpty ? '« $_heard »' : _status ?? s.t('speakArea'),
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                    if (found != null && _status != null)
                      Text(_status!, style: const TextStyle(color: AppColors.muted)),
                  ]),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            Text(s.t('chooseArea'), style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final q in casablancaQuartiers)
                ActionChip(
                  key: ValueKey('area-${q.name}'),
                  avatar: const Icon(Icons.place_outlined, size: 18),
                  label: Text(q.name),
                  backgroundColor: identical(q, found) ? AppColors.greenSoft : Colors.white,
                  onPressed: () {
                    _silence?.cancel();
                    if (_listening) widget.voice.stop().ignore();
                    _listening = false;
                    Navigator.pop(context, q);
                  },
                ),
            ]),
          ]),
        ),
      ),
    );
  }
}
