import 'dart:convert';

import 'package:http/http.dart' as http;

/// Client du serveur Taxi Maroc (dossier backend/).
class Api {
  Api({String? baseUrl}) : baseUrl = baseUrl ?? const String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:3000');
  final String baseUrl;

  Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (res.statusCode >= 400) throw Exception(res.body);
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> estimatePetitTaxi({
    required Map<String, double> depart,
    required Map<String, double> destination,
    required bool seul,
    required bool premium,
  }) async =>
      await _post('/fares/petit-taxi', {
        'depart': depart,
        'destination': destination,
        'mode': seul ? 'seul' : 'partage',
        'categorie': premium ? 'premium' : 'standard',
      }) as Map<String, dynamic>;

  Future<List<dynamic>> findTaxis({
    required Map<String, double> depart,
    required Map<String, double> destination,
    required bool seul,
    required bool premium,
  }) async =>
      await _post('/rides/match', {
        'depart': depart,
        'destination': destination,
        'mode': seul ? 'seul' : 'partage',
        'passagers': 1,
        if (premium) 'categorie': 'premium',
      }) as List<dynamic>;

  Future<void> complain({String? taxiId, required String motif, String? message}) =>
      _post('/complaints', {'taxiId': taxiId, 'motif': motif, 'message': message});
}
