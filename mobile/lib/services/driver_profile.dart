import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'live.dart';

/// Application compilée pour les chauffeurs (« Bab Taxi Chauffeur ») : --dart-define=BAB_APP=chauffeur.
const babApp = String.fromEnvironment('BAB_APP');
const isDriverApp = babApp == 'chauffeur';

/// Application passager de déploiement : pas de mode chauffeur (il est dans « Bab Taxi Chauffeur »).
const isRiderApp = isProduction && !isDriverApp;

/// Lien de téléchargement de l'application chauffeur.
const driverAppLink = 'https://github.com/Patoch87/taxi-maroc/releases/latest/download/bab-taxi-chauffeur.apk';

/// Pièces du dossier, dans l'ordre de l'écran (mêmes noms que sur le serveur).
const driverPieces = ['photo', 'cinRecto', 'cinVerso', 'permis', 'cartePro', 'casier', 'vehicule'];

enum DriverStatus { none, pending, approved, rejected }

DriverStatus _status(String? s) => switch (s) {
      'en_attente' => DriverStatus.pending,
      'valide' => DriverStatus.approved,
      'refuse' => DriverStatus.rejected,
      _ => DriverStatus.none,
    };

/// Dossier du chauffeur : saisi dans l'application, envoyé au serveur, vérifié par Bab Taxi.
class DriverProfile {
  DriverProfile({
    this.cin = '',
    this.license = '',
    this.proCard = '',
    this.grand = false,
    this.taxiNumber = '',
    this.plate = '',
    this.city = 'Casablanca',
    List<String>? languages,
    Map<String, String>? pieces,
    this.status = DriverStatus.none,
    this.reason,
  })  : languages = languages ?? ['dr', 'fr'],
        pieces = pieces ?? {};

  String cin;
  String license;
  String proCard;
  bool grand;
  String taxiNumber;
  String plate;
  String city;
  List<String> languages;

  /// Pièce -> identifiant du fichier envoyé au serveur.
  Map<String, String> pieces;
  DriverStatus status;

  /// Motif du refus, écrit par Bab Taxi.
  String? reason;

  bool get complete =>
      cin.trim().isNotEmpty &&
      license.trim().isNotEmpty &&
      proCard.trim().isNotEmpty &&
      taxiNumber.trim().isNotEmpty &&
      plate.trim().isNotEmpty &&
      driverPieces.every(pieces.containsKey);

  Map<String, dynamic> toJson() => {
        'cin': cin,
        'license': license,
        'proCard': proCard,
        'grand': grand,
        'taxiNumber': taxiNumber,
        'plate': plate,
        'city': city,
        'languages': languages,
        'pieces': pieces,
        'status': status.name,
        'reason': reason,
      };

  static DriverProfile fromJson(Map<String, dynamic> j) => DriverProfile(
        cin: j['cin'] as String? ?? '',
        license: j['license'] as String? ?? '',
        proCard: j['proCard'] as String? ?? '',
        grand: j['grand'] as bool? ?? false,
        taxiNumber: j['taxiNumber'] as String? ?? '',
        plate: j['plate'] as String? ?? '',
        city: j['city'] as String? ?? 'Casablanca',
        languages: (j['languages'] as List?)?.whereType<String>().toList(),
        pieces: (j['pieces'] as Map?)?.map((k, v) => MapEntry(k as String, v as String)),
        status: DriverStatus.values.firstWhere((s) => s.name == j['status'], orElse: () => DriverStatus.none),
        reason: j['reason'] as String?,
      );

  /// Corps envoyé au serveur (noms du serveur).
  Map<String, dynamic> toServer(String firstName, String lastName) => {
        'prenom': firstName,
        'nom': lastName,
        'ville': city,
        'cin': cin.trim(),
        'permis': license.trim(),
        'cartePro': proCard.trim(),
        'taxiType': grand ? 'grand' : 'petit',
        'taxiNumero': taxiNumber.trim(),
        'plaque': plate.trim(),
        'langues': languages,
        'pieces': pieces,
      };
}

/// Dossier gardé sur le téléphone (brouillon compris) et synchronisé avec le serveur.
class DriverProfileStore extends ChangeNotifier {
  static const _key = 'driver_profile_v1';
  DriverProfile profile = DriverProfile();
  bool loaded = false;

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_key);
      if (raw != null) profile = DriverProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {}
    loaded = true;
    notifyListeners();
  }

  Future<void> save() async {
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_key, jsonEncode(profile.toJson()));
    } catch (_) {}
  }

  /// État du dossier sur le serveur (validé, refusé...). Renvoie faux si le serveur ne répond pas.
  Future<bool> refresh(DriverApi api, String id) async {
    try {
      final j = await api.status(id);
      if (j == null) {
        // Aucun dossier sur le serveur (nouvelle base, autre téléphone) : à envoyer.
        if (profile.status != DriverStatus.none) profile.status = DriverStatus.none;
      } else {
        profile
          ..status = _status(j['statut'] as String?)
          ..reason = j['motif'] as String?;
        if (profile.plate.isEmpty) profile.plate = j['plaque'] as String? ?? '';
        if (profile.taxiNumber.isEmpty) profile.taxiNumber = j['taxiNumero'] as String? ?? '';
        profile.grand = j['taxiType'] == 'grand';
      }
      await save();
      return true;
    } catch (_) {
      return false;
    }
  }
}

final driverProfileStore = DriverProfileStore();

/// Appels du serveur pour le dossier chauffeur.
class DriverApi {
  DriverApi({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _base = baseUrl;
  final http.Client _client;
  final String? _base;

  String get base => (_base ?? live.url).replaceAll(RegExp(r'/+$'), '');

  /// Envoie une photo (jpeg) ; renvoie l'identifiant de la pièce.
  Future<String> uploadPiece(String id, String piece, Uint8List jpeg) async {
    final res = await _client
        .post(Uri.parse('$base/chauffeurs/$id/pieces/$piece'), headers: {'Content-Type': 'image/jpeg'}, body: jpeg)
        .timeout(const Duration(seconds: 60));
    if (res.statusCode >= 400) throw Exception('HTTP ${res.statusCode}');
    return (jsonDecode(res.body) as Map<String, dynamic>)['id'] as String;
  }

  Future<Map<String, dynamic>> submit(String id, Map<String, dynamic> body) async {
    final res = await _client
        .post(Uri.parse('$base/chauffeurs/$id/dossier'), headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))
        .timeout(const Duration(seconds: 30));
    if (res.statusCode >= 400) throw Exception(res.body);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// null : aucun dossier sur le serveur.
  Future<Map<String, dynamic>?> status(String id) async {
    final res = await _client.get(Uri.parse('$base/chauffeurs/$id')).timeout(const Duration(seconds: 15));
    if (res.statusCode == 404) return null;
    if (res.statusCode >= 400) throw Exception('HTTP ${res.statusCode}');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
