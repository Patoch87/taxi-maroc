import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../main.dart';

/// Reconnaissance vocale et lecture à voix haute, dans la langue de l'application.
class Voice {
  final _stt = SpeechToText();
  final _tts = FlutterTts();
  bool _ready = false;

  Future<bool> init() async {
    if (_ready) return true;
    try {
      _ready = await _stt.initialize();
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

  Future<void> stop() => _stt.stop();
}
