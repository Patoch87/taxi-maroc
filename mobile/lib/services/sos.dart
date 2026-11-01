import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'account.dart';
import 'live.dart';

/// Envoi de l'alerte SOS : ouverture, séquences vidéo (avec le son), position, fin.
/// Le serveur Bab Taxi (centre de sécurité, /sos/centre) reçoit tout en direct et alerte les autorités
/// compétentes ; aucun raccordement direct à la police n'existe encore.
abstract class SosApi {
  Future<String> open({String? taxiId, String? name, String? accountId, LatLng? position});
  Future<void> segment(String id, int index, Uint8List bytes, String type);
  Future<void> position(String id, LatLng p);
  Future<void> end(String id);
}

/// Serveur Bab Taxi (test réel).
class ServerSosApi implements SosApi {
  ServerSosApi({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _base = baseUrl;
  final http.Client _client;
  final String? _base;

  String get base => (_base ?? live.url).replaceAll(RegExp(r'/+$'), '');

  Future<Map<String, dynamic>> _post(String path, Object? body, {Map<String, String>? headers, Duration? timeout}) async {
    final res = await _client
        .post(Uri.parse('$base$path'),
            headers: headers ?? {'Content-Type': 'application/json'},
            body: body is Uint8List ? body : jsonEncode(body ?? {}))
        .timeout(timeout ?? const Duration(seconds: 15));
    if (res.statusCode >= 400) throw Exception('HTTP ${res.statusCode}');
    return res.body.isEmpty ? {} : jsonDecode(res.body) as Map<String, dynamic>;
  }

  @override
  Future<String> open({String? taxiId, String? name, String? accountId, LatLng? position}) async {
    final r = await _post('/sos', {
      if (accountId != null) 'passagerId': accountId,
      if (name != null) 'nom': name,
      if (taxiId != null) 'taxiId': taxiId,
      if (position != null) ...{'lat': position.latitude, 'lng': position.longitude},
    });
    return r['id'] as String;
  }

  @override
  Future<void> segment(String id, int index, Uint8List bytes, String type) =>
      _post('/sos/$id/segments', bytes,
          headers: {'Content-Type': type, 'x-segment': '$index'}, timeout: const Duration(seconds: 60));

  @override
  Future<void> position(String id, LatLng p) => _post('/sos/$id/position', {'lat': p.latitude, 'lng': p.longitude});

  @override
  Future<void> end(String id) => _post('/sos/$id/end', null);
}

/// Mode démo : rien ne quitte le téléphone, l'envoi est simulé (et signalé comme tel à l'écran).
class DemoSosApi implements SosApi {
  DemoSosApi({this.delay = const Duration(milliseconds: 400)});
  final Duration delay;

  @override
  Future<String> open({String? taxiId, String? name, String? accountId, LatLng? position}) async {
    await Future<void>.delayed(delay);
    return 'demo-${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  Future<void> segment(String id, int index, Uint8List bytes, String type) => Future<void>.delayed(delay);

  @override
  Future<void> position(String id, LatLng p) async {}

  @override
  Future<void> end(String id) async {}
}

/// Une alerte SOS en cours : l'écran SOS lui donne chaque séquence filmée, elle les envoie dans l'ordre.
/// Une séquence qui échoue (réseau) est réessayée à la suivante, sans bloquer le tournage.
class SosSession extends ChangeNotifier {
  SosSession({SosApi? api, bool? demo})
      : demo = demo ?? !live.enabled,
        _api = api ?? ((demo ?? !live.enabled) ? DemoSosApi() : ServerSosApi());

  final SosApi _api;

  /// Envoi simulé (mode démo) : affiché clairement à l'écran.
  final bool demo;

  String? _id;
  String? get id => _id;

  /// Alerte reçue par le centre de sécurité (ou simulée en démo).
  bool get opened => _id != null;

  int _sent = 0;
  int get sent => _sent;

  int _bytes = 0;
  int get bytes => _bytes;

  bool _failed = false;

  /// Dernier envoi en échec (pas de réseau) : l'écran l'affiche, les séquences attendent.
  bool get failed => _failed;

  bool _ended = false;
  bool get ended => _ended;

  final DateTime startedAt = DateTime.now();
  final _queue = <(int, Uint8List, String)>[];
  int _next = 0;
  bool _sending = false;
  Future<void>? _opening;

  /// Ouvre l'alerte avec la position (réessaie tant que le serveur ne répond pas).
  Future<void> start({String? taxiId, LatLng? position}) {
    final a = accountStore.account;
    return _opening ??= () async {
      for (var attempt = 0; _id == null && !_ended && attempt < 5; attempt++) {
        try {
          _id = await _api.open(
            taxiId: taxiId,
            accountId: a?.id,
            name: a == null ? null : '${a.firstName} ${a.lastName}',
            position: position,
          );
          _failed = false;
        } catch (_) {
          _failed = true;
          notifyListeners();
          await Future<void>.delayed(Duration(seconds: 2 * (attempt + 1)));
        }
      }
      notifyListeners();
      await _flush();
    }();
  }

  /// Une séquence vidéo terminée (quelques secondes, avec le son) à envoyer.
  void addSegment(Uint8List bytes, {String type = 'video/mp4'}) {
    if (bytes.isEmpty) return;
    _queue.add((_next++, bytes, type));
    _flush();
  }

  Future<void> updatePosition(LatLng p) async {
    final id = _id;
    if (id == null || _ended) return;
    try {
      await _api.position(id, p);
    } catch (_) {}
  }

  Future<void> _flush() async {
    if (_sending || _id == null) return;
    _sending = true;
    try {
      while (_queue.isNotEmpty) {
        final (index, bytes, type) = _queue.first;
        try {
          await _api.segment(_id!, index, bytes, type);
          _queue.removeAt(0);
          _sent++;
          _bytes += bytes.length;
          _failed = false;
        } catch (_) {
          _failed = true;
          break;
        }
        notifyListeners();
      }
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  /// « Je suis en sécurité » : la dernière séquence part, puis l'alerte est close.
  Future<void> stop() async {
    if (_ended) return;
    await _flush();
    _ended = true;
    notifyListeners();
    final id = _id;
    if (id != null) {
      try {
        await _api.end(id);
      } catch (_) {}
    }
  }
}

/// Type de fichier d'une séquence selon son extension (Android : mp4 ; iPhone : mp4 ou mov).
String videoMime(String path) => path.toLowerCase().endsWith('.mov') ? 'video/quicktime' : 'video/mp4';
