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

  /// Serveur utilisé : activé, adresse connue, et pas en train de se réveiller.
  /// Application de déploiement : le serveur reste utilisé pendant un réveil ou une coupure (les écrans
  /// réessaient), sans jamais basculer sur des taxis simulés.
  bool get enabled => _enabled && url.isNotEmpty && (production || !_connecting);

  /// Application de déploiement (voir [isProduction]) ; modifiable dans les tests.
  bool production = isProduction;
  set enabled(bool v) {
    if (v == _enabled) return;
    _enabled = v;
    if (v) _fellBack = false;
    notifyListeners();
  }

  /// Réveil du serveur (offre gratuite Render : il dort après 15 minutes sans visite).
  bool _connecting = false;
  bool get connecting => _connecting;

  /// Serveur resté injoignable : l'application est passée d'elle-même en mode démo.
  bool _fellBack = false;
  bool get fellBack => _fellBack;

  /// Le passager a vu (ou fermé) l'avis « Mode démo (serveur indisponible) ».
  void dismissFallback() {
    if (!_fellBack) return;
    _fellBack = false;
    notifyListeners();
  }

  /// Premier appel : « Connexion au serveur… » et nouvel essai toutes les [every] pendant [max] au plus ;
  /// sans réponse, passage automatique en mode démo avec un avis, au lieu d'une erreur.
  Future<bool> warmUp({
    LiveApi? api,
    Duration max = const Duration(seconds: 60),
    Duration every = const Duration(seconds: 3),
  }) async {
    if (!_enabled || url.isEmpty || _connecting) return enabled;
    _connecting = true;
    _fellBack = false;
    notifyListeners();
    final client = api ?? LiveApi();
    final end = DateTime.now().add(max);
    var ok = false;
    while (!ok && _enabled) {
      ok = await client.ping();
      // Déploiement : on réessaie jusqu'à ce que le serveur réponde (« Connexion au serveur… » reste affiché).
      if (ok || (!production && !DateTime.now().isBefore(end))) break;
      await Future<void>.delayed(every);
    }
    _connecting = false;
    if (!ok && _enabled && !production) {
      _enabled = false;
      _fellBack = true;
    }
    notifyListeners();
    return ok;
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
    _connecting = false;
    _fellBack = false;
    production = isProduction;
    url = apiUrl;
    notifyListeners();
  }
}

final live = LiveConfig();

/// Réglages publics donnés par le serveur au lancement.
class ServerConfig {
  const ServerConfig({this.whatsapp, this.realSms = false, this.card = false});
  factory ServerConfig.fromJson(Map<String, dynamic> j) => ServerConfig(
        whatsapp: (j['whatsapp'] as String?)?.replaceAll(RegExp(r'\D'), ''),
        realSms: j['sms'] == 'sms',
        card: j['carte'] == true,
      );

  /// Numéro WhatsApp public de Bab Taxi (chiffres avec l'indicatif), absent tant qu'il n'est pas branché.
  final String? whatsapp;
  final bool realSms;

  /// Paiement par carte réel (prestataire branché sur le serveur).
  final bool card;
}

/// Dernière configuration reçue du serveur ([ServerConfig] vide tant qu'il n'a pas répondu).
final serverConfig = ValueNotifier<ServerConfig>(const ServerConfig());

/// Carte bancaire proposée : toujours en démo (paiement simulé), en test réel seulement si le serveur
/// a un vrai prestataire de paiement. Sinon, espèces uniquement.
bool get cardPaymentAvailable => !live.enabled || serverConfig.value.card;

/// Lien « Commander sur WhatsApp » (null tant que le numéro n'est pas configuré sur le serveur).
Uri? whatsappOrderLink(String text) {
  final n = serverConfig.value.whatsapp;
  if (!live.enabled || n == null || n.isEmpty) return null;
  return Uri.parse('https://wa.me/$n?text=${Uri.encodeComponent(text)}');
}

/// Réponse à une demande de code SMS.
class SmsCode {
  const SmsCode({required this.realSms, required this.length, this.testCode});
  factory SmsCode.fromJson(Map<String, dynamic> j) => SmsCode(
        realSms: j['mode'] == 'sms',
        length: (j['longueur'] as num?)?.toInt() ?? 6,
        testCode: j['codeTest'] as String?,
      );
  final bool realSms;
  final int length;

  /// Code à afficher quand aucun SMS n'est envoyé (serveur sans Twilio).
  final String? testCode;
}

Map<String, double> _pt(LatLng p) => {'lat': p.latitude, 'lng': p.longitude};
LatLng _ll(dynamic m) => LatLng((m['lat'] as num).toDouble(), (m['lng'] as num).toDouble());

/// Taxi en ligne vu par le passager.
class LiveTaxi {
  LiveTaxi(this.id, this.name, this.plate, this.grand, this.position, {this.photo = '', this.languages = const []});
  factory LiveTaxi.fromJson(Map<String, dynamic> j) {
    final photo = j['photo'] as String? ?? '';
    return LiveTaxi(j['id'] as String, j['nom'] as String? ?? 'Taxi', j['plaque'] as String? ?? '', j['type'] == 'grand',
        _ll(j['position']),
        // Photo du dossier validé : adresse relative au serveur.
        photo: photo.startsWith('/') ? '${live.url.replaceAll(RegExp(r'/+$'), '')}$photo' : photo,
        languages: (j['langues'] as List?)?.whereType<String>().toList() ?? const []);
  }

  /// Photo du chauffeur (adresse web) et langues parlées (codes dr, ar, zgh, fr, en, es), quand son dossier est validé.
  final String photo;
  final List<String> languages;
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
  LiveRide(this.id, this.status, this.proposedTo, this.taxi,
      {this.pickup, this.drop, this.destinationName = '', this.fare = 0, this.alone = false, this.premium = false,
      this.whatsapp = false});
  factory LiveRide.fromJson(Map<String, dynamic> j) {
    final d = j['demande'] as Map<String, dynamic>?;
    return LiveRide(
      j['id'] as String,
      _status(j['statut'] as String),
      [for (final c in (j['proposeeA'] as List? ?? const [])) c['taxiId'] as String],
      j['taxi'] == null ? null : LiveTaxi.fromJson(j['taxi'] as Map<String, dynamic>),
      pickup: d?['depart'] == null ? null : _ll(d!['depart']),
      drop: d?['destination'] == null ? null : _ll(d!['destination']),
      destinationName: d?['destinationNom'] as String? ?? '',
      fare: (d?['prixMad'] as num?)?.toDouble() ?? 0,
      alone: d?['mode'] == 'seul',
      premium: d?['categorie'] == 'premium',
      whatsapp: d?['source'] == 'whatsapp',
    );
  }
  final String id;
  final LiveStatus status;
  final List<String> proposedTo;
  final LiveTaxi? taxi;

  /// Demande du passager (pour reprendre à l'écran une course commandée ailleurs, ex. sur WhatsApp).
  final LatLng? pickup;
  final LatLng? drop;
  final String destinationName;
  final double fare;
  final bool alone;
  final bool premium;
  final bool whatsapp;
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

  Future<dynamic> _send(String method, String path, [Map<String, dynamic>? body, Duration timeout = _timeout]) async {
    final uri = Uri.parse('$base$path');
    final headers = {'Content-Type': 'application/json'};
    final res = await switch (method) {
      'GET' => _client.get(uri),
      'PUT' => _client.put(uri, headers: headers, body: jsonEncode(body ?? {})),
      'DELETE' => _client.delete(uri),
      _ => _client.post(uri, headers: headers, body: jsonEncode(body ?? {})),
    }
        .timeout(timeout);
    if (res.statusCode == 409) throw LiveConflict();
    if (res.statusCode >= 400) throw Exception('HTTP ${res.statusCode}');
    return res.body.isEmpty ? null : jsonDecode(res.body);
  }

  /// Réglages publics du serveur (numéro WhatsApp, SMS réels, paiement par carte).
  Future<ServerConfig> config() async => ServerConfig.fromJson(await _send('GET', '/config') as Map<String, dynamic>);

  /// Compte enregistré sur le serveur : son numéro relie la commande WhatsApp à l'application.
  Future<void> registerAccount(Account a, String lang) => _send('POST', '/accounts', {
        'id': a.id,
        'phone': a.phone,
        'firstName': a.firstName,
        'lastName': a.lastName,
        'email': a.email,
        'nationality': a.nationality,
        'lang': lang,
      });

  /// Envoie un code de vérification par SMS (ou renvoie le code de test quand le serveur n'a pas de SMS).
  Future<SmsCode> sendCode(String phone) async =>
      SmsCode.fromJson(await _send('POST', '/auth/code', {'phone': phone}) as Map<String, dynamic>);

  Future<bool> checkCode(String phone, String code) async =>
      ((await _send('POST', '/auth/verify', {'phone': phone, 'code': code}) as Map)['ok']) == true;

  Future<bool> ping() async {
    try {
      final r = await _send('GET', '/health', null, const Duration(seconds: 10));
      return r is Map && r['status'] == 'ok';
    } catch (_) {
      return false;
    }
  }

  /// Publicités du serveur (annonceurs fictifs), pour tous les emplacements.
  Future<List<dynamic>> ads() async => await _send('GET', '/ads') as List;

  /// Vue, clic ou bon enregistré sur une publicité (statistiques de l'annonceur, sans donnée personnelle).
  Future<void> adEvent(String id, String type) => _send('POST', '/ads/$id/events', {'type': type});

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
        'passager': {'nom': riderName ?? live.displayName('Passager'), 'id': live.deviceId},
        'source': 'app',
        'destinationNom': destinationName,
        'prixMad': fare,
      }) as Map<String, dynamic>);

  /// Le passager change de destination (avant la prise en charge ou pendant la course).
  Future<void> changeDestination(String id, {required LatLng to, required String destinationName, required double fare}) =>
      _send('POST', '/rides/requests/$id/destination', {
        'destination': _pt(to),
        'destinationNom': destinationName,
        'prixMad': fare,
      });

  Future<LiveRide> ride(String id) async =>
      LiveRide.fromJson(await _send('GET', '/rides/requests/$id') as Map<String, dynamic>);

  /// Course en cours du passager : commandée dans l'application ou sur WhatsApp avec le numéro du compte.
  Future<LiveRide?> activeRide() async {
    final r = await _send('GET', '/passagers/${live.deviceId}/course-en-cours') as Map<String, dynamic>;
    final c = r['course'];
    return c is Map<String, dynamic> ? LiveRide.fromJson(c) : null;
  }

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
