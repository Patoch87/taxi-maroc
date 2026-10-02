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
    'whereTo': {'fr': "Où allez-vous ?", 'ar': "إلى أين تذهب؟", 'en': "Where to?"},
    'searchPlace': {'fr': "Rechercher une destination", 'ar': "ابحث عن وجهة", 'en': "Search a destination"},
    'chooseRide': {'fr': "Choisissez votre taxi", 'ar': "اختر الطاكسي", 'en': "Choose your taxi"},
    'sharedDesc': {'fr': "Avec d'autres passagers sur la route", 'ar': "مع ركاب آخرين في نفس الطريق", 'en': "With other riders on the way"},
    'aloneTitle': {'fr': "Petit taxi seul", 'ar': "طاكسي صغير وحدي", 'en': "Petit taxi, private"},
    'aloneDesc': {'fr': "Le taxi rien que pour vous", 'ar': "الطاكسي لك وحدك", 'en': "The taxi just for you"},
    'premiumDesc': {'fr': "Véhicule récent et climatisé", 'ar': "سيارة حديثة ومكيفة", 'en': "Recent, air-conditioned car"},
    'grandSeat': {'fr': "Grand taxi, 1 place", 'ar': "طاكسي كبير، مقعد واحد", 'en': "Grand taxi, 1 seat"},
    'grandWhole': {'fr': "Grand taxi entier", 'ar': "طاكسي كبير كامل", 'en': "Whole grand taxi"},
    'grandDesc': {'fr': "Départ dès que le taxi est plein", 'ar': "الانطلاق عند امتلاء الطاكسي", 'en': "Leaves when full"},
    'confirm': {'fr': "Commander", 'ar': "اطلب", 'en': "Request"},
    'searching': {'fr': "Recherche d'un taxi sur votre route…", 'ar': "البحث عن طاكسي في طريقك…", 'en': "Finding a taxi on your route…"},
    'cancel': {'fr': "Annuler", 'ar': "إلغاء", 'en': "Cancel"},
    'arrivingIn': {'fr': "Votre taxi arrive dans", 'ar': "الطاكسي سيصل خلال", 'en': "Your taxi arrives in"},
    'arrived': {'fr': "Votre taxi est arrivé", 'ar': "وصل الطاكسي", 'en': "Your taxi has arrived"},
    'startTrip': {'fr': "Commencer la course", 'ar': "ابدأ الرحلة", 'en': "Start trip"},
    'onTrip': {'fr': "En route vers", 'ar': "في الطريق إلى", 'en': "On the way to"},
    'tripDone': {'fr': "Vous êtes arrivé", 'ar': "لقد وصلت", 'en': "You have arrived"},
    'pay': {'fr': "À payer au chauffeur", 'ar': "المبلغ للسائق", 'en': "Pay the driver"},
    'rate': {'fr': "Notez votre chauffeur", 'ar': "قيم السائق", 'en': "Rate your driver"},
    'done': {'fr': "Terminer", 'ar': "إنهاء", 'en': "Done"},
    'minutes': {'fr': "min", 'ar': "د", 'en': "min"},
    'officialPrice': {'fr': "Prix officiel estimé, ne payez pas plus", 'ar': "ثمن رسمي تقديري، لا تدفع أكثر", 'en': "Estimated official fare, don't pay more"},
    'driverMode': {'fr': "Mode chauffeur", 'ar': "وضع السائق", 'en': "Driver mode"},
    'language': {'fr': "Langue", 'ar': "اللغة", 'en': "Language"},
    'goOnline': {'fr': "Passer en ligne", 'ar': "ابدأ العمل", 'en': "Go online"},
    'goOffline': {'fr': "Passer hors ligne", 'ar': "توقف عن العمل", 'en': "Go offline"},
    'offlineHint': {'fr': "Vous êtes hors ligne", 'ar': "أنت غير متصل", 'en': "You are offline"},
    'onlineHint': {'fr': "En ligne : passagers sur votre route", 'ar': "متصل: ركاب في طريقك", 'en': "Online: riders on your route"},
    'newRequest': {'fr': "Passager sur votre route", 'ar': "راكب في طريقك", 'en': "Rider on your route"},
    'accept': {'fr': "Accepter", 'ar': "قبول", 'en': "Accept"},
    'decline': {'fr': "Refuser", 'ar': "رفض", 'en': "Decline"},
    'pickupAhead': {'fr': "à récupérer devant vous", 'ar': "في انتظارك أمامك", 'en': "to pick up ahead"},
    'pickedUp': {'fr': "Passager à bord", 'ar': "الراكب على متن الطاكسي", 'en': "Rider on board"},
    'dropOff': {'fr': "Déposer le passager", 'ar': "إنزال الراكب", 'en': "Drop off rider"},
    'seats': {'fr': "places", 'ar': "مقاعد", 'en': "seats"},
    'demoBanner': {'fr': "Démo : taxis fictifs", 'ar': "تجريبي: طاكسيات وهمية", 'en': "Demo: simulated taxis"},
    'error': {'fr': 'Erreur de connexion', 'ar': 'خطأ في الاتصال', 'en': 'Connection error'},
  };

  String t(String key) => _t[key]?[lang] ?? _t[key]?['fr'] ?? key;
}
