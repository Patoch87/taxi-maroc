import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/rides.dart';
import '../theme.dart';
import 'app_logo.dart';

/// Fond de carte OpenStreetMap (gratuit, sans clé). Les tuiles CARTO demandent désormais une clé.
/// Pour la mise en production : prendre un fournisseur de tuiles avec contrat (Mapbox, MapTiler, Google).
TileLayer baseTiles() => TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      maxNativeZoom: 19,
      userAgentPackageName: 'ma.taxi.taxi_maroc',
    );

/// Mention obligatoire des sources de la carte.
Widget mapAttribution() => const Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: EdgeInsets.only(top: 4, right: 6),
        child: Text('© OpenStreetMap', style: TextStyle(fontSize: 9, color: Colors.black54)),
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

Polyline routeLine(List<LatLng> pts, {Color color = AppColors.moroccoGreen}) =>
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
        child: IconButton(icon: Icon(icon, color: AppColors.ink), onPressed: onTap, tooltip: tooltip),
      );
}

/// Panneau couleur sable arrondi en bas de l'écran, avec un liseré de zellige en haut.
class BottomPanel extends StatelessWidget {
  const BottomPanel({super.key, required this.child, this.handle, this.maxHeightFactor = .7});

  /// Hauteur maximale, en part de l'écran (fin de course : plus haut pour voir la note et « Envoyer »).
  final double maxHeightFactor;
  final Widget child;

  /// Poignée à glisser (remplace la barre dorée simple) : voir l'accueil du passager.
  final Widget? handle;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          color: AppColors.sand,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 16)],
        ),
        child: Stack(children: [
          // Motif de zellige très discret derrière la poignée.
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 30,
            child: Zellige(opacity: .12, cell: 22),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, handle == null ? 10 : 0, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  handle ??
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(3)),
                        ),
                      ),
                  // Le panneau ne dépasse pas 70 % de l'écran (par défaut) ; au-delà, son contenu défile.
                  // Flexible : avec une demande affichée au-dessus, le panneau rétrécit au lieu de déborder.
                  Flexible(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * maxHeightFactor),
                      // Nouvelle étape (clé différente) : le contenu repart du haut.
                      child: SingleChildScrollView(
                        key: child.key == null ? null : ValueKey(child.key),
                        child: AnimatedSize(duration: const Duration(milliseconds: 250), child: child),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ]),
      );
}
