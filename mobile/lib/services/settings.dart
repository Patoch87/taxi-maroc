import 'package:flutter/foundation.dart';

/// Proche de confiance : appelé en un geste depuis la sécurité, et prévenu des trajets.
class TrustedContact {
  const TrustedContact(this.name, this.phone);
  final String name;
  final String phone;
}

/// Partage automatique des trajets avec les proches.
enum AutoShare { always, night, never }

/// Réglages du passager, gardés en mémoire pendant la session (pas de stockage sur le téléphone).
class AppSettings extends ChangeNotifier {
  static const maxContacts = 5;

  bool _senior = false;
  bool _lowVision = false;
  bool _voiceAnnounce = false;
  bool _requestSound = true;
  bool _requestVoice = false;
  AutoShare _autoShare = AutoShare.night;
  final List<TrustedContact> _contacts = [];

  /// Mode senior : accueil simplifié, très gros textes, trois gros boutons.
  bool get senior => _senior;
  set senior(bool v) => _set(() => _senior = v);

  /// Passager malvoyant : le chauffeur est prévenu, et les annonces vocales sont activées.
  bool get lowVision => _lowVision;
  set lowVision(bool v) => _set(() {
        _lowVision = v;
        if (v) _voiceAnnounce = true;
      });

  /// Annonces vocales (taxi accepté, minutes restantes, arrivée) : désactivées par défaut.
  /// Elles s'activent aussi d'elles-mêmes quand le lecteur d'écran du téléphone (TalkBack) est actif.
  bool get voiceAnnounce => _voiceAnnounce;
  set voiceAnnounce(bool v) => _set(() => _voiceAnnounce = v);

  /// Chauffeur : petit son doux à chaque nouvelle demande sur la route (activé par défaut).
  bool get requestSound => _requestSound;
  set requestSound(bool v) => _set(() => _requestSound = v);

  /// Chauffeur : destination lue en arabe quand le taxi est vide (activé par défaut).
  bool get requestVoice => _requestVoice;
  set requestVoice(bool v) => _set(() => _requestVoice = v);

  AutoShare get autoShare => _autoShare;
  set autoShare(AutoShare v) => _set(() => _autoShare = v);

  List<TrustedContact> get contacts => List.unmodifiable(_contacts);
  bool get canAddContact => _contacts.length < maxContacts;

  bool addContact(TrustedContact c) {
    if (!canAddContact || c.name.trim().isEmpty || c.phone.trim().isEmpty) return false;
    _set(() => _contacts.add(TrustedContact(c.name.trim(), c.phone.trim())));
    return true;
  }

  void removeContact(TrustedContact c) => _set(() => _contacts.remove(c));

  /// Faut-il partager automatiquement un trajet qui commence à [time] ? La nuit : de 21 h à 6 h.
  bool shouldAutoShare(DateTime time) {
    if (_contacts.isEmpty) return false;
    return switch (_autoShare) {
      AutoShare.always => true,
      AutoShare.night => time.hour >= 21 || time.hour < 6,
      AutoShare.never => false,
    };
  }

  /// Remet les réglages par défaut (utilisé par les tests).
  void reset() => _set(() {
        _senior = false;
        _lowVision = false;
        _voiceAnnounce = false;
        _requestSound = true;
        _requestVoice = false;
        _autoShare = AutoShare.night;
        _contacts.clear();
      });

  void _set(VoidCallback change) {
    change();
    notifyListeners();
  }
}

final settings = AppSettings();
