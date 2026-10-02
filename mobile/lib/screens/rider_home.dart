import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../main.dart';
import '../services/location.dart';
import '../services/places.dart';
import '../services/rides.dart';
import '../services/routing.dart';
import '../theme.dart';
import '../widgets/map_parts.dart';
import 'complaint_screen.dart';
import 'driver_home.dart';
import 'search_screen.dart';
import 'voice_screen.dart';

enum RiderStep { idle, choosing, searching, arriving, arrived, onTrip, done }

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

  // Taxi attribué
  DemoDriver? _driver;
  List<LatLng> _taxiPath = [];
  int _taxiIndex = 0;
  Timer? _moveTimer;
  int _rating = 0;

  LatLng? get _taxiPos => _taxiPath.isEmpty ? null : _taxiPath[_taxiIndex];

  @override
  void initState() {
    super.initState();
    if (widget.locate) _locate();
    _ambientTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted || _step.index >= RiderStep.arriving.index) return;
      setState(() {
        _ambient = _ambient
            .map((p) => LatLng(p.latitude + (_rnd.nextDouble() - .5) * .0006,
                p.longitude + (_rnd.nextDouble() - .5) * .0006))
            .toList();
      });
    });
  }

  @override
  void dispose() {
    _ambientTimer?.cancel();
    _moveTimer?.cancel();
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
      padding: const EdgeInsets.fromLTRB(60, 130, 60, 470),
    ));
  }

  Future<void> _pickDestination() async {
    final place = await Navigator.push<Place>(context, MaterialPageRoute(builder: (_) => const SearchScreen()));
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

  Future<void> _request() async {
    setState(() => _step = RiderStep.searching);
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted || _step != RiderStep.searching) return;
    // Le taxi le plus proche parmi ceux de la carte.
    const d = Distance();
    final start = _ambient.reduce((a, b) => d(a, _me) < d(b, _me) ? a : b);
    final path = await fetchRoute(start, _me);
    if (!mounted || _step != RiderStep.searching) return;
    setState(() {
      _driver = DemoDriver.random(_selected!.kind, _rnd);
      _taxiPath = path;
      _taxiIndex = 0;
      _step = RiderStep.arriving;
    });
    _fit([...path, _me]);
    _animateTaxi(onEnd: () => setState(() => _step = RiderStep.arrived));
  }

  void _animateTaxi({required VoidCallback onEnd}) {
    _moveTimer?.cancel();
    // Environ 12 secondes pour parcourir le trajet, quelle que soit sa longueur.
    final stepMs = max(40, 12000 ~/ max(1, _taxiPath.length));
    _moveTimer = Timer.periodic(Duration(milliseconds: stepMs), (t) {
      if (!mounted) return t.cancel();
      if (_taxiIndex >= _taxiPath.length - 1) {
        t.cancel();
        onEnd();
        return;
      }
      setState(() => _taxiIndex++);
    });
  }

  void _startTrip() {
    setState(() {
      _taxiPath = _route;
      _taxiIndex = 0;
      _step = RiderStep.onTrip;
    });
    _fit(_route);
    _animateTaxi(onEnd: () => setState(() => _step = RiderStep.done));
  }

  void _reset() {
    _moveTimer?.cancel();
    setState(() {
      _step = RiderStep.idle;
      _dest = null;
      _route = [];
      _taxiPath = [];
      _driver = null;
      _rating = 0;
    });
    if (_mapReady) _map.move(_me, 15);
  }

  int get _etaMin {
    if (_taxiPath.isEmpty) return 0;
    final left = routeLengthM(_taxiPath.sublist(_taxiIndex));
    return max(1, (left / 400).round()); // environ 24 km/h en ville
  }

  // ---------------------------------------------------------------- Carte

  Widget _buildMap() {
    final showAmbient = _step.index < RiderStep.arriving.index;
    final routeToShow = switch (_step) {
      RiderStep.choosing || RiderStep.searching || RiderStep.onTrip => _route,
      RiderStep.arriving => _taxiPath.sublist(_taxiIndex),
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
          if (showAmbient) for (final p in _ambient) taxiMarker(p, TaxiKind.petit),
          if (_step == RiderStep.idle) meMarker(_me),
          if (_dest != null && _step != RiderStep.idle) ...[
            if (_step != RiderStep.onTrip) stopMarker(_me, destination: false),
            stopMarker(LatLng(_dest!.lat, _dest!.lng), destination: true),
          ],
          if (_taxiPos != null && _step.index >= RiderStep.arriving.index && _step != RiderStep.done)
            taxiMarker(_taxiPos!, _selected!.kind),
        ]),
        mapAttribution(),
      ],
    );
  }

  // ---------------------------------------------------------------- Panneaux

  Widget _panel() => switch (_step) {
        RiderStep.idle => _idlePanel(),
        RiderStep.choosing => _choosePanel(),
        RiderStep.searching => _searchingPanel(),
        RiderStep.arriving || RiderStep.arrived || RiderStep.onTrip => _tripPanel(),
        RiderStep.done => _donePanel(),
      };

  Widget _idlePanel() => Column(
        key: const ValueKey('idle'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.t('whereTo'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _pickDestination,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(color: const Color(0xFFF3F3F3), borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                const Icon(Icons.search, size: 26),
                const SizedBox(width: 12),
                Text(s.t('searchPlace'), style: const TextStyle(fontSize: 17, color: AppColors.muted)),
              ]),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final p in casablancaPlaces.take(5))
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      avatar: const Icon(Icons.place, size: 18),
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

  Widget _choosePanel() => Column(
        key: const ValueKey('choose'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(
              child: Text(s.t('chooseRide'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ),
            Text(distanceText(_routeM), style: const TextStyle(color: AppColors.muted)),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.arrow_forward, size: 16, color: AppColors.muted),
            const SizedBox(width: 6),
            Expanded(child: Text(_dest!.name, style: const TextStyle(color: AppColors.muted))),
          ]),
          const SizedBox(height: 10),
          for (final o in _options) _optionTile(o),
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.verified_user_outlined, size: 16, color: AppColors.moroccoGreen),
            const SizedBox(width: 6),
            Expanded(
              child: Text(s.t('officialPrice'),
                  style: const TextStyle(fontSize: 12, color: AppColors.moroccoGreen)),
            ),
          ]),
          const SizedBox(height: 12),
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
                child: Text('${s.t('confirm')} · ${_selected!.title}', overflow: TextOverflow.ellipsis),
              ),
            ),
          ]),
        ],
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
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppColors.ink : AppColors.line, width: selected ? 2 : 1.5),
        ),
        child: Row(children: [
          Container(
            width: 52,
            height: 40,
            decoration: BoxDecoration(color: taxiColor(o.kind), borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.local_taxi, color: o.kind == TaxiKind.grand ? AppColors.ink : Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(o.title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.person, size: 14, color: AppColors.muted),
                Text('${o.seats}', style: const TextStyle(fontSize: 13, color: AppColors.muted)),
              ]),
              Text(o.description, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
            ]),
          ),
          Text(dh(o.priceMad),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }

  Widget _searchingPanel() => Column(
        key: const ValueKey('searching'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.t('searching'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          const LinearProgressIndicator(minHeight: 4, color: AppColors.ink, backgroundColor: AppColors.line),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: _reset, child: Text(s.t('cancel'))),
        ],
      );

  Widget _tripPanel() {
    final d = _driver!;
    final title = switch (_step) {
      RiderStep.arriving => '${s.t('arrivingIn')} $_etaMin ${s.t('minutes')}',
      RiderStep.arrived => s.t('arrived'),
      _ => '${s.t('onTrip')} ${_dest!.name}',
    };
    return Column(
      key: const ValueKey('trip'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        Row(children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFFF3F3F3),
            foregroundColor: AppColors.ink,
            child: Text(d.name.substring(0, 1), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(d.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(width: 6),
                const Icon(Icons.star, size: 16, color: Color(0xFFF5B301)),
                Text(d.rating.toStringAsFixed(1)),
              ]),
              Text(d.car, style: const TextStyle(color: AppColors.muted)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFF3F3F3), borderRadius: BorderRadius.circular(6)),
              child: Text(d.plate, style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 4),
            Text(d.taxiNumber, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ]),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFF7F7F7), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Expanded(child: Text(_selected!.title, style: const TextStyle(fontWeight: FontWeight.w600))),
            Text(dh(_selected!.priceMad), style: const TextStyle(fontWeight: FontWeight.w800)),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.flag_outlined),
              label: Text(s.t('complain'), overflow: TextOverflow.ellipsis),
              onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => ComplaintScreen(taxiId: d.taxiNumber))),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 64,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.taxiRed, padding: EdgeInsets.zero),
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('SOS : position envoyée à vos proches et aux secours (démo)'))),
              child: const Text('SOS'),
            ),
          ),
        ]),
        if (_step == RiderStep.arrived) ...[
          const SizedBox(height: 10),
          FilledButton(onPressed: _startTrip, child: Text(s.t('startTrip'))),
        ],
        if (_step == RiderStep.arriving) ...[
          const SizedBox(height: 4),
          TextButton(onPressed: _reset, child: Text(s.t('cancel'), style: const TextStyle(color: AppColors.muted))),
        ],
      ],
    );
  }

  Widget _donePanel() => Column(
        key: const ValueKey('done'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.t('tripDone'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFF7F7F7), borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              Text(s.t('pay'), style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 4),
              Text(dh(_selected!.priceMad),
                  style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
              Text('${_driver!.name} · ${_driver!.taxiNumber}', style: const TextStyle(color: AppColors.muted)),
            ]),
          ),
          const SizedBox(height: 14),
          Text(s.t('rate'), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  iconSize: 36,
                  onPressed: () => setState(() => _rating = i),
                  icon: Icon(i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: const Color(0xFFF5B301)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: _reset, child: Text(s.t('done'))),
          TextButton(
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => ComplaintScreen(taxiId: _driver?.taxiNumber))),
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
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: AppColors.taxiRed, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.local_taxi, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Text(s.t('appTitle'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                ]),
              ),
              const Divider(color: AppColors.line),
              ListTile(
                leading: const Icon(Icons.drive_eta_outlined),
                title: Text(s.t('driverMode')),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverHome()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.mic_none),
                title: Text(s.t('voiceMode')),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const VoiceScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text(s.t('complain')),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ComplaintScreen()));
                },
              ),
              const Divider(color: AppColors.line),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Text(s.t('language'), style: const TextStyle(color: AppColors.muted)),
              ),
              for (final (code, label) in const [('fr', 'Français'), ('ar', 'العربية'), ('en', 'English')])
                ListTile(
                  title: Text(label),
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
                  builder: (ctx) => MapCircleButton(icon: Icons.menu, onTap: () => Scaffold.of(ctx).openDrawer()),
                ),
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
