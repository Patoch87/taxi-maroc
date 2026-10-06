import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'account.dart';
import 'api.dart';

/// Test réel : les téléphones (passagers et chauffeurs) partagent un même serveur au lieu des taxis
/// simulés. Activé par défaut quand l'application est compilée avec une adresse de serveur (API_URL),
/// sauf dans la démo web (?demo=1). Réglable dans le menu.
class LiveConfig extends ChangeNotifier {
  LiveConfig() : _enabled = apiUrl.isNotEmpty;

  bool _enabled;
  bool get enabled => _enabled && url.isNotEmpty;
  set enabled(bool v) {
    if (v == _enabled) return;
    _enabled = v;
    notifyListeners();
  }

  /// Adresse du serveur, sans « / » final.
  String url = apiUrl;

  /// Identifiant de ce téléphone (compte, sinon tiré au hasard au lancement).
  final String _randomId = 'D${Random().nextInt(1 << 31)}';
  String get deviceId => accountStore.account?.id ?? _randomId;

  /// Prénom et nom du compte, affichés à l'autre téléphone ([fallback] sans compte).
  String displayName([String fallback = 'Bab Taxi']) {
    final a = accountStore.account;
    if (a == null) return fallback;
    return '${a.firstName} ${a.lastName.isEmpty ? '' : '${a.lastName[0]}.'}'.trim();
  }

  @visibleForTesting
  void reset() {
    _enabled = apiUrl.isNotEmpty;
    url = apiUrl;
    notifyListeners();
  }
}

final live = LiveConfig();

Map<String, double> _pt(LatLng p) => {'lat': p.latitude, 'lng': p.longitude};
LatLng _ll(dynamic m) => LatLng((m['lat'] as num).toDouble(), (m['lng'] as num).toDouble());

/// Taxi en ligne vu par le passager.
class LiveTaxi {
  LiveTaxi(this.id, this.name, this.plate, this.grand, this.position);
  factory LiveTaxi.fromJson(Map<String, dynamic> j) => LiveTaxi(j['id'] as String, j['nom'] as String? ?? 'Taxi',
      j['plaque'] as String? ?? '', j['type'] == 'grand', _ll(j['position']));
  final String id;
  final String name;
  final String plate;
  final bool grand;
  final LatLng position;
}

/// Statut d'une course côté serveur.
enum LiveStatus { waiting, accepted, onBoard, done, cancelled, expired }

LiveStatus _status(String s) => switch (s) {
      'acceptee' => LiveStatus.accepted,
      'a_bord' => LiveStatus.onBoard,
      'terminee' => LiveStatus.done,
      'annulee' => LiveStatus.cancelled,
      'expiree' => LiveStatus.expired,
      _ => LiveStatus.waiting,
    };

/// Course vue par le passager.
class LiveRide {
  LiveRide(this.id, this.status, this.proposedTo, this.taxi);
  factory LiveRide.fromJson(Map<String, dynamic> j) => LiveRide(
        j['id'] as String,
        _status(j['statut'] as String),
        [for (final c in (j['proposeeA'] as List? ?? const [])) c['taxiId'] as String],
        j['taxi'] == null ? null : LiveTaxi.fromJson(j['taxi'] as Map<String, dynamic>),
      );
  final String id;
  final LiveStatus status;
  final List<String> proposedTo;
  final LiveTaxi? taxi;
}

/// Demande reçue par le chauffeur.
class LiveOffer {
  LiveOffer(this.id, this.pickup, this.drop, this.riderName, this.destinationName, this.fare, this.seats, this.status);
  factory LiveOffer.fromJson(Map<String, dynamic> j) {
    final d = j['demande'] as Map<String, dynamic>;
    return LiveOffer(
      j['id'] as String,
      _ll(d['depart']),
      _ll(d['destination']),
      (d['passager'] as Map?)?['nom'] as String? ?? 'Passager',
      d['destinationNom'] as String? ?? '',
      (d['prixMad'] as num?)?.toDouble() ?? 0,
      (d['passagers'] as num?)?.toInt() ?? 1,
      _status(j['statut'] as String),
    );
  }
  final String id;
  final LatLng pickup;
  final LatLng drop;
  final String riderName;
  final String destinationName;
  final double fare;
  final int seats;
  final LiveStatus status;
}

/// Client du serveur pour le test réel. Les erreurs réseau remontent en exceptions : les écrans
/// réessaient au tour suivant (interrogation toutes les 2 à 3 secondes).
class LiveApi {
  LiveApi({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _base = baseUrl;
  final http.Client _client;
  final String? _base;

  String get base => (_base ?? live.url).replaceAll(RegExp(r'/+$'), '');
  static const _timeout = Duration(seconds: 15);

  Future<dynamic> _send(String method, String path, [Map<String, dynamic>? body]) async {
    final uri = Uri.parse('$base$path');
    final headers = {'Content-Type': 'application/json'};
    final res = await switch (method) {
      'GET' => _client.get(uri),
      'PUT' => _client.put(uri, headers: headers, body: jsonEncode(body ?? {})),
      'DELETE' => _client.delete(uri),
      _ => _client.post(uri, headers: headers, body: jsonEncode(body ?? {})),
    }
        .timeout(_timeout);
    if (res.statusCode == 409) throw LiveConflict();
    if (res.statusCode >= 400) throw Exception('HTTP ${res.statusCode}');
    return res.body.isEmpty ? null : jsonDecode(res.body);
  }

  Future<bool> ping() async {
    try {
      final r = await _send('GET', '/health');
      return r is Map && r['status'] == 'ok';
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------- Passager

  Future<List<LiveTaxi>> nearby(LatLng p) async {
    final r = await _send('GET', '/taxis/nearby?lat=${p.latitude}&lng=${p.longitude}') as List;
    return [for (final t in r) LiveTaxi.fromJson(t as Map<String, dynamic>)];
  }

  Future<LiveRide> request({
    required LatLng from,
    required LatLng to,
    required String destinationName,
    required bool alone,
    required bool premium,
    required int seats,
    required double fare,
    String? riderName,
  }) async =>
      LiveRide.fromJson(await _send('POST', '/rides/requests', {
        'depart': _pt(from),
        'destination': _pt(to),
        'mode': alone ? 'seul' : 'partage',
        'passagers': seats,
        if (premium) 'categorie': 'premium',
        'passager': {'nom': riderName ?? live.displayName('Passager')},
        'destinationNom': destinationName,
        'prixMad': fare,
      }) as Map<String, dynamic>);

  Future<LiveRide> ride(String id) async =>
      LiveRide.fromJson(await _send('GET', '/rides/requests/$id') as Map<String, dynamic>);

  Future<void> cancel(String id) => _send('POST', '/rides/requests/$id/cancel');

  // ---------------------------------------------------------------- Chauffeur

  /// Position et itinéraire restant (un seul point = sans destination : demandes proches).
  Future<void> publishTaxi({
    required String id,
    required LatLng position,
    required List<LatLng> route,
    required bool grand,
    required int onBoard,
    String? plate,
  }) =>
      _send('PUT', '/taxis/$id/route', {
        'type': grand ? 'grand' : 'petit',
        'categorie': 'standard',
        'passagersABord': onBoard,
        'reserveSeul': false,
        'position': _pt(position),
        // Au plus 200 points : assez pour la correspondance, léger sur le réseau.
        'itineraire': [
          for (final p in _thin(route.isEmpty ? [position] : route, 200)) _pt(p)
        ],
        'nom': live.displayName('Chauffeur'),
        if (plate != null && plate.isNotEmpty) 'plaque': plate,
      });

  Future<void> goOffline(String id) => _send('DELETE', '/taxis/$id/route');

  Future<List<LiveOffer>> offers(String taxiId) async {
    final r = await _send('GET', '/taxis/$taxiId/offers') as List;
    return [for (final o in r) LiveOffer.fromJson(o as Map<String, dynamic>)];
  }

  /// Renvoie faux si un autre chauffeur a accepté avant.
  Future<bool> accept(String id, String taxiId) async {
    try {
      await _send('POST', '/rides/requests/$id/accept', {'taxiId': taxiId});
      return true;
    } on LiveConflict {
      return false;
    }
  }

  Future<void> decline(String id, String taxiId) => _send('POST', '/rides/requests/$id/decline', {'taxiId': taxiId});
  Future<void> pickedUp(String id, String taxiId) => _send('POST', '/rides/requests/$id/pickup', {'taxiId': taxiId});
  Future<void> droppedOff(String id, String taxiId) => _send('POST', '/rides/requests/$id/dropoff', {'taxiId': taxiId});
}

class LiveConflict implements Exception {}

List<LatLng> _thin(List<LatLng> pts, int max) {
  if (pts.length <= max) return pts;
  final step = pts.length / (max - 1);
  return [for (var i = 0; i < max - 1; i++) pts[(i * step).floor()], pts.last];
}
