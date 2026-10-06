import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:latlong2/latlong.dart';

/// Point affiché sur la carte Google du chauffeur.
class GooglePin {
  final String id;
  final LatLng at;
  final String title;
  final double hue;
  const GooglePin(this.id, this.at, this.title, this.hue);
}

gm.LatLng toGoogle(LatLng p) => gm.LatLng(p.latitude, p.longitude);

/// Carte Google Maps (seulement quand une clé est fournie à la compilation), pour le passager comme
/// pour le chauffeur : itinéraire, points d'arrêt et taxi.
class GoogleTaxiMap extends StatelessWidget {
  /// Taxi suivi, orienté selon [bearingDeg] ; absent quand il n'y a pas encore de taxi.
  final LatLng? taxi;
  final LatLng initial;
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
  }) : initial = initial ?? taxi ?? const LatLng(33.5731, -7.5898);

  @override
  Widget build(BuildContext context) {
    return gm.GoogleMap(
      initialCameraPosition: gm.CameraPosition(target: toGoogle(initial), zoom: 16),
      onMapCreated: onCreated,
      onCameraMoveStarted: onUserMove,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
      padding: padding,
      polylines: {
        if (route.length > 1)
          gm.Polyline(
            polylineId: const gm.PolylineId('route'),
            points: [for (final p in route) toGoogle(p)],
            color: const Color(0xFF1A73E8),
            width: 6,
          ),
      },
      markers: {
        for (final p in pins)
          gm.Marker(
            markerId: gm.MarkerId(p.id),
            position: toGoogle(p.at),
            infoWindow: gm.InfoWindow(title: p.title),
            icon: gm.BitmapDescriptor.defaultMarkerWithHue(p.hue),
          ),
        if (taxi != null)
          gm.Marker(
            markerId: const gm.MarkerId('taxi'),
            position: toGoogle(taxi!),
            rotation: bearingDeg,
            flat: true,
            anchor: const Offset(.5, .5),
            icon: gm.BitmapDescriptor.defaultMarkerWithHue(gm.BitmapDescriptor.hueAzure),
            zIndexInt: 10,
          ),
      },
    );
  }
}
