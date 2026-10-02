/// Textes de l'application en arabe, français et anglais.
/// La darija et l'amazigh viendront ensuite.
class S {
  S(this.lang);
  final String lang;

  static const supported = ['fr', 'ar', 'en'];

  static const Map<String, Map<String, String>> _t = {
    'appTitle': {'fr': 'Taxi Maroc', 'ar': 'طاكسي المغرب', 'en': 'Taxi Morocco'},
    'iAmPassenger': {'fr': 'Je suis passager', 'ar': 'أنا راكب', 'en': 'I am a passenger'},
    'iAmDriver': {'fr': 'Je suis chauffeur', 'ar': 'أنا سائق', 'en': 'I am a driver'},
    'voiceMode': {'fr': 'Commande vocale', 'ar': 'الطلب بالصوت', 'en': 'Voice ordering'},
    'destination': {'fr': 'Destination finale', 'ar': 'الوجهة النهائية', 'en': 'Final destination'},
    'petitTaxi': {'fr': 'Petit taxi', 'ar': 'طاكسي صغير', 'en': 'Petit taxi (city)'},
    'grandTaxi': {'fr': 'Grand taxi', 'ar': 'طاكسي كبير', 'en': 'Grand taxi (intercity)'},
    'alone': {'fr': 'Seul (supplément)', 'ar': 'وحدي (مع زيادة)', 'en': 'Alone (surcharge)'},
    'shared': {'fr': 'Partagé', 'ar': 'مشترك', 'en': 'Shared'},
    'premium': {'fr': 'Taxi premium', 'ar': 'طاكسي ممتاز', 'en': 'Premium taxi'},
    'estimate': {'fr': 'Voir le prix', 'ar': 'عرض الثمن', 'en': 'See the price'},
    'findTaxi': {'fr': 'Trouver un taxi sur ma route', 'ar': 'ابحث عن طاكسي في طريقي', 'en': 'Find a taxi on my way'},
    'priceInfo': {
      'fr': 'Prix estimé selon le tarif officiel. Ne payez pas plus.',
      'ar': 'الثمن التقديري حسب التعريفة الرسمية. لا تدفع أكثر.',
      'en': 'Estimated price based on the official fare. Do not pay more.'
    },
    'noTaxi': {'fr': 'Aucun taxi sur votre route pour le moment.', 'ar': 'لا يوجد طاكسي في طريقك حاليا.', 'en': 'No taxi on your route right now.'},
    'taxiFound': {'fr': 'Taxi trouvé, il arrive', 'ar': 'تم العثور على طاكسي، إنه قادم', 'en': 'Taxi found, on its way'},
    'complain': {'fr': 'Signaler un problème', 'ar': 'الإبلاغ عن مشكلة', 'en': 'Report a problem'},
    'send': {'fr': 'Envoyer', 'ar': 'إرسال', 'en': 'Send'},
    'complaintSent': {'fr': 'Plainte enregistrée', 'ar': 'تم تسجيل الشكاية', 'en': 'Complaint recorded'},
    'available': {'fr': 'Disponible', 'ar': 'متاح', 'en': 'Available'},
    'busy': {'fr': 'Occupé', 'ar': 'مشغول', 'en': 'Busy'},
    'sos': {'fr': 'SOS urgence', 'ar': 'نجدة', 'en': 'SOS emergency'},
    'speakNow': {'fr': 'Dites votre destination', 'ar': 'قل وجهتك', 'en': 'Say your destination'},
    'error': {'fr': 'Erreur de connexion', 'ar': 'خطأ في الاتصال', 'en': 'Connection error'},
  };

  String t(String key) => _t[key]?[lang] ?? _t[key]?['fr'] ?? key;
}
