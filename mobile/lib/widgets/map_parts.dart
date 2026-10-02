import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/rides.dart';
import '../theme.dart';

/// Fond de carte clair (CARTO Voyager, données OpenStreetMap).
/// Pour la mise en production : prendre un fournisseur de tuiles avec contrat (CARTO, Mapbox, Google).
TileLayer baseTiles() => TileLayer(
      urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
      subdomains: const ['a', 'b', 'c', 'd'],
      retinaMode: true,
      userAgentPackageName: 'ma.taxi.taxi_maroc',
    );

/// Mention obligatoire des sources de la carte.
Widget mapAttribution() => const Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: EdgeInsets.only(top: 4, right: 6),
        child: Text('© OpenStreetMap © CARTO', style: TextStyle(fontSize: 9, color: Colors.black54)),
      ),
    );

Marker taxiMarker(LatLng p, TaxiKind kind, {double rotation = 0}) => Marker(
      point: p,
      width: 34,
      height: 34,
      child: Transform.rotate(
        angle: rotation,
        child: Container(
          decoration: BoxDecoration(
            color: taxiColor(kind),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
          ),
          child: Icon(Icons.local_taxi, size: 18, color: kind == TaxiKind.grand ? AppColors.ink : Colors.white),
        ),
      ),
    );

/// Point bleu de la position de l'utilisateur.
Marker meMarker(LatLng p) => Marker(
      point: p,
      width: 26,
      height: 26,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A73E8),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
        ),
      ),
    );

/// Point de départ (rond noir) ou d'arrivée (carré noir), comme sur les applications de VTC.
Marker stopMarker(LatLng p, {required bool destination}) => Marker(
      point: p,
      width: 22,
      height: 22,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.ink,
          shape: destination ? BoxShape.rectangle : BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
        ),
        child: Center(
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: destination ? BoxShape.rectangle : BoxShape.circle,
            ),
          ),
        ),
      ),
    );

Polyline routeLine(List<LatLng> pts, {Color color = AppColors.ink}) =>
    Polyline(points: pts, strokeWidth: 5, color: color, borderColor: Colors.white, borderStrokeWidth: 1.5);

/// Bouton rond flottant au-dessus de la carte.
class MapCircleButton extends StatelessWidget {
  const MapCircleButton({super.key, required this.icon, required this.onTap, this.tooltip});
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 4,
        shadowColor: Colors.black26,
        child: IconButton(icon: Icon(icon), onPressed: onTap, tooltip: tooltip),
      );
}

/// Panneau blanc arrondi en bas de l'écran.
class BottomPanel extends StatelessWidget {
  const BottomPanel({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 16)],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                AnimatedSize(duration: const Duration(milliseconds: 250), child: child),
              ],
            ),
          ),
        ),
      );
}
