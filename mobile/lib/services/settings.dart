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
  bool _voiceAnnounce = true;
  AutoShare _autoShare = AutoShare.night;
  final List<TrustedContact> _contacts = [];

  /// Mode senior : accueil simplifié, très gros textes, trois gros boutons.
  bool get senior => _senior;
  set senior(bool v) => _set(() => _senior = v);

  /// Passager malvoyant : le chauffeur est prévenu, et les étapes sont annoncées à voix haute.
  bool get lowVision => _lowVision;
  set lowVision(bool v) => _set(() => _lowVision = v);

  /// Annonces vocales : taxi accepté, minutes restantes, arrivée.
  bool get voiceAnnounce => _voiceAnnounce;
  set voiceAnnounce(bool v) => _set(() => _voiceAnnounce = v);

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
        _voiceAnnounce = true;
        _autoShare = AutoShare.night;
        _contacts.clear();
      });

  void _set(VoidCallback change) {
    change();
    notifyListeners();
  }
}

final settings = AppSettings();
