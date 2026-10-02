import 'package:flutter/material.dart';

import '../main.dart';

/// Écran chauffeur simplifié : gros boutons pour ne pas distraire la conduite.
/// TODO : envoyer la position et l'itinéraire au serveur (PUT /taxis/:id/route)
/// et afficher sur la carte les passagers qui vont dans la même direction.
class DriverScreen extends StatefulWidget {
  const DriverScreen({super.key});

  @override
  State<DriverScreen> createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen> {
  bool _available = false;
  int _passengers = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(s.t('iAmDriver'))),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 96,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: _available ? Colors.green : Colors.grey),
                  onPressed: () => setState(() => _available = !_available),
                  child: Text(_available ? s.t('available') : s.t('busy'), style: const TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filled(
                      iconSize: 40,
                      onPressed: _passengers > 0 ? () => setState(() => _passengers--) : null,
                      icon: const Icon(Icons.remove)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text('$_passengers / 3', style: const TextStyle(fontSize: 36)),
                  ),
                  IconButton.filled(
                      iconSize: 40,
                      onPressed: _passengers < 3 ? () => setState(() => _passengers++) : null,
                      icon: const Icon(Icons.add)),
                ],
              ),
            ],
          ),
        ),
      );
}
