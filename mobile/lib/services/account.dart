import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pays proposés pour la nationalité : code ISO, noms en français, arabe et anglais,
/// et langue de l'application proposée par défaut.
class Country {
  const Country(this.code, this.fr, this.ar, this.en, this.lang);
  final String code;
  final String fr;
  final String ar;
  final String en;
  final String lang;

  /// Drapeau à partir du code ISO (deux lettres régionales).
  String get flag => String.fromCharCodes(code.toUpperCase().codeUnits.map((c) => 0x1F1E6 + c - 0x41));

  /// Nom du pays dans la langue de l'application (anglais pour les autres langues).
  String name(String lang) => switch (lang) {
        'fr' => fr,
        'ar' || 'dr' => ar,
        _ => en,
      };
}

/// Maroc en premier, puis les autres pays par ordre alphabétique (en français).
const countries = [
  Country('MA', 'Maroc', 'المغرب', 'Morocco', 'fr'),
  Country('DZ', 'Algérie', 'الجزائر', 'Algeria', 'ar'),
  Country('DE', 'Allemagne', 'ألمانيا', 'Germany', 'de'),
  Country('GB', 'Royaume-Uni', 'المملكة المتحدة', 'United Kingdom', 'en'),
  Country('SA', 'Arabie saoudite', 'السعودية', 'Saudi Arabia', 'ar'),
  Country('AR', 'Argentine', 'الأرجنتين', 'Argentina', 'es'),
  Country('AU', 'Australie', 'أستراليا', 'Australia', 'en'),
  Country('BE', 'Belgique', 'بلجيكا', 'Belgium', 'fr'),
  Country('BR', 'Brésil', 'البرازيل', 'Brazil', 'pt'),
  Country('CM', 'Cameroun', 'الكاميرون', 'Cameroon', 'fr'),
  Country('CA', 'Canada', 'كندا', 'Canada', 'en'),
  Country('CN', 'Chine', 'الصين', 'China', 'en'),
  Country('KR', 'Corée du Sud', 'كوريا الجنوبية', 'South Korea', 'ko'),
  Country('CI', 'Côte d\'Ivoire', 'ساحل العاج', 'Ivory Coast', 'fr'),
  Country('HR', 'Croatie', 'كرواتيا', 'Croatia', 'hr'),
  Country('DK', 'Danemark', 'الدنمارك', 'Denmark', 'da'),
  Country('EG', 'Égypte', 'مصر', 'Egypt', 'ar'),
  Country('AE', 'Émirats arabes unis', 'الإمارات', 'United Arab Emirates', 'ar'),
  Country('ES', 'Espagne', 'إسبانيا', 'Spain', 'es'),
  Country('US', 'États-Unis', 'الولايات المتحدة', 'United States', 'en'),
  Country('FR', 'France', 'فرنسا', 'France', 'fr'),
  Country('GH', 'Ghana', 'غانا', 'Ghana', 'en'),
  Country('IN', 'Inde', 'الهند', 'India', 'en'),
  Country('IR', 'Iran', 'إيران', 'Iran', 'fa'),
  Country('IE', 'Irlande', 'أيرلندا', 'Ireland', 'en'),
  Country('IT', 'Italie', 'إيطاليا', 'Italy', 'it'),
  Country('JP', 'Japon', 'اليابان', 'Japan', 'ja'),
  Country('JO', 'Jordanie', 'الأردن', 'Jordan', 'ar'),
  Country('LB', 'Liban', 'لبنان', 'Lebanon', 'ar'),
  Country('ML', 'Mali', 'مالي', 'Mali', 'fr'),
  Country('MR', 'Mauritanie', 'موريتانيا', 'Mauritania', 'ar'),
  Country('MX', 'Mexique', 'المكسيك', 'Mexico', 'es'),
  Country('NG', 'Nigeria', 'نيجيريا', 'Nigeria', 'en'),
  Country('NL', 'Pays-Bas', 'هولندا', 'Netherlands', 'nl'),
  Country('PL', 'Pologne', 'بولندا', 'Poland', 'pl'),
  Country('PT', 'Portugal', 'البرتغال', 'Portugal', 'pt'),
  Country('QA', 'Qatar', 'قطر', 'Qatar', 'ar'),
  Country('SN', 'Sénégal', 'السنغال', 'Senegal', 'fr'),
  Country('RS', 'Serbie', 'صربيا', 'Serbia', 'sr'),
  Country('CH', 'Suisse', 'سويسرا', 'Switzerland', 'fr'),
  Country('SE', 'Suède', 'السويد', 'Sweden', 'en'),
  Country('TN', 'Tunisie', 'تونس', 'Tunisia', 'ar'),
  Country('TR', 'Turquie', 'تركيا', 'Turkey', 'en'),
];

Country? countryByCode(String? code) => countries.where((c) => c.code == code).firstOrNull;

/// Recherche sans accents ni majuscules, sur les trois noms et le code.
List<Country> searchCountries(String query) {
  String norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[àâä]'), 'a')
      .replaceAll(RegExp('[ôö]'), 'o')
      .replaceAll(RegExp('[îï]'), 'i')
      .replaceAll(RegExp('[ûü]'), 'u');
  final q = norm(query.trim());
  if (q.isEmpty) return countries;
  return countries.where((c) => [c.fr, c.ar, c.en, c.code].any((n) => norm(n).contains(q))).toList();
}

/// Compte du passager (gardé sur le téléphone, pour la connexion par empreinte ou visage).
/// La nationalité sert à proposer la langue et à aider les touristes, jamais à la publicité (loi 09-08).
class Account {
  const Account({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.nationality,
    this.phoneCountry = 'MA',
    this.email = '',
  });
  final String id;
  final String firstName;
  final String lastName;
  final String phone;
  final String email;

  /// Code ISO du pays.
  final String nationality;

  /// Pays de l'indicatif du numéro (code ISO).
  final String phoneCountry;

  Map<String, String> toJson() => {
        'id': id,
        'firstName': firstName,
        'lastName': lastName,
        'phone': phone,
        'email': email,
        'nationality': nationality,
        'phoneCountry': phoneCountry,
      };

  static Account? fromJson(Map<String, dynamic> j) {
    final id = j['id'], first = j['firstName'], last = j['lastName'], phone = j['phone'], nat = j['nationality'];
    if (id is! String || first is! String || last is! String || phone is! String || nat is! String) return null;
    return Account(
      id: id,
      firstName: first,
      lastName: last,
      phone: phone,
      nationality: nat,
      phoneCountry: j['phoneCountry'] is String ? j['phoneCountry'] as String : 'MA',
      email: j['email'] is String ? j['email'] as String : '',
    );
  }
}

/// Code SMS de la démo (aucun SMS n'est envoyé).
const demoSmsCode = '1234';

/// Numéro marocain ou international : + et 8 à 15 chiffres.
bool validPhone(String v) => RegExp(r'^\+\d{8,15}$').hasMatch(v.replaceAll(RegExp(r'[\s.-]'), ''));

/// Numéro local (sans l'indicatif) : 6 à 12 chiffres, espaces, points et tirets permis.
bool validLocalNumber(String v) => RegExp(r'^\d{6,12}$').hasMatch(v.replaceAll(RegExp(r'[\s.-]'), ''));

bool validEmail(String v) => v.trim().isEmpty || RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());

/// Identifiant de compte : U suivi de 5 caractères (lettres majuscules et chiffres).
String newAccountId([Random? rnd]) {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final r = rnd ?? Random();
  return 'U${List.generate(5, (_) => chars[r.nextInt(chars.length)]).join()}';
}

/// Compte du passager, gardé sur le téléphone pour la connexion par empreinte ou visage.
class AccountStore extends ChangeNotifier {
  static const _key = 'account';
  Account? _account;

  /// Enregistrement sur le téléphone, à partir de [load] (lancement de l'application, pas dans les tests).
  bool _persistent = false;
  bool _skipped = false;

  Account? get account => _account;

  /// « Continuer en démo » : pas d'inscription au premier lancement.
  bool get skipped => _skipped;

  void save(Account a) {
    _account = a;
    notifyListeners();
    _persist();
  }

  /// Lancement : compte enregistré sur le téléphone (aucun dans la version web ni dans les tests).
  Future<void> load() async {
    _persistent = true;
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      if (raw == null) return;
      final a = Account.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      if (a != null) {
        _account = a;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _persist() async {
    if (!_persistent) return;
    try {
      final p = await SharedPreferences.getInstance();
      final a = _account;
      if (a == null) {
        await p.remove(_key);
      } else {
        await p.setString(_key, jsonEncode(a.toJson()));
      }
    } catch (_) {}
  }

  void skip() {
    _skipped = true;
    notifyListeners();
  }

  void reset() {
    _account = null;
    _skipped = false;
    notifyListeners();
    _persist();
  }
}

final accountStore = AccountStore();
