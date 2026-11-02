import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taxi_maroc/services/driver_profile.dart';

void main() {
  test('dossier complet seulement avec toutes les pièces et les numéros', () {
    final p = DriverProfile(cin: 'BE1', license: 'P1', proCard: 'C1', taxiNumber: '2417', plate: '12345-A-6');
    expect(p.complete, isFalse);
    for (final piece in driverPieces) {
      p.pieces[piece] = 'chauffeur-x-$piece-1';
    }
    expect(p.complete, isTrue);
    final body = p.toServer('Hamid', 'Mansouri');
    expect(body['taxiType'], 'petit');
    expect(body['plaque'], '12345-A-6');
    expect((body['pieces'] as Map).length, driverPieces.length);
    // Brouillon gardé sur le téléphone.
    final back = DriverProfile.fromJson(jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>);
    expect(back.complete, isTrue);
  });

  test('état du dossier lu sur le serveur', () async {
    final api = DriverApi(
      baseUrl: 'http://serveur',
      client: MockClient((r) async => r.url.path == '/chauffeurs/c1'
          ? http.Response(jsonEncode({'statut': 'refuse', 'motif': 'Casier illisible', 'plaque': 'P', 'taxiType': 'grand'}), 200)
          : http.Response('', 404)),
    );
    final store = DriverProfileStore();
    expect(await store.refresh(api, 'c1'), isTrue);
    expect(store.profile.status, DriverStatus.rejected);
    expect(store.profile.reason, 'Casier illisible');
    expect(store.profile.grand, isTrue);
    expect(await store.refresh(api, 'autre'), isTrue);
    expect(store.profile.status, DriverStatus.none);
  });
}
