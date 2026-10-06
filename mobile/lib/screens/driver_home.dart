import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:latlong2/latlong.dart';

import 'search_screen.dart';
import '../main.dart';
import '../services/demo.dart';
import '../services/driver_shift.dart';
import '../services/location.dart';
import '../services/navigation_apps.dart';
import '../services/places.dart';
import '../services/rides.dart';
import '../services/routing.dart';
import '../services/driver_notifications.dart';
import '../services/request_chime.dart';
import '../services/settings.dart';
import '../theme.dart';
import '../widgets/google_taxi_map.dart';
import '../widgets/map_parts.dart';

/// Demande d'un passager qui se trouve sur la route du chauffeur.
class _Request {
  _Request(this.rider, this.destination, this.rating,
      {this.takenAfter, this.lowVision = false, this.bookedBy, this.babySeat = false});
  final ShiftRider rider;
  final String destination;
  final double rating;

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
  const DriverHome({super.key});

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
  TaxiKind _kind = TaxiKind.petit;
  LatLng _me = casablancaCenter;
  Place? _heading;

  /// Destination du chauffeur (ex. : il rentre chez lui). Il ne reçoit alors que les passagers
  /// pris et déposés sur son trajet, avant sa destination ; arrivé, il passe hors ligne.
  Place? _myDest;
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
    currentLatLng().then((p) {
      if (!mounted) return;
      setState(() => _me = p);
      _moveCamera(p, 16);
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _hazardTimer?.cancel();
    _chime.cancel();
    if (_notifications.onAction == _onNotificationAction) _notifications.onAction = null;
    _notifications.cancel(DriverNotifications.requestId);
    super.dispose();
  }

  LatLng get _taxi => _route.isEmpty ? _me : _route[_pos];

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
    setState(() => _online = true);
    await _newRoute();
    _lastRequest = DateTime.now().subtract(const Duration(seconds: 4));
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(milliseconds: 100), (_) => _onTick());
  }

  void _goOffline() {
    _tick?.cancel();
    setState(() {
      _online = false;
      _request = null;
      _route = [];
      _shift.riders.clear();
      _shift.hailOnBoard = 0;
    });
  }

  void _onTick() {
    if (!mounted || _route.length < 2) return;
    // Avancer le taxi d'une distance fixe le long de la route.
    // Le taxi ralentit en approchant d'un passager à prendre (démo : environ 5 s pour les 50 derniers mètres).
    final nextPickup = _shift.riders
        .where((r) => !r.onBoard)
        .map((r) => _exactMetersTo(r.pickupIdx))
        .fold<double?>(null, (m, v) => m == null || v < m ? v : m);
    _carry += nextPickup != null && nextPickup <= 60 ? 1.0 : _metersPerTick;
    const d = Distance();
    var moved = false;
    while (_pos < _route.length - 1) {
      final seg = d(_route[_pos], _route[_pos + 1]);
      if (_carry < seg) break;
      _carry -= seg;
      _pos++;
      moved = true;
    }
    if (moved) {
      // Démo : une Dacia Spring consomme environ 1 % tous les 2 km.
      final events = _shift.advance(_pos);
      if (_hazardFor != null && events.pickedUp.contains(_hazardFor)) _hideHazard();
      for (final r in events.pickedUp) {
        _toast(Icons.person_add_alt_1, '${s.t('riderPickedUp')} : ${r.name} · ${_shift.onBoard}/${_shift.capacity}');
      }
      for (final r in events.dropped) {
        _toast(Icons.check_circle, '${s.t('riderDropped')} : ${r.name} · +${dh(r.fare)}');
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
      if (_myDest != null) {
        // Arrivé chez lui : fin du service, plus de demandes.
        _toast(Icons.flag_rounded, '${s.t('driverDestReached')} : ${_myDest!.name}');
        _myDest = null;
        _goOffline();
        return;
      }
      _newRoute();
    }
    setState(() {});
  }

  void _maybeNewRequest() {
    if (_request != null || _shift.isFull) return;
    if (DateTime.now().difference(_lastRequest).inSeconds < 7) return;
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
          // Démo : un passager sur deux laisse un pourboire par carte.
          tip: _rnd.nextBool() ? const [5.0, 10.0, 20.0][_rnd.nextInt(3)] : 0),
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
      title: '${s.t('newRequest')} · ${dh(r.rider.fare)}',
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
    _chime.cancel();
    setState(() {
      _shift.accept(r.rider);
      _request = null;
    });
  }

  void _decline() {
    _chime.cancel();
    setState(() => _request = null);
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
                gm.BitmapDescriptor.hueRed),
          for (final r in pending)
            GooglePin(
                'pick-${r.name}', _route[r.pickupIdx], '${s.t('pickUp')} ${r.name}', gm.BitmapDescriptor.hueGreen),
          if (req != null) GooglePin('req-${req.name}', _route[req.pickupIdx], req.name, gm.BitmapDescriptor.hueYellow),
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
            MapCircleButton(icon: Icons.arrow_back, onTap: () => Navigator.pop(context)),
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

  /// Grand rappel lisible d'un coup d'œil : triangle de danger, texte en gros, bouton OK.
  Widget _hazardBanner() => Semantics(
        liveRegion: true,
        container: true,
        label: s.t('hazardLights'),
        child: Container(
          key: const ValueKey('hazardBanner'),
          margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFB300),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.taxiRed, width: 4),
            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 14)],
          ),
          child: Row(children: [
            const Icon(Icons.warning_rounded, size: 64, color: AppColors.taxiRed),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(s.t('hazardLights'),
                    style:
                        const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.ink, height: 1.1)),
                const SizedBox(height: 4),
                Text('${s.t('hazardNear')} · ${_hazardFor!.name}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink)),
              ]),
            ),
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.ink,
                minimumSize: const Size(72, 64),
                textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              onPressed: _hideHazard,
              child: const Text('OK'),
            ),
          ]),
        ),
      );

  Widget _earningsCard() => Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(18),
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

  Widget _divider() => Container(width: 1, height: 30, color: Colors.white24);

  Widget _stat(String value, String label) => Column(children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ]);

  /// Compteur des personnes à bord : une icône de siège par place.
  Widget _seatCounter() {
    final onBoard = _shift.onBoard;
    final reserved = _shift.reserved;
    final full = _shift.isFull;
    return Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.t('onBoard'), style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
              child: Text('$onBoard',
                  key: ValueKey(onBoard), style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900, height: 1)),
            ),
            Text(' / ${_shift.capacity}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.muted)),
            if (full) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.taxiRed, borderRadius: BorderRadius.circular(8)),
                child: Text(s.t('taxiFull'),
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 4, children: [
            for (var i = 0; i < _shift.capacity; i++)
              Icon(
                Icons.event_seat,
                size: 26,
                color: i < onBoard
                    ? AppColors.moroccoGreen
                    : i < reserved
                        ? const Color(0xFFF5B301)
                        : const Color(0xFFD9D9D9),
              ),
          ]),
        ]),
      ),
      // Boutons pour les passagers pris dans la rue, sans l'application.
      Column(children: [
        _roundBtn(
            Icons.add,
            _shift.isFull
                ? null
                : () => setState(() {
                      if (_shift.addHail()) {
                        _toast(
                            Icons.person_add_alt_1, '${s.t('riderPickedUp')} · ${_shift.onBoard}/${_shift.capacity}');
                      }
                    }),
            filled: true),
        const SizedBox(height: 8),
        _roundBtn(Icons.remove, _shift.hailOnBoard == 0 ? null : () => setState(_shift.removeHail)),
      ]),
    ]);
  }

  Widget _roundBtn(IconData icon, VoidCallback? onTap, {bool filled = false}) => SizedBox(
        width: 52,
        height: 52,
        child: IconButton.filled(
          style: IconButton.styleFrom(
            backgroundColor: filled ? AppColors.ink : const Color(0xFFF1F1F1),
            foregroundColor: filled ? Colors.white : AppColors.ink,
            disabledBackgroundColor: const Color(0xFFF5F5F5),
          ),
          iconSize: 28,
          onPressed: onTap,
          icon: Icon(icon),
        ),
      );

  Widget _stops() {
    final stops = _shift.nextStops().take(3).toList();
    if (stops.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(children: [
          const Icon(Icons.radar, color: AppColors.muted),
          const SizedBox(width: 10),
          Expanded(child: Text(s.t('noStops'), style: const TextStyle(color: AppColors.muted))),
        ]),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(s.t('nextStops'), style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      for (final st in stops)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: st.pickup ? AppColors.moroccoGreen : AppColors.ink,
                shape: st.pickup ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: st.pickup ? null : BorderRadius.circular(8),
              ),
              child: Icon(st.pickup ? Icons.person_add_alt_1 : Icons.logout, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${st.pickup ? s.t('pickUp') : s.t('dropAt')} ${st.rider.name}'
                '${st.rider.seats > 1 ? ' (${st.rider.seats})' : ''}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            Text(distanceText(_exactMetersTo(st.idx)), style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
        ),
      const SizedBox(height: 6),
      OutlinedButton.icon(
        key: const ValueKey('navigate'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF1A73E8),
          side: const BorderSide(color: Color(0xFF1A73E8), width: 1.5),
        ),
        onPressed: () => _navigate(stops.first),
        icon: const Icon(Icons.navigation),
        label: Text('${s.t('navigateTo')} ${stops.first.rider.name}', overflow: TextOverflow.ellipsis),
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

  Widget _requestCard() {
    final r = _request!;
    final left = _requestSeconds - DateTime.now().difference(r.shownAt).inMilliseconds / 1000;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 18)],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        LinearProgressIndicator(
          value: (left / _requestSeconds).clamp(0, 1),
          minHeight: 5,
          color: const Color(0xFFF5B301),
          backgroundColor: AppColors.line,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFF5B301),
                child: Text(r.rider.name.substring(0, 1),
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.t('newRequest'), style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                  Row(children: [
                    Flexible(
                      child: Text(r.rider.name,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.star, size: 16, color: Color(0xFFF5B301)),
                    Text(r.rating.toStringAsFixed(1)),
                  ]),
                ]),
              ),
              Text(dh(r.rider.fare), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            ]),
            if (r.bookedBy != null) ...[
              const SizedBox(height: 6),
              Text('${s.t('bookedBy')} ${r.bookedBy} ${s.t('forPerson')} ${r.rider.name}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
            if (r.lowVision) ...[
              const SizedBox(height: 10),
              Semantics(
                container: true,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    const Icon(Icons.visibility_off, color: Colors.white),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s.t('lowVisionBadge'),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                        Text(s.t('lowVisionHint'), style: const TextStyle(color: Colors.white, fontSize: 13)),
                      ]),
                    ),
                  ]),
                ),
              ),
            ],
            if (r.babySeat) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: AppColors.greenSoft, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(Icons.child_friendly, color: AppColors.moroccoGreen),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(s.t('babySeatRequested'),
                        style:
                            const TextStyle(color: AppColors.moroccoGreen, fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: 12),
            _infoLine(Icons.person_pin_circle, AppColors.moroccoGreen,
                '${distanceText(_exactMetersTo(r.rider.pickupIdx))} ${s.t('pickupAhead')}'),
            const SizedBox(height: 6),
            _infoLine(Icons.flag, AppColors.ink, r.destination),
            const SizedBox(height: 6),
            _infoLine(Icons.event_seat, AppColors.muted,
                '${r.rider.seats} ${r.rider.seats > 1 ? s.t('seats') : s.t('seat')}'),
            const SizedBox(height: 14),
            if (r.takenAt != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFFFBEAEA), borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(Icons.lock, color: AppColors.taxiRed),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(s.t('takenByOther'),
                        style: const TextStyle(color: AppColors.taxiRed, fontWeight: FontWeight.w800)),
                  ),
                ]),
              )
            else
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: _decline, child: Text(s.t('decline')))),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.moroccoGreen),
                    onPressed: _accept,
                    child: Text(s.t('accept'), style: const TextStyle(fontSize: 18)),
                  ),
                ),
              ]),
          ]),
        ),
      ]),
    );
  }

  Widget _infoLine(IconData icon, Color color, String text) => Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
      ]);

  Widget _offlinePanel() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
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

  Future<void> _searchMyDest() async {
    final place = await Navigator.push<Place>(context, MaterialPageRoute(builder: (_) => const SearchScreen()));
    if (place != null && mounted) setState(() => _myDest = place);
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
              onPressed: () => setState(() => _myDest = homePlace),
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
          IconButton(
            key: const ValueKey('myDestClear'),
            tooltip: s.t('clearDest'),
            onPressed: () {
              setState(() => _myDest = null);
              // En service : le trajet en cours continue, la suite redevient libre.
            },
            icon: const Icon(Icons.close),
          ),
        ]),
      );

  Widget _onlinePanel() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_myDest != null) ...[_myDestBanner(), const Divider(height: 20, color: AppColors.line)],
        _seatCounter(),
        const Divider(height: 26, color: AppColors.line),
        _stops(),
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
          ]),
        ),
      ),
      body: Stack(children: [
        Positioned.fill(child: _buildMap()),
        Column(children: [
          _topBar(),
          if (_online) _earningsCard(),
          if (_online && _guideRider != null) _guideBanner(),
          if (_hazardFor != null) _hazardBanner(),
        ]),
        Align(
          alignment: Alignment.bottomCenter,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (_request != null) _requestCard(),
            BottomPanel(child: _online ? _onlinePanel() : _offlinePanel()),
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
