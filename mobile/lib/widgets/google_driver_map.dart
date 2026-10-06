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

/// Carte Google Maps du mode chauffeur (seulement quand une clé est fournie à la compilation) :
/// itinéraire, passagers à prendre, destinations et taxi, avec suivi du taxi.
class GoogleDriverMap extends StatelessWidget {
  final LatLng taxi;
  final double bearingDeg;
  final List<LatLng> route;
  final List<GooglePin> pins;
  final void Function(gm.GoogleMapController) onCreated;
  final VoidCallback onUserMove;

  const GoogleDriverMap({
    super.key,
    required this.taxi,
    required this.bearingDeg,
    required this.route,
    required this.pins,
    required this.onCreated,
    required this.onUserMove,
  });

  @override
  Widget build(BuildContext context) {
    return gm.GoogleMap(
      initialCameraPosition: gm.CameraPosition(target: toGoogle(taxi), zoom: 16),
      onMapCreated: onCreated,
      onCameraMoveStarted: onUserMove,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
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
        gm.Marker(
          markerId: const gm.MarkerId('taxi'),
          position: toGoogle(taxi),
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
