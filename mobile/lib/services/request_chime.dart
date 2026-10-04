import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Une fenêtre de sécurité (SOS) est ouverte : aucun son ni annonce pendant ce temps.
bool sosActive = false;

/// Annonce en arabe d'une nouvelle demande : « طلب جديد، الوجهة: موروكو مول ».
String requestAnnouncementAr(String destination) => 'طلب جديد، الوجهة: $destination';

/// Rappel en arabe des feux de détresse avant de prendre un passager.
const hazardAnnouncementAr = 'اقتربت من الراكب، شغّل أضواء التنبيه';

/// Distance à laquelle le chauffeur est invité à allumer ses feux de détresse.
const hazardDistanceM = 50.0;

/// Sons et annonces côté chauffeur : un petit son doux par nouvelle demande, avec une légère vibration,
/// et, quand le taxi est vide, la destination lue en arabe. Avec des passagers à bord : le son seulement.
/// La logique est séparée du lecteur pour être testée (voir test/request_chime_test.dart).
class RequestChime {
  RequestChime({
    Future<void> Function()? play,
    Future<void> Function()? haptic,
    Future<void> Function(String text)? speak,
    Future<void> Function()? stopSpeech,
    this.speechDelay = const Duration(milliseconds: 900),
  })  : _play = play ?? _playAsset,
        _haptic = haptic ?? HapticFeedback.lightImpact,
        _speak = speak ?? _speakArabic,
        _stopSpeech = stopSpeech ?? _stopTts;

  final Future<void> Function() _play;
  final Future<void> Function() _haptic;
  final Future<void> Function(String text) _speak;
  final Future<void> Function() _stopSpeech;

  /// Le son passe d'abord, la voix ensuite.
  final Duration speechDelay;
  Object? _last;
  Object? _speaking;
  Timer? _speechTimer;

  /// À appeler quand une demande s'affiche. Renvoie true si le son a été joué.
  /// [speakText] : texte lu à voix haute si [voice] est activé et que le taxi est vide ([empty]).
  bool onRequest(
    Object? request, {
    required bool enabled,
    bool voice = false,
    bool empty = false,
    String? speakText,
  }) {
    if (request == null || identical(request, _last)) return false;
    _last = request;
    return _alert(request, enabled: enabled, voice: voice, empty: empty, speakText: speakText);
  }

  /// Rappel (feux de détresse) : même son, et même règle pour la voix.
  bool alert(Object key, {required bool enabled, bool voice = false, bool empty = false, String? speakText}) =>
      _alert(key, enabled: enabled, voice: voice, empty: empty, speakText: speakText);

  bool _alert(Object key, {required bool enabled, bool voice = false, bool empty = false, String? speakText}) {
    if (!enabled || sosActive) return false;
    _play().catchError((_) {});
    _haptic().catchError((_) {});
    if (voice && empty && speakText != null) {
      _speaking = key;
      _speechTimer?.cancel();
      _speechTimer = Timer(speechDelay, () {
        if (identical(_speaking, key) && !sosActive) _speak(speakText).catchError((_) {});
      });
    }
    return true;
  }

  /// Demande acceptée, refusée ou expirée : on arrête de parler.
  void cancel() {
    _speechTimer?.cancel();
    if (_speaking == null) return;
    _speaking = null;
    _stopSpeech().catchError((_) {});
  }

  static AudioPlayer? _player;
  static FlutterTts? _tts;

  /// Son de notification : il suit le volume des notifications et le mode silencieux du téléphone
  /// (Android : flux notification ; iOS : catégorie « ambient », coupée par l'interrupteur silencieux).
  static Future<void> _playAsset() async {
    final p = _player ??= AudioPlayer()
      ..setAudioContext(AudioContext(
        android: const AudioContextAndroid(
          usageType: AndroidUsageType.notificationEvent,
          contentType: AndroidContentType.sonification,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
        iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
      ));
    await p.play(AssetSource('sounds/request_chime.wav'), volume: .6);
  }

  /// Voix arabe : ar-MA, sinon ar-SA, sinon arabe ; volume et débit modérés.
  static Future<void> _speakArabic(String text) async {
    final tts = _tts ??= FlutterTts();
    for (final lang in ['ar-MA', 'ar-SA', 'ar']) {
      if (await tts.isLanguageAvailable(lang) == true) {
        await tts.setLanguage(lang);
        break;
      }
    }
    await tts.setVolume(.7);
    await tts.setSpeechRate(.45);
    await tts.speak(text);
  }

  static Future<void> _stopTts() async => _tts?.stop();
}

/// Rappel des feux de détresse : une seule fois par prise en charge, quand le taxi passe à 50 m ou moins.
class PickupAlerts {
  final _shown = <Object>{};

  /// Renvoie true quand il faut afficher le rappel pour [pickup] à [meters] du point de prise en charge.
  bool check(Object pickup, double meters) {
    if (meters > hazardDistanceM || _shown.contains(pickup)) return false;
    _shown.add(pickup);
    return true;
  }
}
