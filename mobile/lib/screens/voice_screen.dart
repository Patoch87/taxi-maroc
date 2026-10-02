import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../main.dart';
import '../services/api.dart';
import '../services/location.dart';
import '../services/places.dart';

/// Commande vocale pour les personnes aveugles ou malvoyantes.
/// Un seul grand bouton : on dit la destination, l'application répond à voix haute.
class VoiceScreen extends StatefulWidget {
  const VoiceScreen({super.key});

  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen> {
  final _speech = SpeechToText();
  final _tts = FlutterTts();
  final _api = Api();
  String _status = '';

  String get _locale => {'fr': 'fr-FR', 'ar': 'ar-MA', 'en': 'en-US'}[langNotifier.value]!;

  Future<void> _say(String text) async {
    setState(() => _status = text);
    await _tts.setLanguage(_locale);
    await _tts.speak(text);
  }

  Future<void> _listen() async {
    if (!await _speech.initialize()) {
      await _say(s.t('error'));
      return;
    }
    await _say(s.t('speakNow'));
    await _speech.listen(
      listenOptions: SpeechListenOptions(localeId: _locale.replaceAll('-', '_')),
      onResult: (r) {
        if (r.finalResult) _handle(r.recognizedWords);
      },
    );
  }

  Future<void> _handle(String words) async {
    final place = findPlace(words);
    if (place == null) {
      await _say('$words ? ${s.t('speakNow')}');
      return;
    }
    try {
      final depart = await currentPosition();
      final e = await _api.estimatePetitTaxi(
          depart: depart, destination: place.toJson(), seul: false, premium: false);
      final taxis = await _api.findTaxis(
          depart: depart, destination: place.toJson(), seul: false, premium: false);
      final found = taxis.isEmpty ? s.t('noTaxi') : s.t('taxiFound');
      await _say('${place.name}. ${e['montantMad']} dirhams. $found');
    } catch (_) {
      await _say(s.t('error'));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(s.t('voiceMode'))),
        body: Semantics(
          button: true,
          label: s.t('speakNow'),
          child: InkWell(
            onTap: _listen,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.mic, size: 160),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_status, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
