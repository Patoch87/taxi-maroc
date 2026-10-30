import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../main.dart';

/// Reconnaissance vocale et lecture à voix haute, dans la langue de l'application.
class Voice {
  final _stt = SpeechToText();
  final _tts = FlutterTts();
  bool _ready = false;

  /// Micro prêt (permission accordée). Sans réponse après 20 secondes : pas de micro, on réessaiera.
  Future<bool> init() async {
    if (_ready) return true;
    try {
      _ready = await _stt
          .initialize(
            // Fin d'écoute (silence, temps écoulé ou erreur) : la réponse attendue par [hear] est rendue.
            onStatus: (status) {
              if (status == SpeechToText.doneStatus || status == SpeechToText.notListeningStatus) _endHearing();
            },
            onError: (_) => _endHearing(),
          )
          .timeout(const Duration(seconds: 20), onTimeout: () => false);
    } catch (_) {
      _ready = false;
    }
    return _ready;
  }

  Future<void> say(String text) async {
    try {
      await _tts.setLanguage(s.speechLocale);
      await _tts.awaitSpeakCompletion(true);
      await _tts.speak(text);
    } catch (_) {}
  }

  /// Écoute une phrase et renvoie le texte reconnu (ou null).
  Future<void> listen({required void Function(String words, bool done) onResult}) async {
    if (!await init()) return;
    await _stt.listen(
      listenOptions: SpeechListenOptions(localeId: s.speechLocale.replaceAll('-', '_')),
      onResult: (r) => onResult(r.recognizedWords, r.finalResult),
    );
  }

  Completer<String>? _hearing;
  String _heard = '';

  void _endHearing() {
    final c = _hearing;
    _hearing = null;
    if (c != null && !c.isCompleted) c.complete(_heard);
  }

  /// Écoute une seule réponse : rend ce qui a été dit après un court silence, ou '' si rien n'a été entendu.
  /// [onWords] reçoit les mots au fur et à mesure (affichés à l'écran).
  Future<String> hear({void Function(String words)? onWords}) async {
    if (!await init()) return '';
    _endHearing();
    _heard = '';
    final c = _hearing = Completer<String>();
    try {
      await _stt.listen(
        listenOptions: SpeechListenOptions(
          localeId: s.speechLocale.replaceAll('-', '_'),
          listenFor: const Duration(seconds: 12),
          pauseFor: const Duration(seconds: 3),
        ),
        onResult: (r) {
          _heard = r.recognizedWords;
          onWords?.call(_heard);
          if (r.finalResult) _endHearing();
        },
      );
    } catch (_) {
      _endHearing();
    }
    return c.future.timeout(const Duration(seconds: 16), onTimeout: () {
      _stt.stop().ignore();
      return _heard;
    });
  }

  Future<void> stop() async {
    try {
      await _stt.stop();
    } catch (_) {}
    _endHearing();
  }

  /// Coupe la voix en cours (le passager a déjà répondu en touchant l'écran).
  Future<void> silence() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
