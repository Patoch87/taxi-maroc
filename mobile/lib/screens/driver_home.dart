import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../main.dart';
import '../services/demo.dart';
import '../services/driver_shift.dart';
import '../services/location.dart';
import '../services/places.dart';
import '../services/rides.dart';
import '../services/routing.dart';
import '../theme.dart';
import '../widgets/map_parts.dart';

/// Demande d'un passager qui se trouve sur la route du chauffeur.
class _Request {
  _Request(this.rider, this.destination, this.rating, {this.takenAfter});
  final ShiftRider rider;
  final String destination;
  final double rating;
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

  bool _online = false;
  TaxiKind _kind = TaxiKind.petit;
  LatLng _me = casablancaCenter;
  Place? _heading;
  List<LatLng> _route = [];
  int _pos = 0;
  double _carry = 0;
  Timer? _tick;
  _Request? _request;
  DateTime _lastRequest = DateTime.now();

  @override
  void initState() {
    super.initState();
    currentLatLng().then((p) {
      if (!mounted) return;
      setState(() => _me = p);
      if (_mapReady) _map.move(p, 16);
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
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

  double _metersTo(int idx) => idx <= _pos ? 0 : routeLengthM(_route.sublist(_pos, idx + 1));

  // ---------------------------------------------------------------- Simulation

  bool _routing = false;

  Future<void> _newRoute() async {
    if (_routing) return;
    _routing = true;
    const d = Distance();
    final from = _taxi;
    final far = casablancaPlaces.where((p) => !p.intercity && d(from, LatLng(p.lat, p.lng)) > 2500).toList();
    final dest =
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
    _carry += _metersPerTick;
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
      final events = _shift.advance(_pos);
      for (final r in events.pickedUp) {
        _toast(Icons.person_add_alt_1, '${s.t('riderPickedUp')} : ${r.name} · ${_shift.onBoard}/${_shift.capacity}');
      }
      for (final r in events.dropped) {
        _toast(Icons.check_circle, '${s.t('riderDropped')} : ${r.name} · +${dh(r.fare)}');
      }
      if (_follow && _mapReady) _map.move(_taxi, _map.camera.zoom, offset: _followOffset);
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

    // Fin de la route : nouvelle direction si plus personne à déposer.
    if (_pos >= _route.length - 1 && _shift.riders.isEmpty) {
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
    _request = _Request(
      ShiftRider(name: names[_rnd.nextInt(names.length)], pickupIdx: pickup, dropIdx: drop, fare: fare, seats: seats),
      _nearestPlaceName(_route[drop]),
      4.5 + _rnd.nextInt(5) / 10,
      takenAfter: _rnd.nextInt(4) == 0 ? Duration(milliseconds: 4000 + _rnd.nextInt(6000)) : null,
    );
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
    setState(() {
      _shift.accept(r.rider);
      _request = null;
    });
  }

  void _decline() => setState(() => _request = null);

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
            const Spacer(),
            // Interrupteur en ligne / hors ligne
            GestureDetector(
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
                  Text(_online ? s.t('online') : s.t('offline'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
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
            const Spacer(),
            MapCircleButton(
              icon: _follow ? Icons.navigation : Icons.navigation_outlined,
              onTap: () {
                setState(() => _follow = true);
                if (_mapReady) _map.move(_taxi, 16, offset: _followOffset);
              },
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
            Text(distanceText(_metersTo(st.idx)), style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
        ),
    ]);
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
            const SizedBox(height: 12),
            _infoLine(Icons.person_pin_circle, AppColors.moroccoGreen,
                '${distanceText(_metersTo(r.rider.pickupIdx))} ${s.t('pickupAhead')}'),
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
                    Text(k == TaxiKind.grand ? s.t('grandTaxi') : s.t('petitTaxi'),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('${k == TaxiKind.grand ? 6 : 3} ${s.t('seats')}',
                        style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                  ]),
                ),
              ),
            ),
            if (k == TaxiKind.petit) const SizedBox(width: 10),
          ],
        ]),
        const SizedBox(height: 14),
        FilledButton.icon(
          style:
              FilledButton.styleFrom(backgroundColor: AppColors.moroccoGreen, minimumSize: const Size.fromHeight(60)),
          onPressed: _goOnline,
          icon: const Icon(Icons.power_settings_new),
          label: Text(s.t('goOnline'), style: const TextStyle(fontSize: 18)),
        ),
      ]);

  Widget _onlinePanel() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _seatCounter(),
        const Divider(height: 26, color: AppColors.line),
        _stops(),
      ]);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        Positioned.fill(child: _buildMap()),
        Column(children: [
          _topBar(),
          if (_online) _earningsCard(),
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
