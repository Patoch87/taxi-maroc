import 'package:flutter/material.dart';

import '../main.dart';
import '../services/api.dart';
import '../services/location.dart';
import '../services/places.dart';
import 'complaint_screen.dart';

/// Écran passager : destination finale, petit ou grand taxi, seul ou partagé, premium.
class PassengerScreen extends StatefulWidget {
  const PassengerScreen({super.key});

  @override
  State<PassengerScreen> createState() => _PassengerScreenState();
}

class _PassengerScreenState extends State<PassengerScreen> {
  final _api = Api();
  Place? _destination;
  bool _petitTaxi = true;
  bool _seul = false;
  bool _premium = false;
  String? _message;
  Map<String, dynamic>? _estimate;
  String? _taxiId;

  Future<void> _run(Future<void> Function(Map<String, double> depart) action) async {
    if (_destination == null) return;
    try {
      await action(await currentPosition());
    } catch (_) {
      setState(() => _message = s.t('error'));
    }
  }

  Future<void> _estimatePrice() => _run((depart) async {
        final e = await _api.estimatePetitTaxi(
            depart: depart, destination: _destination!.toJson(), seul: _seul, premium: _premium);
        setState(() => _estimate = e);
      });

  Future<void> _findTaxi() => _run((depart) async {
        final taxis = await _api.findTaxis(
            depart: depart, destination: _destination!.toJson(), seul: _seul, premium: _premium);
        setState(() {
          _taxiId = taxis.isEmpty ? null : taxis.first['taxiId'] as String;
          _message = taxis.isEmpty ? s.t('noTaxi') : '${s.t('taxiFound')} : $_taxiId';
        });
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(s.t('iAmPassenger'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: true, label: Text(s.t('petitTaxi'))),
              ButtonSegment(value: false, label: Text(s.t('grandTaxi'))),
            ],
            selected: {_petitTaxi},
            onSelectionChanged: (v) => setState(() => _petitTaxi = v.first),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<Place>(
            decoration: InputDecoration(labelText: s.t('destination'), border: const OutlineInputBorder()),
            initialValue: _destination,
            items: casablancaPlaces.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
            onChanged: (p) => setState(() => _destination = p),
          ),
          const SizedBox(height: 16),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: false, label: Text(s.t('shared'))),
              ButtonSegment(value: true, label: Text(s.t('alone'))),
            ],
            selected: {_seul},
            onSelectionChanged: (v) => setState(() => _seul = v.first),
          ),
          SwitchListTile(
            title: Text(s.t('premium')),
            value: _premium,
            onChanged: (v) => setState(() => _premium = v),
          ),
          if (!_petitTaxi)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              // TODO: réservation de places par ligne (endpoint /fares/grand-taxi).
              child: Text('Grand taxi : lignes Casablanca → Mohammedia, Berrechid, El Jadida (bientôt).'),
            ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _estimatePrice, child: Text(s.t('estimate'))),
          if (_estimate != null) ...[
            const SizedBox(height: 8),
            Text('${_estimate!['montantMad']} DH', style: Theme.of(context).textTheme.headlineMedium),
            Text(s.t('priceInfo')),
          ],
          const SizedBox(height: 16),
          FilledButton(onPressed: _findTaxi, child: Text(s.t('findTaxi'))),
          if (_message != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_message!)),
          const SizedBox(height: 24),
          TextButton.icon(
            icon: const Icon(Icons.report),
            label: Text(s.t('complain')),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => ComplaintScreen(taxiId: _taxiId))),
          ),
          TextButton.icon(
            icon: const Icon(Icons.sos, color: Colors.red),
            label: Text(s.t('sos'), style: const TextStyle(color: Colors.red)),
            onPressed: () {}, // TODO: alerte SOS au serveur et partage de la position.
          ),
        ],
      ),
    );
  }
}
