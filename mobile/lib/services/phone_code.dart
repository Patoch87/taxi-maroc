import 'account.dart';
import 'live.dart';

/// Vérification du numéro par code SMS.
///
/// Test réel : le serveur envoie un vrai SMS (Twilio) et vérifie le code ; sans Twilio, il renvoie un code
/// de test affiché à l'écran. Démo (sans serveur) : code [demoSmsCode], vérifié sur le téléphone.
class PhoneCodeVerifier {
  PhoneCodeVerifier({LiveApi? api}) : _api = api;
  final LiveApi? _api;

  /// Code demandé (null tant que « Recevoir un code » n'a pas été touché).
  SmsCode? sent;
  String? _phone;
  bool _server = false;

  /// Dernier code vérifié et son résultat.
  String? _checked;
  bool? _result;

  bool get verified => _result == true;

  /// Code complet saisi mais refusé.
  bool get wrong => _result == false;

  Future<SmsCode> send(String phone) async {
    _phone = phone;
    _checked = null;
    _result = null;
    // Serveur en train de se réveiller : on l'attend plutôt que de passer en démo.
    for (var i = 0; i < 200 && live.connecting; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    if (live.enabled) {
      _server = true;
      return sent = await (_api ?? LiveApi()).sendCode(phone);
    }
    _server = false;
    return sent = const SmsCode(realSms: false, length: 4, testCode: demoSmsCode);
  }

  /// Vérifie le code dès qu'il a la bonne longueur ; renvoie true quand il est accepté.
  Future<bool> check(String code) async {
    final c = sent, phone = _phone;
    final v = code.trim();
    if (c == null || phone == null || v.length < c.length) {
      _checked = null;
      _result = null;
      return false;
    }
    if (v == _checked && _result != null) return _result!;
    _checked = v;
    if (!_server) return _result = v == c.testCode;
    try {
      _result = await (_api ?? LiveApi()).checkCode(phone, v);
    } catch (_) {
      _result = false;
    }
    // Le passager a pu continuer à taper pendant la vérification.
    if (_checked != v) return false;
    return _result!;
  }
}
