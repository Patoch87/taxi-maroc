import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../main.dart';
import '../services/demo.dart';
import '../services/location.dart';
import '../services/places.dart';
import '../services/rides.dart';
import '../services/routing.dart';
import '../theme.dart';
import '../widgets/map_parts.dart';

enum DriverStep { offline, online, request, toPickup, onBoard }

/// Écran chauffeur : le chauffeur suit sa route et ne voit que les passagers
/// qui sont devant lui et vont dans sa direction. Gros boutons pour ne pas distraire la conduite.
class DriverHome extends StatefulWidget {
  const DriverHome({super.key});

  @override
  State<DriverHome> createState() => _DriverHomeState();
}

class _DriverHomeState extends State<DriverHome> {
  final _map = MapController();
  final _rnd = Random();
  bool _mapReady = false;

  DriverStep _step = DriverStep.offline;
  LatLng _me = casablancaCenter;
  Place _heading = casablancaPlaces[2];
  List<LatLng> _route = [];
  int _pos = 0;
  int _pickupIdx = 0;
  int _dropIdx = 0;
  double _fare = 0;
  double _earnings = 0;
  int _passengers = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    currentLatLng().then((p) {
      if (!mounted) return;
      setState(() => _me = p);
      if (_mapReady) _map.move(p, 15);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  LatLng get _taxi => _route.isEmpty ? _me : _route[_pos];

  Future<void> _goOnline() async {
    _heading = casablancaPlaces[_rnd.nextInt(6)];
    final route = await fetchRoute(_me, LatLng(_heading.lat, _heading.lng));
    if (!mounted) return;
    setState(() {
      _route = route.length > 10 ? route : interpolate(_me, LatLng(_heading.lat, _heading.lng), 60);
      _pos = 0;
      _step = DriverStep.online;
    });
    if (_mapReady) {
      _map.fitCamera(CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(_route), padding: const EdgeInsets.fromLTRB(60, 120, 60, 320)));
    }
    // Une demande arrive après quelques secondes de conduite.
    _drive(until: () => _pos >= _route.length ~/ 6, then: _newRequest);
  }

  void _goOffline() {
    _timer?.cancel();
    setState(() {
      _step = DriverStep.offline;
      _route = [];
      _pos = 0;
      _passengers = 0;
    });
  }

  void _drive({required bool Function() until, required VoidCallback then}) {
    _timer?.cancel();
    final stepMs = max(60, 14000 ~/ max(1, _route.length));
    _timer = Timer.periodic(Duration(milliseconds: stepMs), (t) {
      if (!mounted) return t.cancel();
      if (until() || _pos >= _route.length - 1) {
        t.cancel();
        then();
        return;
      }
      setState(() => _pos++);
    });
  }

  void _newRequest() {
    final remaining = _route.length - _pos;
    setState(() {
      _pickupIdx = min(_route.length - 2, _pos + max(2, remaining ~/ 4));
      _dropIdx = min(_route.length - 1, _pickupIdx + max(2, remaining ~/ 2));
      final km = routeLengthM(_route.sublist(_pickupIdx, _dropIdx + 1)) / 1000;
      _fare = Demo.petitTaxiPrice(routeKm: km, seul: false, premium: false);
      _step = DriverStep.request;
    });
  }

  void _accept() {
    setState(() => _step = DriverStep.toPickup);
    _drive(
      until: () => _pos >= _pickupIdx,
      then: () => setState(() {
        _passengers++;
        _step = DriverStep.onBoard;
      }),
    );
  }

  void _decline() {
    setState(() => _step = DriverStep.online);
    _drive(until: () => _pos >= _route.length - 1, then: () {});
  }

  void _dropOff() {
    setState(() {
      _earnings += _fare;
      _passengers = max(0, _passengers - 1);
      _step = DriverStep.online;
    });
    _drive(until: () => _pos >= _route.length - 1, then: () {});
  }

  void _toDropoff() {
    _drive(until: () => _pos >= _dropIdx, then: _dropOff);
  }

  Widget _panel() {
    switch (_step) {
      case DriverStep.offline:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(s.t('offlineHint'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.moroccoGreen, minimumSize: const Size.fromHeight(64)),
            onPressed: _goOnline,
            child: Text(s.t('goOnline'), style: const TextStyle(fontSize: 20)),
          ),
        ]);
      case DriverStep.online:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.moroccoGreen, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(child: Text(s.t('onlineHint'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.arrow_forward, size: 16, color: AppColors.muted),
            const SizedBox(width: 6),
            Expanded(child: Text(_heading.name, style: const TextStyle(color: AppColors.muted))),
          ]),
          const SizedBox(height: 14),
          OutlinedButton(onPressed: _goOffline, child: Text(s.t('goOffline'))),
        ]);
      case DriverStep.request:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(s.t('newRequest'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            '${distanceText(routeLengthM(_route.sublist(_pos, _pickupIdx + 1)))} ${s.t('pickupAhead')}',
            style: const TextStyle(fontSize: 16, color: AppColors.muted),
          ),
          const SizedBox(height: 10),
          Text(dh(_fare), style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: _decline, child: Text(s.t('decline')))),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.moroccoGreen, minimumSize: const Size.fromHeight(64)),
                onPressed: _accept,
                child: Text(s.t('accept'), style: const TextStyle(fontSize: 20)),
              ),
            ),
          ]),
        ]);
      case DriverStep.toPickup:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(distanceText(routeLengthM(_route.sublist(_pos, _pickupIdx + 1))),
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
          Text(s.t('pickupAhead'), style: const TextStyle(fontSize: 16, color: AppColors.muted)),
        ]);
      case DriverStep.onBoard:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(s.t('pickedUp'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(64)),
            onPressed: _toDropoff,
            child: Text(s.t('dropOff'), style: const TextStyle(fontSize: 20)),
          ),
        ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showPassenger = _step == DriverStep.request || _step == DriverStep.toPickup;
    final showDrop = _step == DriverStep.request || _step == DriverStep.onBoard || _step == DriverStep.toPickup;
    return Scaffold(
      body: Stack(children: [
        Positioned.fill(
          child: FlutterMap(
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
              if (_route.length > 1)
                PolylineLayer(polylines: [routeLine(_route.sublist(_pos), color: const Color(0xFF1A73E8))]),
              MarkerLayer(markers: [
                if (showPassenger)
                  Marker(
                    point: _route[_pickupIdx],
                    width: 40,
                    height: 40,
                    child: const CircleAvatar(
                      backgroundColor: AppColors.moroccoGreen,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                  ),
                if (showDrop && _route.isNotEmpty) stopMarker(_route[_dropIdx], destination: true),
                taxiMarker(_taxi, TaxiKind.petit),
              ]),
              mapAttribution(),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              MapCircleButton(icon: Icons.arrow_back, onTap: () => Navigator.pop(context)),
              const Spacer(),
              // Gains du jour et places occupées.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
                ),
                child: Text(
                  '${dh(_earnings)} · $_passengers/3 ${s.t('seats')}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
              const Spacer(),
              const SizedBox(width: 48),
            ]),
          ),
        ),
        Align(alignment: Alignment.bottomCenter, child: BottomPanel(child: _panel())),
      ]),
    );
  }
}
