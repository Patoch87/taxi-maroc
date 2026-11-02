import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:latlong2/latlong.dart';

import '../services/rides.dart';

/// Dessin d'un point sur la carte, à la manière d'Uber : position (point bleu), prise en charge (rond noir),
/// destination (carré noir). [PinStyle.hue] garde l'épingle Google classique de la couleur donnée.
enum PinStyle { hue, me, pickup, dest }

/// Point affiché sur la carte Google.
class GooglePin {
  final String id;
  final LatLng at;
  final String title;
  final double hue;
  final PinStyle style;
  const GooglePin(this.id, this.at, this.title, this.hue, {this.style = PinStyle.hue});
}

/// Style de carte clair et épuré (inspiré d'Uber) : fond gris très clair, rues blanches, grands axes bleu pâle,
/// commerces masqués pour que les taxis, l'itinéraire et les arrêts ressortent.
const babMapStyle = '''[
  {"elementType":"geometry","stylers":[{"color":"#eef0f3"}]},
  {"elementType":"labels.icon","stylers":[{"saturation":-100},{"lightness":20}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#5f6368"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#ffffff"},{"weight":3}]},
  {"featureType":"administrative.land_parcel","stylers":[{"visibility":"off"}]},
  {"featureType":"administrative.neighborhood","elementType":"labels.text.fill","stylers":[{"color":"#7b8ca8"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#e6e8ec"}]},
  {"featureType":"poi.business","stylers":[{"visibility":"off"}]},
  {"featureType":"poi.medical","elementType":"labels","stylers":[{"visibility":"simplified"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#d3ecd0"}]},
  {"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#4f9a5a"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffffff"}]},
  {"featureType":"road","elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#ffffff"}]},
  {"featureType":"road.highway","elementType":"geometry.fill","stylers":[{"color":"#c3d1ec"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#aebfe0"}]},
  {"featureType":"road.local","elementType":"labels.text.fill","stylers":[{"color":"#8a9099"}]},
  {"featureType":"transit.line","stylers":[{"visibility":"simplified"},{"color":"#d6d9de"}]},
  {"featureType":"transit.station","elementType":"labels.icon","stylers":[{"saturation":-100}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#c6dbef"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#7a9cc0"}]}
]''';

/// Icônes dessinées une fois au lancement (point bleu, rond et carré noirs, bulle « 2 min »).
class MapIcons {
  static final ready = ValueNotifier<int>(0);
  static final Map<String, gm.BitmapDescriptor> _cache = {};
  static bool _loading = false;

  static gm.BitmapDescriptor? get(PinStyle style) => _cache[style.name];

  /// Bulle d'heure d'arrivée (« 3 min ») ; dessinée à la demande puis gardée.
  static gm.BitmapDescriptor? bubble(String text) {
    final key = 'bubble:$text';
    final b = _cache[key];
    if (b == null) {
      _draw(_bubbleSize(text), (c, size) => _paintBubble(c, size, text)).then((d) {
        _cache[key] = d;
        ready.value++;
      }).catchError((_) {});
    }
    return b;
  }

  static Future<void> load() async {
    if (_loading) return;
    _loading = true;
    try {
      _cache[PinStyle.me.name] = await _draw(const Size(30, 30), _paintMe);
      _cache[PinStyle.pickup.name] = await _draw(const Size(22, 22), _paintPickup);
      _cache[PinStyle.dest.name] = await _draw(const Size(20, 20), _paintDest);
      ready.value++;
    } catch (_) {
      _loading = false;
    }
  }

  static double get _ratio {
    final views = ui.PlatformDispatcher.instance.views;
    return views.isEmpty ? 3 : views.first.devicePixelRatio.clamp(1, 4).toDouble();
  }

  static Future<gm.BitmapDescriptor> _draw(Size size, void Function(Canvas, Size) paint) async {
    final r = _ratio;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec)..scale(r);
    paint(c, size);
    final img = await rec.endRecording().toImage((size.width * r).ceil(), (size.height * r).ceil());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return gm.BytesMapBitmap(bytes!.buffer.asUint8List(), width: size.width, height: size.height);
  }

  static void _paintMe(Canvas c, Size s) {
    final o = s.center(Offset.zero);
    c.drawCircle(o, 15, Paint()..color = const Color(0x331A73E8));
    c.drawCircle(o.translate(0, .8), 8.5, Paint()..color = const Color(0x40000000)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5));
    c.drawCircle(o, 8.5, Paint()..color = Colors.white);
    c.drawCircle(o, 6, Paint()..color = const Color(0xFF1A73E8));
  }

  static void _paintPickup(Canvas c, Size s) {
    final o = s.center(Offset.zero);
    c.drawCircle(o, 10, Paint()..color = const Color(0xFF111111));
    c.drawCircle(o, 4, Paint()..color = Colors.white);
  }

  static void _paintDest(Canvas c, Size s) {
    c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF111111));
    c.drawRect(Rect.fromCenter(center: s.center(Offset.zero), width: 7, height: 7), Paint()..color = Colors.white);
  }

  static TextPainter _text(String t) => TextPainter(
        text: TextSpan(text: t, style: const TextStyle(color: Color(0xFF111111), fontSize: 15, fontWeight: FontWeight.w700)),
        textDirection: TextDirection.ltr,
      )..layout();

  static Size _bubbleSize(String t) {
    final p = _text(t);
    return Size(p.width + 26, p.height + 18);
  }

  static void _paintBubble(Canvas c, Size s, String t) {
    final box = RRect.fromRectAndRadius(Rect.fromLTWH(3, 2, s.width - 6, s.height - 6), const Radius.circular(10));
    c.drawRRect(box.shift(const Offset(0, 1.5)),
        Paint()..color = const Color(0x33000000)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    c.drawRRect(box, Paint()..color = Colors.white);
    final p = _text(t);
    p.paint(c, Offset((s.width - p.width) / 2, (s.height - 4 - p.height) / 2));
  }
}

gm.LatLng toGoogle(LatLng p) => gm.LatLng(p.latitude, p.longitude);

/// Taxi vu du dessus (rouge pour le petit taxi, crème pour le grand), pointé vers le haut.
gm.BitmapDescriptor taxiIcon(TaxiKind kind, {double width = 32}) => gm.AssetMapBitmap(
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

  /// Bulle d'heure d'arrivée (« 3 min ») posée à côté de [etaAt], comme chez Uber.
  final String? etaLabel;
  final LatLng? etaAt;
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
    this.etaLabel,
    this.etaAt,
  }) : initial = initial ?? taxi ?? const LatLng(33.5731, -7.5898);

  @override
  State<GoogleTaxiMap> createState() => _GoogleTaxiMapState();
}

class _GoogleTaxiMapState extends State<GoogleTaxiMap> {
  /// L'écran se redessine 10 fois par seconde pour animer le taxi ; la carte Google, elle, n'est mise
  /// à jour que toutes les 400 ms (ou tout de suite si un arrêt ou l'itinéraire change), sinon elle rame.
  static const _refresh = Duration(milliseconds: 250);
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
        w.etaLabel,
        MapIcons.ready.value,
      ].join('|');

  @override
  void initState() {
    super.initState();
    MapIcons.load();
    MapIcons.ready.addListener(_iconsReady);
  }

  @override
  void dispose() {
    MapIcons.ready.removeListener(_iconsReady);
    super.dispose();
  }

  void _iconsReady() {
    if (mounted) setState(() {});
  }

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
      indoorViewEnabled: false,
      trafficEnabled: false,
      tiltGesturesEnabled: false,
      style: babMapStyle,
      padding: w.padding,
      // Itinéraire noir bordé de blanc, lisible sur le fond clair (comme Uber).
      polylines: {
        if (w.route.length > 1) ...[
          gm.Polyline(
            polylineId: const gm.PolylineId('route-casing'),
            points: [for (final p in w.route) toGoogle(p)],
            color: Colors.white,
            width: 9,
            jointType: gm.JointType.round,
            startCap: gm.Cap.roundCap,
            endCap: gm.Cap.roundCap,
            zIndex: 1,
          ),
          gm.Polyline(
            polylineId: const gm.PolylineId('route'),
            points: [for (final p in w.route) toGoogle(p)],
            color: const Color(0xFF111111),
            width: 5,
            jointType: gm.JointType.round,
            startCap: gm.Cap.roundCap,
            endCap: gm.Cap.roundCap,
            zIndex: 2,
          ),
        ],
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
            anchor: p.style == PinStyle.hue || MapIcons.get(p.style) == null ? const Offset(.5, 1) : const Offset(.5, .5),
            zIndexInt: 5,
            icon: (p.style == PinStyle.hue ? null : MapIcons.get(p.style)) ??
                gm.BitmapDescriptor.defaultMarkerWithHue(p.hue),
          ),
        if (w.etaLabel != null && w.etaAt != null && MapIcons.bubble(w.etaLabel!) != null)
          gm.Marker(
            markerId: const gm.MarkerId('eta'),
            position: toGoogle(w.etaAt!),
            // Bulle en haut à droite du point, sans le cacher.
            anchor: const Offset(-.08, 1.15),
            zIndexInt: 6,
            consumeTapEvents: true,
            icon: MapIcons.bubble(w.etaLabel!)!,
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
final _nearbyIcon = taxiIcon(TaxiKind.petit, width: 26);
