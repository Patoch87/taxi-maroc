import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:latlong2/latlong.dart';

import '../services/rides.dart';

/// Point affiché sur la carte Google du chauffeur.
class GooglePin {
  final String id;
  final LatLng at;
  final String title;
  final double hue;
  const GooglePin(this.id, this.at, this.title, this.hue);
}

gm.LatLng toGoogle(LatLng p) => gm.LatLng(p.latitude, p.longitude);

/// Taxi vu du dessus (rouge pour le petit taxi, crème pour le grand), pointé vers le haut.
gm.BitmapDescriptor taxiIcon(TaxiKind kind, {double width = 26}) => gm.AssetMapBitmap(
      kind == TaxiKind.grand ? 'assets/map/taxi_grand.png' : 'assets/map/taxi_petit.png',
      width: width,
    );

/// Carte Google Maps (seulement quand une clé est fournie à la compilation), pour le passager comme
/// pour le chauffeur : itinéraire, points d'arrêt et taxi.
class GoogleTaxiMap extends StatefulWidget {
  /// Taxi suivi, orienté selon [bearingDeg] ; absent quand il n'y a pas encore de taxi.
  final LatLng? taxi;
  final LatLng initial;
  final TaxiKind taxiKind;

  /// Taxis libres autour du passager (petites icônes de taxi).
  final List<LatLng> nearbyTaxis;
  final double bearingDeg;
  final List<LatLng> route;
  final List<GooglePin> pins;
  final void Function(gm.GoogleMapController) onCreated;
  final VoidCallback onUserMove;

  /// Zone cachée par les panneaux : Google Maps centre et cadre la carte dans le reste.
  final EdgeInsets padding;

  const GoogleTaxiMap({
    super.key,
    required this.taxi,
    LatLng? initial,
    required this.bearingDeg,
    required this.route,
    required this.pins,
    required this.onCreated,
    required this.onUserMove,
    this.padding = EdgeInsets.zero,
    this.taxiKind = TaxiKind.petit,
    this.nearbyTaxis = const [],
  }) : initial = initial ?? taxi ?? const LatLng(33.5731, -7.5898);

  @override
  State<GoogleTaxiMap> createState() => _GoogleTaxiMapState();
}

class _GoogleTaxiMapState extends State<GoogleTaxiMap> {
  /// L'écran se redessine 10 fois par seconde pour animer le taxi ; la carte Google, elle, n'est mise
  /// à jour que toutes les 400 ms (ou tout de suite si un arrêt ou l'itinéraire change), sinon elle rame.
  static const _refresh = Duration(milliseconds: 400);
  Widget? _cached;
  DateTime _builtAt = DateTime(0);
  String _signature = '';

  String _sig(GoogleTaxiMap w) => [
        w.route.isEmpty ? '' : w.route.last,
        for (final p in w.pins) p.id,
        w.taxi == null,
        w.taxiKind,
        w.nearbyTaxis.length,
        w.padding,
      ].join('|');

  @override
  Widget build(BuildContext context) {
    final sig = _sig(widget);
    final now = DateTime.now();
    if (_cached != null && sig == _signature && now.difference(_builtAt) < _refresh) return _cached!;
    _signature = sig;
    _builtAt = now;
    return _cached = _map(widget);
  }

  Widget _map(GoogleTaxiMap w) {
    final taxi = w.taxi;
    return gm.GoogleMap(
      initialCameraPosition: gm.CameraPosition(target: toGoogle(w.initial), zoom: 16),
      onMapCreated: w.onCreated,
      onCameraMoveStarted: w.onUserMove,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
      buildingsEnabled: false,
      padding: w.padding,
      polylines: {
        if (w.route.length > 1)
          gm.Polyline(
            polylineId: const gm.PolylineId('route'),
            points: [for (final p in w.route) toGoogle(p)],
            color: const Color(0xFF1A73E8),
            width: 6,
          ),
      },
      markers: {
        for (final (i, p) in w.nearbyTaxis.indexed)
          gm.Marker(
            markerId: gm.MarkerId('nearby-$i'),
            position: toGoogle(p),
            // Orientation variée mais fixe pour chaque taxi.
            rotation: (i * 67) % 360.0,
            flat: true,
            anchor: const Offset(.5, .5),
            icon: _nearbyIcon,
          ),
        for (final p in w.pins)
          gm.Marker(
            markerId: gm.MarkerId(p.id),
            position: toGoogle(p.at),
            infoWindow: gm.InfoWindow(title: p.title),
            icon: gm.BitmapDescriptor.defaultMarkerWithHue(p.hue),
          ),
        if (taxi != null)
          gm.Marker(
            markerId: const gm.MarkerId('taxi'),
            position: toGoogle(taxi),
            rotation: w.bearingDeg,
            flat: true,
            anchor: const Offset(.5, .5),
            icon: w.taxiKind == TaxiKind.grand ? _grandIcon : _petitIcon,
            zIndexInt: 10,
          ),
      },
    );
  }
}

final _petitIcon = taxiIcon(TaxiKind.petit);
final _grandIcon = taxiIcon(TaxiKind.grand);
final _nearbyIcon = taxiIcon(TaxiKind.petit, width: 20);
