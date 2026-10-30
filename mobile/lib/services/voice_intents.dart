import 'quartiers.dart';

/// Ce que le passager peut dire pendant le parcours 100 % vocal.
enum VoiceIntent {
  yes,
  no,
  cancel,
  repeat,
  help,
  shared,
  alone,
  premium,
  grandSeat,
  grandWhole,
  cash,
  card,
  where,
  call,
  share,
  sos,
  skip
}

/// Mots compris pour chaque intention : français, arabe, darija (en arabe et en lettres latines), anglais,
/// et oui / non dans les autres langues de l'application.
const _keywords = <VoiceIntent, List<String>>{
  VoiceIntent.yes: [
    'oui',
    'ouais',
    'ouai',
    "d'accord",
    'ok',
    'okay',
    'exact',
    'exactement',
    "c'est ça",
    "c'est bien ça",
    'confirme',
    'je confirme',
    'vas-y',
    'yes',
    'yeah',
    'yep',
    'sure',
    'correct',
    'نعم',
    'أجل',
    'اه',
    'ايه',
    'إيه',
    'واخا',
    'صافي',
    'wakha',
    'waha',
    'iyeh',
    'eyeh',
    'naam',
    'safi',
    'sí',
    'si',
    'sim',
    'ja',
    'tak',
    'da',
    'はい',
    '네',
    '예',
    'بله',
  ],
  VoiceIntent.no: [
    'non',
    'pas ça',
    'no',
    'nope',
    'لا',
    'لالا',
    'ماشي',
    'nein',
    'nee',
    'nie',
    'nej',
    'não',
    'いいえ',
    '아니요',
    'نه',
  ],
  VoiceIntent.cancel: [
    'annuler',
    'annule',
    'annulez',
    'arrête',
    'arrêter',
    'stop',
    'cancel',
    'لغي',
    'ألغي',
    'الغاء',
    'إلغاء',
    'بلاش',
    'بطل',
    'blach',
    'lghi',
  ],
  VoiceIntent.repeat: [
    'répète',
    'répéter',
    'répétez',
    'redis',
    'encore',
    'pardon',
    'quoi',
    'repeat',
    'again',
    'what',
    'عاود',
    'عاودي',
    'أعد',
    'اعد',
    'شنو',
    '3awed',
    'aawed',
  ],
  VoiceIntent.help: ['aide', 'que dire', 'quoi dire', 'commandes', 'help', 'مساعدة', 'عاوني'],
  VoiceIntent.shared: [
    'partagé',
    'partage',
    'normal',
    'collectif',
    'petit taxi',
    'avec d\'autres',
    'shared',
    'share ride',
    'مشترك',
    'مشاركة',
    'مع الناس',
    'عادي',
    'mcharek',
    'mouchtarak',
    '3adi',
  ],
  VoiceIntent.alone: [
    'seul',
    'tout seul',
    'seule',
    'solo',
    'privé',
    'alone',
    'private',
    'وحدي',
    'بوحدي',
    'براسي',
    'وحدك',
    'bohdi',
    'wahdi',
    'brasi',
  ],
  VoiceIntent.premium: ['premium', 'luxe', 'confort', 'vip', 'بريميوم', 'بريميم', 'فاخر', 'لوكس'],
  VoiceIntent.grandSeat: ['une place', 'place', 'seat', 'بلاصة', 'مقعد', 'blasa', 'blassa'],
  VoiceIntent.grandWhole: ['entier', 'tout le taxi', 'complet', 'whole', 'كامل', 'كله', 'kamel'],
  VoiceIntent.cash: [
    'espèces',
    'espèce',
    'cash',
    'liquide',
    'argent',
    'كاش',
    'نقدا',
    'نقدي',
    'فلوس',
    'بالفلوس',
    'flous',
    'flouss',
  ],
  VoiceIntent.card: ['carte', 'carte bancaire', 'card', 'بطاقة', 'كارط', 'لاكارط', 'lacarte', 'karta'],
  VoiceIntent.where: [
    'où est',
    'où en est',
    'combien de temps',
    'quand',
    'il arrive',
    'temps',
    'where',
    'how long',
    'when',
    'فين',
    'شحال',
    'وقتاش',
    'أين',
    'متى',
    'chhal',
    'imta',
    'w9tach',
  ],
  VoiceIntent.call: [
    'appeler',
    'appelle',
    'appelez',
    'téléphoner',
    'call',
    'phone',
    'عيط',
    'عيط ليه',
    'اتصل',
    'تصل',
    '3ayet',
    'ttasel',
  ],
  VoiceIntent.share: [
    'partager',
    'partage mon trajet',
    'envoyer ma position',
    'position',
    'share',
    'شارك',
    'بارطاجي',
    'صيفط',
    'sift',
  ],
  VoiceIntent.sos: [
    'sos',
    'au secours',
    'secours',
    'urgence',
    'danger',
    'police',
    'aidez-moi',
    'aidez moi',
    'help me',
    'emergency',
    'النجدة',
    'نجدة',
    'عتقوني',
    'عتقو',
    'ساعدوني',
    'خطر',
    'البوليس',
    'بوليس',
    '3te9ouni',
  ],
  VoiceIntent.skip: [
    'passer',
    'je passe',
    'plus tard',
    'rien',
    'pas de pourboire',
    'non merci',
    'zéro',
    'skip',
    'no thanks',
    'nothing',
    'none',
    'والو',
    'لا شكرا',
    'walou',
    'walo',
  ],
};

/// Mots qui ne comptent que s'ils sont dits seuls (« la » est aussi un article en français).
const _alone = {'la': VoiceIntent.no};

Map<VoiceIntent, List<String>>? _normalized;

Map<VoiceIntent, List<String>> get _table => _normalized ??= {
      for (final e in _keywords.entries)
        e.key: [for (final k in e.value) normalizeQuartier(k)].where((k) => k.isNotEmpty).toList(),
    };

/// Toutes les intentions reconnues dans une phrase dite (« oui, en espèces » → oui + espèces).
Set<VoiceIntent> voiceIntents(String said) {
  final n = normalizeQuartier(said);
  if (n.isEmpty) return {};
  final hay = ' $n ';
  final found = <VoiceIntent>{
    for (final e in _table.entries)
      if (e.value.any((k) => hay.contains(' $k '))) e.key,
  };
  final single = _alone[n];
  if (single != null) found.add(single);
  // « Aidez-moi » est une urgence, pas une demande d'aide ; « partage mon trajet » n'est pas un taxi partagé.
  if (found.contains(VoiceIntent.sos)) found.remove(VoiceIntent.help);
  if (found.contains(VoiceIntent.share) && !hay.contains(' taxi ')) found.remove(VoiceIntent.shared);
  // « Non merci », « لا شكرا » : pas de pourboire, ce n'est pas un refus.
  if (found.contains(VoiceIntent.skip)) found.remove(VoiceIntent.no);
  return found;
}

const _numbers = {
  'zero': 0, 'un': 1, 'une': 1, 'deux': 2, 'trois': 3, 'quatre': 4, 'cinq': 5, 'six': 6, 'dix': 10, 'quinze': 15,
  'vingt': 20, 'trente': 30, 'cinquante': 50, 'cent': 100, //
  'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5, 'ten': 10, 'fifteen': 15, 'twenty': 20, 'fifty': 50,
  'wahed': 1, 'jouj': 2, 'jooj': 2, 'zouj': 2, 'tlata': 3, 'rb3a': 4, 'reb3a': 4, 'khamsa': 5, '3achra': 10,
  '3achrin': 20, 'khamsin': 50,
  'واحد': 1, 'وحدة': 1, 'جوج': 2, 'زوج': 2, 'اثنان': 2, 'اثنين': 2, 'ثلاثة': 3, 'تلاتة': 3, 'ثلاث': 3, 'أربعة': 4,
  'ربعة': 4, 'خمسة': 5, 'عشرة': 10, 'خمستاش': 15, 'عشرين': 20, 'عشرون': 20, 'خمسين': 50, 'مية': 100,
};

Map<String, int>? _numbersNormalized;

/// Premier nombre dit (« 4 étoiles », « quatre », « ربعة », « 20 dirhams »), sinon null.
int? spokenNumber(String said) {
  final arabicDigits = RegExp('[٠-٩]+').firstMatch(said);
  if (arabicDigits != null) {
    return int.parse(String.fromCharCodes(arabicDigits[0]!.codeUnits.map((c) => c - 0x0660 + 0x30)));
  }
  // Les mots d'abord : « 3achra » est un mot darija en lettres latines, pas le chiffre 3.
  final table = _numbersNormalized ??= {for (final e in _numbers.entries) normalizeQuartier(e.key): e.value};
  for (final w in normalizeQuartier(said).split(' ')) {
    final v = table[w];
    if (v != null) return v;
  }
  final digits = RegExp(r'\d+').firstMatch(said);
  return digits == null ? null : int.parse(digits[0]!);
}
