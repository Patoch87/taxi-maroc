import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import 'account.dart';

/// Ce que le téléphone sait vérifier : empreinte, visage, ou les deux.
class BiometricSupport {
  const BiometricSupport({this.fingerprint = false, this.face = false, this.other = false});
  final bool fingerprint;
  final bool face;

  /// Capteur « fort » ou « faible » sans type précis (Android ne dit pas toujours lequel).
  final bool other;

  bool get any => fingerprint || face || other;
  static const none = BiometricSupport();
}

/// Lecteur d'empreinte et reconnaissance faciale du téléphone (remplacé dans les tests).
abstract class BiometricDevice {
  Future<BiometricSupport> support();
  Future<bool> authenticate(String reason);
}

class LocalBiometricDevice implements BiometricDevice {
  final _auth = LocalAuthentication();

  @override
  Future<BiometricSupport> support() async {
    try {
      if (!await _auth.isDeviceSupported()) return BiometricSupport.none;
      final types = await _auth.getAvailableBiometrics();
      return BiometricSupport(
        fingerprint: types.contains(BiometricType.fingerprint),
        face: types.contains(BiometricType.face),
        other: types.contains(BiometricType.strong) || types.contains(BiometricType.weak) || types.contains(BiometricType.iris),
      );
    } catch (_) {
      // Version web, ou téléphone sans capteur.
      return BiometricSupport.none;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(localizedReason: reason, biometricOnly: true, persistAcrossBackgrounding: true);
    } catch (_) {
      return false;
    }
  }
}

/// Connexion par empreinte ou visage : à l'ouverture de l'application, le compte enregistré sur le
/// téléphone s'ouvre seulement après la vérification (une course en cours n'est jamais interrompue).
/// Le code SMS reste possible. Rien de biométrique ne quitte le téléphone : c'est le système qui vérifie.
class BiometricLock extends ChangeNotifier {
  BiometricLock({BiometricDevice? device}) : _device = device;

  BiometricDevice? _device;
  BiometricDevice get device => _device ??= LocalBiometricDevice();
  set device(BiometricDevice d) => _device = d;

  static const _key = 'biometricLogin';

  bool _enabled = false;
  bool get enabled => _enabled;

  bool _locked = false;

  /// Accueil masqué par l'écran de connexion.
  bool get locked => _locked && _enabled && accountStore.account != null;

  BiometricSupport _support = BiometricSupport.none;
  BiometricSupport get support => _support;

  /// Lancement : réglage enregistré, capteurs du téléphone, verrouillage s'il y a un compte.
  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      _enabled = p.getBool(_key) ?? false;
    } catch (_) {}
    _support = await device.support();
    _locked = _enabled && accountStore.account != null;
    notifyListeners();
  }

  Future<void> refreshSupport() async {
    _support = await device.support();
    notifyListeners();
  }

  /// Active la connexion biométrique après une vérification réussie (sinon reste désactivée).
  Future<bool> enable() async {
    if (!await device.authenticate(s.t('bioReason'))) return false;
    await _save(true);
    return true;
  }

  Future<void> disable() => _save(false);

  Future<void> _save(bool v) async {
    _enabled = v;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_key, v);
    } catch (_) {}
  }

  /// Écran de connexion : empreinte ou visage.
  Future<bool> unlock() async {
    final ok = await device.authenticate(s.t('bioReason'));
    if (ok) unlocked();
    return ok;
  }

  /// Ouverture par le code SMS (ou après une vérification réussie).
  void unlocked() {
    _locked = false;
    notifyListeners();
  }

  /// Verrouille comme au lancement (tests).
  @visibleForTesting
  void lock() {
    _locked = true;
    notifyListeners();
  }

  @visibleForTesting
  void reset() {
    _enabled = false;
    _locked = false;
    _support = BiometricSupport.none;
  }
}

final biometricLock = BiometricLock();
