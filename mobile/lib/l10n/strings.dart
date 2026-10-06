import 'lang/es.dart' as es_;
import 'lang/pt.dart' as pt_;
import 'lang/de.dart' as de_;
import 'lang/it.dart' as it_;
import 'lang/nl.dart' as nl_;
import 'lang/pl.dart' as pl_;
import 'lang/hr.dart' as hr_;
import 'lang/sr.dart' as sr_;
import 'lang/da.dart' as da_;
import 'lang/ja.dart' as ja_;
import 'lang/ko.dart' as ko_;
import 'lang/fa.dart' as fa_;

/// Textes de l'application dans 16 langues : celles du Maroc (français, arabe, darija, anglais)
/// et celles des pays de la Coupe du monde 2022.
///
/// Les 4 langues de base sont dans le tableau [_t] ci-dessous ; les autres ont chacune leur fichier
/// dans `lang/` (une ligne par clé), plus simple à faire relire par un locuteur natif.
class S {
  S(this.lang);
  final String lang;

  /// Codes des langues, dans l'ordre d'affichage du choix de langue.
  /// dr : darija marocaine (écrite en arabe) ; sr : serbe en alphabet latin.
  static const supported = [
    'fr', 'ar', 'dr', 'en', 'es', 'pt', 'de', 'it', 'nl', 'pl', 'hr', 'sr', 'da', 'ja', 'ko', 'fa' //
  ];

  /// Nom de chaque langue, écrit dans cette langue.
  static const names = {
    'fr': 'Français',
    'ar': 'العربية',
    'dr': 'الدارجة',
    'en': 'English',
    'es': 'Español',
    'pt': 'Português',
    'de': 'Deutsch',
    'it': 'Italiano',
    'nl': 'Nederlands',
    'pl': 'Polski',
    'hr': 'Hrvatski',
    'sr': 'Srpski',
    'da': 'Dansk',
    'ja': '日本語',
    'ko': '한국어',
    'fa': 'فارسی',
  };

  /// Drapeau affiché pour chaque langue.
  static const flags = {
    'fr': '🇫🇷',
    'ar': '🇲🇦',
    'dr': '🇲🇦',
    'en': '🇬🇧',
    'es': '🇪🇸',
    'pt': '🇵🇹',
    'de': '🇩🇪',
    'it': '🇮🇹',
    'nl': '🇳🇱',
    'pl': '🇵🇱',
    'hr': '🇭🇷',
    'sr': '🇷🇸',
    'da': '🇩🇰',
    'ja': '🇯🇵',
    'ko': '🇰🇷',
    'fa': '🇮🇷',
  };

  static const _i = {'fr': 0, 'ar': 1, 'dr': 2, 'en': 3};

  static const Map<String, Map<String, String>> _other = {
    'es': es_.es,
    'pt': pt_.pt,
    'de': de_.de,
    'it': it_.it,
    'nl': nl_.nl,
    'pl': pl_.pl,
    'hr': hr_.hr,
    'sr': sr_.sr,
    'da': da_.da,
    'ja': ja_.ja,
    'ko': ko_.ko,
    'fa': fa_.fa,
  };

  /// Langues écrites de droite à gauche.
  bool get rtl => lang == 'ar' || lang == 'dr' || lang == 'fa';

  /// Langue de la reconnaissance et de la synthèse vocales.
  String get speechLocale => switch (lang) {
        'ar' || 'dr' => 'ar-MA',
        'en' => 'en-US',
        'es' => 'es-ES',
        'pt' => 'pt-PT',
        'de' => 'de-DE',
        'it' => 'it-IT',
        'nl' => 'nl-NL',
        'pl' => 'pl-PL',
        'hr' => 'hr-HR',
        'sr' => 'sr-RS',
        'da' => 'da-DK',
        'ja' => 'ja-JP',
        'ko' => 'ko-KR',
        'fa' => 'fa-IR',
        _ => 'fr-FR',
      };

  /// Les nombres décimaux s'écrivent avec un point dans ces langues, avec une virgule ailleurs.
  bool get decimalPoint => const ['en', 'ja', 'ko'].contains(lang);

  /// Touriste probable : langue autre que le français, l'arabe ou la darija.
  bool get foreign => !const ['fr', 'ar', 'dr'].contains(lang);

  static const Map<String, List<String>> _t = {
    // Général
    'appTitle': ['Bab Taxi', 'باب طاكسي', 'باب طاكسي', 'Bab Taxi'],
    'demoBanner': [
      'Démo : taxis fictifs',
      'تجريبي: طاكسيات وهمية',
      'تجريبي: طاكسيات ماشي حقيقيين',
      'Demo: simulated taxis'
    ],
    'error': ['Erreur de connexion', 'خطأ في الاتصال', 'كاين مشكل فالكونيكسيون', 'Connection error'],
    'cancel': ['Annuler', 'إلغاء', 'لغي', 'Cancel'],
    'done': ['Terminer', 'إنهاء', 'سالينا', 'Done'],
    'send': ['Envoyer', 'إرسال', 'صيفط', 'Send'],
    'close': ['Fermer', 'إغلاق', 'سد', 'Close'],
    'minutes': ['min', 'د', 'دقيقة', 'min'],
    'language': ['Langue', 'اللغة', 'اللغة', 'Language'],
    'hello': ['Salam 👋', 'السلام عليكم 👋', 'السلام 👋', 'Salam 👋'],

    // Recherche et commande
    'whereTo': ['Où allez-vous ?', 'إلى أين تذهب؟', 'فين غادي؟', 'Where to?'],
    'searchPlace': ['Rechercher une destination', 'ابحث عن وجهة', 'قلب على البلاصة', 'Search a destination'],
    'home': ['Maison', 'المنزل', 'الدار', 'Home'],
    'work': ['Travail', 'العمل', 'الخدمة', 'Work'],
    'recent': ['Récents', 'الأخيرة', 'اللي مشيتي ليهم', 'Recent'],
    'now': ['Maintenant', 'الآن', 'دابا', 'Now'],
    'later': ['Plus tard', 'لاحقا', 'من بعد', 'Later'],
    'scheduledFor': ['Prévu à', 'مبرمج على', 'مبرمج مع', 'Scheduled for'],
    'speakNow': ['Dites votre destination', 'قل وجهتك', 'قول فين بغيتي تمشي', 'Say your destination'],
    'listening': ['Je vous écoute…', 'أستمع إليك…', 'كنسمع ليك…', 'Listening…'],
    'youSaid': ['Vous avez dit', 'قلت', 'قلتي', 'You said'],
    'searchingFor': ['Je cherche', 'أبحث عن', 'كنقلب على', 'Searching for'],
    'notUnderstood': [
      'Je n\'ai pas compris, réessayez',
      'لم أفهم، أعد المحاولة',
      'ما فهمتش، عاود',
      'I didn\'t understand, try again'
    ],
    'micDenied': ['Micro non disponible', 'الميكروفون غير متاح', 'الميكرو ماخدامش', 'Microphone unavailable'],

    // Choix du taxi
    'chooseRide': ['Choisissez votre taxi', 'اختر الطاكسي', 'ختار الطاكسي', 'Choose your taxi'],
    'petitTaxi': ['Petit taxi', 'طاكسي صغير', 'طاكسي صغير', 'Petit taxi'],
    'grandTaxi': ['Grand taxi', 'طاكسي كبير', 'طاكسي كبير', 'Grand taxi'],
    'sharedDesc': [
      'Partagé avec des passagers sur votre route',
      'مشترك مع ركاب في طريقك',
      'مشارك مع ناس فطريقك',
      'Shared with riders on your route'
    ],
    'aloneTitle': ['Petit taxi seul', 'طاكسي صغير لوحدك', 'طاكسي صغير بوحدك', 'Petit taxi, private'],
    'aloneDesc': ['Le taxi rien que pour vous', 'الطاكسي لك وحدك', 'الطاكسي ديالك بوحدك', 'The taxi just for you'],
    'premium': ['Taxi premium', 'طاكسي ممتاز', 'طاكسي بريميوم', 'Premium taxi'],
    'premiumDesc': [
      'Véhicule récent et climatisé',
      'سيارة حديثة ومكيفة',
      'طوموبيل جديدة وفيها الكليماتيزور',
      'Recent, air-conditioned car'
    ],
    'grandSeat': ['Grand taxi, 1 place', 'طاكسي كبير، مقعد واحد', 'طاكسي كبير، بلاصة وحدة', 'Grand taxi, 1 seat'],
    'grandWhole': ['Grand taxi entier', 'طاكسي كبير كامل', 'طاكسي كبير كامل', 'Whole grand taxi'],
    'grandDesc': [
      'Départ dès que le taxi est plein',
      'الانطلاق عند امتلاء الطاكسي',
      'كيمشي ملي يعمر',
      'Leaves when full'
    ],
    'officialPrice': [
      'Prix officiel estimé, ne payez pas plus',
      'ثمن رسمي تقديري، لا تدفع أكثر',
      'الثمن الرسمي، ما تخلصش كثر',
      'Estimated official fare, don\'t pay more'
    ],
    'cash': ['Espèces', 'نقدا', 'كاش', 'Cash'],
    'card': ['Carte bancaire', 'بطاقة بنكية', 'لاكارط', 'Card'],
    'confirm': ['Commander', 'اطلب', 'طلب', 'Request'],
    'arrivalAt': ['Arrivée vers', 'الوصول حوالي', 'غادي توصل مع', 'Arrival around'],

    // Recherche de chauffeur (premier qui accepte)
    'searching': [
      'Recherche d\'un taxi sur votre route…',
      'البحث عن طاكسي في طريقك…',
      'كنقلبو على طاكسي فطريقك…',
      'Finding a taxi on your route…'
    ],
    'sentTo': ['Demande envoyée à', 'تم إرسال الطلب إلى', 'الطلب تصيفط ل', 'Request sent to'],
    'drivers': ['chauffeurs sur votre route', 'سائقين في طريقك', 'شيفورات فطريقك', 'drivers on your route'],
    'firstWins': [
      'Le premier qui accepte prend la course, les autres ne sont pas retenus',
      'أول سائق يقبل يأخذ الرحلة، ولا يتم اختيار الباقين',
      'اللي قبل اللول هو اللي غادي يجي، والباقين ما تختاروش',
      'The first to accept gets the ride, the others are not selected'
    ],
    'acceptedFirst': ['a accepté en premier', 'قبل أولا', 'قبل هو اللول', 'accepted first'],
    'declined': ['a refusé', 'رفض', 'رفض', 'declined'],
    'blocked': ['non retenu', 'لم يتم اختياره', 'ما تختارش', 'not selected'],
    'answerAccepted': ['accepté', 'قبل', 'قبل', 'accepted'],
    'answerPending': ['en attente', 'في الانتظار', 'كيتسنى', 'waiting'],
    'noTaxi': [
      'Aucun taxi sur votre route pour le moment.',
      'لا يوجد طاكسي في طريقك حاليا.',
      'ما كاين حتى طاكسي فطريقك دابا.',
      'No taxi on your route right now.'
    ],

    // Course
    'arrivingIn': ['Votre taxi arrive dans', 'الطاكسي سيصل خلال', 'الطاكسي غادي يوصل فـ', 'Your taxi arrives in'],
    'arrived': ['Votre taxi est arrivé', 'وصل الطاكسي', 'الطاكسي وصل', 'Your taxi has arrived'],
    'startTrip': ['Je suis dans le taxi', 'أنا في الطاكسي', 'راني فالطاكسي', 'I\'m in the taxi'],
    'onTrip': ['En route vers', 'في الطريق إلى', 'فالطريق ل', 'On the way to'],
    'remaining': ['restantes', 'متبقية', 'باقيين', 'left'],
    'speaks': ['Parle', 'يتحدث', 'كيهضر', 'Speaks'],
    'ridesCount': ['courses', 'رحلة', 'كورصة', 'rides'],
    'call': ['Appeler', 'اتصال', 'عيط', 'Call'],
    'message': ['Message', 'رسالة', 'ميساج', 'Message'],
    'share': ['Partager', 'مشاركة', 'بارطاجي', 'Share'],
    'safety': ['Sécurité', 'الأمان', 'الأمان', 'Safety'],
    'shareText': [
      'Je suis en taxi avec Bab Taxi',
      'أنا في طاكسي مع باب طاكسي',
      'راني فطاكسي مع باب طاكسي',
      'I\'m in a taxi with Bab Taxi'
    ],
    'myPosition': ['Ma position', 'موقعي', 'فين أنا', 'My location'],

    // Sécurité et réclamations
    'sos': ['SOS urgence', 'نجدة', 'عتقوني', 'SOS emergency'],
    'sosDesc': [
      'Alerte vos proches et la plateforme avec votre position',
      'تنبيه أقاربك والمنصة بموقعك',
      'كيعلم العائلة ديالك والمنصة فين نتا',
      'Alerts your contacts and the platform with your location'
    ],
    'police': ['Police (19)', 'الشرطة (19)', 'البوليس (19)', 'Police (19)'],
    'gendarmerie': ['Gendarmerie (177)', 'الدرك (177)', 'الجدارمية (177)', 'Gendarmerie (177)'],
    'ambulance': ['Protection civile (15)', 'الوقاية المدنية (15)', 'لابروطيكسيون (15)', 'Civil protection (15)'],
    'shareTrip': ['Partager ma course en direct', 'مشاركة رحلتي مباشرة', 'بارطاجي الكورصة ديالي', 'Share my trip live'],
    'complain': ['Signaler un problème', 'الإبلاغ عن مشكلة', 'بلغ على شي مشكل', 'Report a problem'],
    'complaintSent': ['Réclamation enregistrée', 'تم تسجيل الشكاية', 'الشكاية تسجلات', 'Complaint recorded'],
    'sosSent': [
      'Alerte envoyée avec votre position',
      'تم إرسال التنبيه مع موقعك',
      'التنبيه تصيفط مع البلاصة ديالك',
      'Alert sent with your location'
    ],
    'motifRefus': ['Refus de course', 'رفض الرحلة', 'رفض يديني', 'Ride refused'],
    'motifPrix': ['Prix abusif', 'ثمن مبالغ فيه', 'طلب بزاف ديال الفلوس', 'Overcharging'],
    'motifConduite': ['Conduite dangereuse', 'سياقة خطيرة', 'كيسوق بالخطر', 'Dangerous driving'],
    'motifComportement': ['Comportement', 'السلوك', 'السلوك', 'Behaviour'],
    'motifObjet': ['Objet oublié', 'غرض منسي', 'نسيت شي حاجة', 'Lost item'],
    'motifAutre': ['Autre', 'أخرى', 'حاجة أخرى', 'Other'],
    'describe': [
      'Décrivez le problème (facultatif)',
      'صف المشكلة (اختياري)',
      'شرح المشكل (إلا بغيتي)',
      'Describe the problem (optional)'
    ],

    // Messages rapides
    'quickHere': ['Je suis devant', 'أنا في الأمام', 'راني قدام', 'I\'m in front'],
    'quickComing': ['J\'arrive dans 2 minutes', 'سأصل بعد دقيقتين', 'جاي فجوج دقايق', 'Coming in 2 minutes'],
    'quickWait': ['Attendez-moi s\'il vous plaît', 'انتظرني من فضلك', 'تسناني عافاك', 'Please wait for me'],
    'quickLuggage': ['J\'ai des bagages', 'لدي أمتعة', 'عندي الباليزات', 'I have luggage'],
    'translatedFor': ['Traduit pour le chauffeur', 'مترجم للسائق', 'مترجم للشيفور', 'Translated for the driver'],

    // Fin de course
    'tripDone': ['Vous êtes arrivé', 'لقد وصلت', 'وصلتي', 'You have arrived'],
    'pay': ['À payer au chauffeur', 'المبلغ للسائق', 'خلص الشيفور', 'Pay the driver'],
    'tip': ['Pourboire', 'إكرامية', 'البوربوار', 'Tip'],
    'rate': ['Notez votre chauffeur', 'قيم السائق', 'عطي نقطة للشيفور', 'Rate your driver'],
    'history': ['Mes courses', 'رحلاتي', 'الكورصات ديالي', 'My rides'],
    'noHistory': ['Aucune course pour le moment', 'لا توجد رحلات بعد', 'ما زال ما درتي حتى كورصة', 'No rides yet'],

    'driverReplyOk': ['D\'accord, j\'arrive', 'حسنا، أنا قادم', 'واخا، جاي', 'OK, on my way'],
    'fastForward': ['Accélérer (démo)', 'تسريع (تجريبي)', 'زربها (تجريبي)', 'Fast-forward (demo)'],
    'tripBooked': ['Course réservée pour', 'تم حجز الرحلة على', 'الكورصة تريزيرفات مع', 'Ride booked for'],
    'payment': ['Paiement', 'الدفع', 'الخلاص', 'Payment'],
    'driverInfo': ['Votre chauffeur', 'السائق الخاص بك', 'الشيفور ديالك', 'Your driver'],
    'emergencyNumbers': ['Numéros d\'urgence', 'أرقام الطوارئ', 'نمر الطوارئ', 'Emergency numbers'],
    'planned': ['Prévue', 'مبرمجة', 'مبرمجة', 'Scheduled'],
    'completed': ['Terminée', 'منتهية', 'سالات', 'Completed'],

    // Réservation à l'avance
    'today': ['Aujourd\'hui', 'اليوم', 'اليوم', 'Today'],
    'tomorrow': ['Demain', 'غدا', 'غدا', 'Tomorrow'],
    'tooSoon': [
      'Départ au moins 15 minutes après maintenant',
      'الانطلاق بعد 15 دقيقة على الأقل',
      'خاص يكون الخروج من بعد 15 دقيقة على الأقل',
      'Departure at least 15 minutes from now'
    ],
    'pickupAt': ['Prise en charge à', 'موعد الركوب', 'غادي يدّيك مع', 'Pickup at'],

    // Commander pour quelqu'un d'autre
    'forMe': ['Pour moi', 'لي', 'ليا أنا', 'For me'],
    'forSomeoneElse': ['Pour quelqu\'un d\'autre', 'لشخص آخر', 'لشي واحد آخر', 'For someone else'],
    'whoRides': ['Qui prend le taxi ?', 'من سيركب الطاكسي؟', 'شكون غادي يركب؟', 'Who is riding?'],
    'passengerName': ['Nom du passager', 'اسم الراكب', 'سمية الكليان', 'Passenger name'],
    'phone': ['Téléphone', 'الهاتف', 'التيليفون', 'Phone'],
    'fromContacts': ['Mes contacts', 'جهات اتصالي', 'الكونطاكتات ديالي', 'My contacts'],
    'validate': ['Valider', 'تأكيد', 'أكد', 'Confirm'],
    'passenger': ['Passager', 'الراكب', 'الكليان', 'Passenger'],
    'sendToPassenger': ['Envoyer les infos à', 'إرسال المعلومات إلى', 'صيفط المعلومات ل', 'Send the details to'],
    'passengerInformed': [
      'Infos du trajet envoyées à',
      'تم إرسال معلومات الرحلة إلى',
      'المعلومات ديال الكورصة تصيفطو ل',
      'Trip details sent to'
    ],
    'helloName': ['Bonjour', 'مرحبا', 'السلام', 'Hello'],
    'bookedForYou': [
      'un taxi a été commandé pour vous avec Bab Taxi.',
      'تم طلب طاكسي لك عبر باب طاكسي.',
      'طلبنا ليك طاكسي مع باب طاكسي.',
      'a taxi has been booked for you with Bab Taxi.'
    ],
    'pickupPoint': ['Lieu de prise en charge', 'مكان الركوب', 'البلاصة فين غادي تركب', 'Pickup point'],
    'bookedBy': ['Commandé par', 'طلبه', 'طلبو', 'Booked by'],
    'forPerson': ['pour', 'لـ', 'ل', 'for'],

    // Contacts de confiance
    'trustedContacts': ['Contacts de confiance', 'جهات الاتصال الموثوقة', 'الناس اللي كتيق فيهم', 'Trusted contacts'],
    'trustedDesc': [
      'Jusqu\'à 5 proches à appeler en un geste et à prévenir de vos trajets',
      'حتى 5 أقارب للاتصال بهم بلمسة وإعلامهم برحلاتك',
      'حتى 5 ديال الناس تعيط ليهم بضغطة وتعلمهم بالكورصات ديالك',
      'Up to 5 people to call in one tap and keep posted on your trips'
    ],
    'addContact': ['Ajouter un contact', 'إضافة جهة اتصال', 'زيد كونطاكت', 'Add a contact'],
    'name': ['Nom', 'الاسم', 'السمية', 'Name'],
    'manage': ['Gérer', 'إدارة', 'سيّر', 'Manage'],
    'add': ['Ajouter', 'إضافة', 'زيد', 'Add'],
    'remove': ['Supprimer', 'حذف', 'مسح', 'Remove'],
    'noContacts': [
      'Aucun contact pour le moment',
      'لا توجد جهات اتصال بعد',
      'ما زال ما زدتي حتى واحد',
      'No contacts yet'
    ],
    'maxContacts': [
      '5 contacts au maximum',
      '5 جهات اتصال كحد أقصى',
      '5 كونطاكتات هوما الماكسيموم',
      '5 contacts maximum'
    ],
    'autoShare': [
      'Partager automatiquement chaque trajet',
      'مشاركة كل رحلة تلقائيا',
      'بارطاجي كل كورصة أوطوماتيكيا',
      'Share every trip automatically'
    ],
    'autoAlways': ['Toujours', 'دائما', 'ديما', 'Always'],
    'autoNight': [
      'La nuit seulement (21 h - 6 h)',
      'في الليل فقط (21:00 - 6:00)',
      'غير فالليل (21 - 6)',
      'Only at night (9 pm - 6 am)'
    ],
    'autoNever': ['Jamais', 'أبدا', 'عمرني', 'Never'],
    'sharedWith': ['Trajet partagé avec', 'تمت مشاركة الرحلة مع', 'الكورصة تبارطاجات مع', 'Trip shared with'],
    'contactsShort': ['contacts', 'جهات اتصال', 'كونطاكتات', 'contacts'],

    // Mode senior
    'seniorMode': ['Mode senior', 'وضع كبار السن', 'وضع الشيوخ', 'Senior mode'],
    'seniorModeDesc': [
      'Écran très simple, gros boutons et gros texte',
      'شاشة بسيطة جدا بأزرار ونص كبير',
      'شاشة ساهلة بزاف، بوطونات وكتابة كبار',
      'Very simple screen, big buttons and big text'
    ],
    'normalMode': ['Revenir au mode normal', 'العودة إلى الوضع العادي', 'رجع للوضع العادي', 'Back to normal mode'],
    'seniorOrder': ['Commander un taxi', 'طلب طاكسي', 'طلب طاكسي', 'Book a taxi'],
    'seniorHome': ['Rentrer à la maison', 'العودة إلى المنزل', 'نرجع للدار', 'Go home'],
    'seniorCall': ['Appeler un proche', 'الاتصال بقريب', 'عيط لشي واحد من العائلة', 'Call a loved one'],
    'seniorNoContact': [
      'Ajoutez d\'abord un contact de confiance',
      'أضف أولا جهة اتصال موثوقة',
      'زيد اللول شي واحد كتيق فيه',
      'First add a trusted contact'
    ],
    'goTo': ['Aller à', 'الذهاب إلى', 'نمشي ل', 'Go to'],
    'sayDestination': ['Dire ma destination', 'قل وجهتك', 'قول فين غادي', 'Say my destination'],
    'typeDestination': ['Ou écrivez ici', 'أو اكتب هنا', 'ولا كتب هنا', 'Or type here'],
    'plate': ['Plaque', 'اللوحة', 'لاماتريكيلا', 'Plate'],

    // Accessibilité
    'accessibility': ['Accessibilité', 'إمكانية الوصول', 'السهولة', 'Accessibility'],
    'lowVision': ['Je suis malvoyant(e)', 'أنا ضعيف البصر', 'ما كنشوفش مزيان', 'I am visually impaired'],
    'lowVisionDesc': [
      'Le chauffeur est prévenu que vous êtes malvoyant',
      'يتم إخبار السائق بأنك ضعيف البصر',
      'الشيفور كيتعلم بلي ما كتشوفش مزيان',
      'The driver is told you are visually impaired'
    ],
    'lowVisionBadge': ['Passager malvoyant', 'راكب ضعيف البصر', 'كليان ما كيشوفش مزيان', 'Visually impaired rider'],
    'lowVisionHint': [
      'Présentez-vous et guidez-le jusqu\'à la portière',
      'عرّف بنفسك وساعده حتى باب السيارة',
      'عرف براسك وعاونو حتى للباب',
      'Introduce yourself and guide them to the door'
    ],
    'lowVisionShort': ['Malvoyant', 'ضعيف البصر', 'ما كنشوفش مزيان', 'Low vision'],
    'voiceAnnounce': ['Annonces vocales', 'الإعلانات الصوتية', 'الإعلانات بالصوت', 'Voice announcements'],
    'taxiFound': ['Taxi trouvé', 'تم العثور على طاكسي', 'لقينا طاكسي', 'Taxi found'],
    'minutesLong': ['minutes', 'دقائق', 'دقايق', 'minutes'],
    'minuteOne': ['1 minute', 'دقيقة واحدة', 'دقيقة وحدة', '1 minute'],
    'colorRed': ['rouge', 'أحمر', 'حمر', 'red'],
    'colorBlack': ['noire', 'سوداء', 'كحلة', 'black'],
    'colorBeige': ['beige', 'بيج', 'بيج', 'beige'],
    'demoShort': ['Démo', 'تجريبي', 'تجريبي', 'Demo'],

    // Offres contextuelles (exemples de démo)
    'promoLabel': [
      'Exemple publicitaire (démo)',
      'مثال إشهاري (تجريبي)',
      'مثال ديال الإشهار (تجريبي)',
      'Ad example (demo)'
    ],
    'seeOffer': ['Voir une offre', 'عرض متاح', 'شوف واحد العرض', 'See an offer'],

    // Offres réalistes (démo) et bons de réduction avec QR code
    'offerFashion': [
      '-15 % sur la nouvelle collection',
      'خصم 15٪ على المجموعة الجديدة',
      '-15٪ على الكوليكسيون الجديدة',
      '15% off the new collection'
    ],
    'offerFashionDetail': [
      'Dès 300 DH d\'achat',
      'ابتداء من 300 درهم من المشتريات',
      'من 300 درهم دالشرا',
      'With a purchase of 300 DH or more'
    ],
    'offerKool': [
      'Un smoothie offert pour un acheté',
      'عصير سموذي مجاني عند شراء واحد',
      'شري سموذي وخود واحد فابور',
      'Buy one smoothie, get one free'
    ],
    'offerKoolDetail': ['Avant 18 h', 'قبل الساعة 18', 'قبل 6 دالعشية', 'Before 6 pm'],
    'offerPortCafe': [
      'Café + croissant à 15 DH',
      'قهوة + كرواسون بـ 15 درهم',
      'قهوة + كرواصة ب 15 درهم',
      'Coffee + croissant for 15 DH'
    ],
    'offerPortCafeDetail': [
      'De 7 h à 11 h, sur place ou à emporter',
      'من 7 إلى 11 صباحا، في المكان أو للأخذ',
      'من 7 حتى 11 دالصباح، تما ولا تديها',
      '7 to 11 am, eat in or take away'
    ],
    'offerSport': ['-20 % sur les baskets', 'خصم 20٪ على الأحذية الرياضية', '-20٪ على السبرديلات', '20% off sneakers'],
    'offerSportDetail': [
      'Dès 500 DH d\'achat, hors promotions',
      'ابتداء من 500 درهم، باستثناء التخفيضات',
      'من 500 درهم، من غير الصولد',
      'From 500 DH, sale items excluded'
    ],
    'offerLunch': [
      'Menu déjeuner à 69 DH au lieu de 89 DH',
      'قائمة الغداء بـ 69 درهم بدل 89 درهم',
      'منيو الغدا ب 69 درهم عوض 89',
      'Lunch menu 69 DH instead of 89 DH'
    ],
    'offerLunchDetail': [
      'De 12 h à 15 h, du lundi au vendredi',
      'من 12 إلى 15، من الإثنين إلى الجمعة',
      'من 12 حتى 3، من الاثنين للجمعة',
      '12 to 3 pm, Monday to Friday'
    ],
    'offerTea': [
      'Thé à la menthe offert dès 50 DH de commande',
      'شاي بالنعناع مجاني ابتداء من 50 درهم',
      'أتاي بالنعناع فابور من 50 درهم',
      'Free mint tea with orders from 50 DH'
    ],
    'offerTeaDetail': [
      'Tous les jours jusqu\'à 23 h, en terrasse face à la mer',
      'كل يوم حتى الساعة 23، في الشرفة أمام البحر',
      'كل نهار حتى ل 11 دالليل، فالتيراس قدام البحر',
      'Every day until 11 pm, sea-view terrace'
    ],
    'couponTitle': [
      'Votre bon de réduction',
      'قسيمة التخفيض الخاصة بك',
      'البون ديال التخفيض ديالك',
      'Your discount voucher'
    ],
    'couponLinked': ['Lié à votre compte', 'مرتبط بحسابك', 'مربوط بالحساب ديالك', 'Linked to your account'],
    'couponExpires': ['Valable jusqu\'au', 'صالح حتى', 'صالح حتى', 'Valid until'],
    'couponConditions': [
      'Valable 24 h, une fois, sur présentation en caisse',
      'صالح 24 ساعة، مرة واحدة، عند تقديمه في الصندوق',
      'صالح 24 ساعة، مرة وحدة، وريه فالكيس',
      'Valid for 24 h, once, show it at the checkout'
    ],
    'saveOffer': ['Enregistrer dans mes offres', 'حفظ في عروضي', 'سجل فالعروض ديالي', 'Save to my offers'],
    'offerSaved': ['Enregistré dans mes offres', 'تم الحفظ في عروضي', 'تسجل فالعروض ديالي', 'Saved to my offers'],
    'myOffers': ['Mes offres', 'عروضي', 'العروض ديالي', 'My offers'],
    'noOffers': [
      'Aucune offre enregistrée. Les offres apparaissent pendant la course.',
      'لا توجد عروض محفوظة. تظهر العروض أثناء الرحلة.',
      'ما كاين حتى عرض مسجل. العروض كيبانو فالكورصة.',
      'No saved offers. Offers appear during the ride.'
    ],
    'storeAddress': ['Adresse', 'العنوان', 'العنوان', 'Address'],
    'promoGeneric': ['Votre publicité ici', 'إشهارك هنا', 'الإشهار ديالك هنا', 'Your ad here'],
    'promoGenericDetail': [
      'Annonce non personnalisée',
      'إعلان غير مخصص',
      'إشهار ماشي على حسابك',
      'Non-personalised ad'
    ],
    'mapView': ['Carte plein écran', 'الخريطة بملء الشاشة', 'الخريطة فالشاشة كاملة', 'Full-screen map'],
    'detailsView': ['Afficher les détails', 'عرض التفاصيل', 'وري التفاصيل', 'Show details'],
    // Siège bébé et valises
    'babySeat': ['Siège bébé', 'مقعد الرضيع', 'كرسي ديال البيبي', 'Baby seat'],
    'babySeatRequested': ['Siège bébé demandé', 'مطلوب مقعد للرضيع', 'طالبين كرسي ديال البيبي', 'Baby seat requested'],
    'babySeatFree': [
      'Gratuit : seuls les chauffeurs équipés d\'un siège bébé reçoivent la demande',
      'مجاني: يتلقى الطلب فقط السائقون الذين لديهم مقعد للرضيع',
      'فابور: غير الشيفورات اللي عندهم كرسي ديال البيبي اللي كيوصلهم الطلب',
      'Free: only drivers with a baby seat receive the request'
    ],
    'suitcases': ['Valises', 'حقائب', 'فاليزات', 'Suitcases'],
    'suitcasesMax': ['valises max', 'حقائب كحد أقصى', 'فاليزات ماكسيموم', 'suitcases max'],
    'tooManyBags': [
      'Pas assez de place pour vos valises',
      'لا يوجد مكان كاف لحقائبك',
      'ما كايناش بلاصة كافية للفاليزات ديالك',
      'Not enough room for your suitcases'
    ],
    'fewerBags': ['Une valise de moins', 'حقيبة أقل', 'فاليزة قل', 'One suitcase less'],
    'moreBags': ['Une valise de plus', 'حقيبة إضافية', 'فاليزة زايدة', 'One more suitcase'],
    // Fin de course : note, avis et pourboire par carte
    'tagCareful': ['Conduite prudente', 'قيادة حذرة', 'سايق بشوية', 'Careful driving'],
    'tagClean': ['Propre', 'نظيف', 'نقي', 'Clean'],
    'tagPunctual': ['Ponctuel', 'دقيق في الموعد', 'جا فالوقت', 'On time'],
    'tagMusic': ['Bonne musique', 'موسيقى جيدة', 'موسيقى زوينة', 'Good music'],
    'tagLate': ['Retard', 'تأخير', 'تعطل', 'Late'],
    'tagRough': ['Conduite brusque', 'قيادة متهورة', 'سايق بالزربة', 'Rough driving'],
    'tagPrice': ['Prix non respecté', 'لم يحترم السعر', 'ما احترمش الثمن', 'Price not respected'],
    'commentHint': ['Un commentaire (facultatif)', 'تعليق (اختياري)', 'شي تعليق (إلا بغيتي)', 'A comment (optional)'],
    'otherAmount': ['Autre montant', 'مبلغ آخر', 'شي مبلغ آخر', 'Other amount'],
    'amountDh': ['Montant en DH', 'المبلغ بالدرهم', 'المبلغ بالدرهم', 'Amount in DH'],
    'tipByCard': [
      'Le pourboire est payé par carte',
      'تدفع الإكرامية بالبطاقة',
      'البوربوار كيتخلص بالكارط',
      'The tip is paid by card'
    ],
    'simulatedPayment': [
      'Paiement simulé (démo)',
      'دفع تجريبي (محاكاة)',
      'خلاص تجريبي (ديمو)',
      'Simulated payment (demo)'
    ],
    'savedCard': ['Carte enregistrée', 'بطاقة محفوظة', 'الكارط المسجلة', 'Saved card'],
    'addCard': ['Ajouter une carte', 'إضافة بطاقة', 'زيد كارط', 'Add a card'],
    'cardNumber': ['Numéro de carte', 'رقم البطاقة', 'نمرة الكارط', 'Card number'],
    'cardExpiry': ['Expiration (MM/AA)', 'تاريخ الانتهاء (شهر/سنة)', 'تاريخ الانتهاء (MM/AA)', 'Expiry (MM/YY)'],
    'cardCvc': ['CVC', 'رمز CVC', 'CVC', 'CVC'],
    'invalidCard': ['Numéro de carte invalide', 'رقم البطاقة غير صالح', 'نمرة الكارط غالطة', 'Invalid card number'],
    'invalidExpiry': [
      'Date d\'expiration invalide',
      'تاريخ انتهاء غير صالح',
      'تاريخ الانتهاء غالط',
      'Invalid expiry date'
    ],
    'invalidCvc': ['CVC invalide', 'رمز CVC غير صالح', 'CVC غالط', 'Invalid CVC'],
    'payNow': ['Payer', 'ادفع', 'خلص', 'Pay'],
    'thanksSent': [
      'Merci ! Votre avis a été envoyé.',
      'شكرا! تم إرسال رأيك.',
      'شكرا! وصل الرأي ديالك.',
      'Thank you! Your feedback has been sent.'
    ],
    'tipPaid': ['Pourboire payé', 'تم دفع الإكرامية', 'البوربوار تخلص', 'Tip paid'],
    'badRide': [
      'Un problème pendant la course ? Faire une réclamation',
      'مشكلة أثناء الرحلة؟ قدم شكاية',
      'شي مشكل فالكورصة؟ دير شكاية',
      'A problem during the ride? File a complaint'
    ],
    'stars': ['étoiles sur 5', 'نجوم من 5', 'نجوم من 5', 'stars out of 5'],
    'tipsReceived': ['pourboires', 'إكراميات', 'البوربوار', 'tips'],
    // Compte passager, changement de destination
    'createAccount': ['Créer un compte', 'إنشاء حساب', 'صايب حساب', 'Create an account'],
    'myAccount': ['Mon compte', 'حسابي', 'الحساب ديالي', 'My account'],
    'signUpIntro': [
      'Quelques informations pour commander vos taxis en toute sécurité.',
      'بعض المعلومات لطلب سيارات الأجرة بأمان.',
      'شي معلومات باش تطلب الطاكسي بأمان.',
      'A few details to book your taxis safely.'
    ],
    'firstName': ['Prénom', 'الاسم الشخصي', 'السمية', 'First name'],
    'lastName': ['Nom', 'الاسم العائلي', 'الكنية', 'Last name'],
    'emailOptional': ['E-mail (facultatif)', 'البريد الإلكتروني (اختياري)', 'الإيميل (إلا بغيتي)', 'Email (optional)'],
    'nationality': ['Nationalité', 'الجنسية', 'الجنسية', 'Nationality'],
    'chooseNationality': ['Choisir votre nationalité', 'اختر جنسيتك', 'ختار الجنسية ديالك', 'Choose your nationality'],
    'searchCountry': ['Rechercher un pays', 'ابحث عن بلد', 'قلب على شي بلاد', 'Search for a country'],
    'privacyNationality': [
      'Votre nationalité sert uniquement à choisir la langue et à mieux aider les touristes. Elle n\'est jamais utilisée pour la publicité (loi 09-08).',
      'تستعمل جنسيتك فقط لاختيار اللغة ومساعدة السياح بشكل أفضل. لا تستعمل أبدا للإشهار (القانون 09-08).',
      'الجنسية ديالك كتستعمل غير باش نختارو اللغة ونعاونو السياح. عمرها ما كتستعمل للإشهار (القانون 09-08).',
      'Your nationality is only used to choose the language and to better assist tourists. It is never used for advertising (law 09-08).'
    ],
    'appLanguage': ['Langue de l\'application', 'لغة التطبيق', 'اللغة ديال التطبيق', 'App language'],
    'sendCode': ['Recevoir le code par SMS', 'استلام الرمز عبر SMS', 'توصل بالكود فـ SMS', 'Get the code by SMS'],
    'smsCode': ['Code reçu par SMS', 'الرمز المستلم عبر SMS', 'الكود اللي جاك فـ SMS', 'Code received by SMS'],
    'codeSentDemo': [
      'SMS simulé (démo), code :',
      'رسالة تجريبية (محاكاة)، الرمز:',
      'SMS تجريبي (ديمو)، الكود:',
      'Simulated SMS (demo), code:'
    ],
    'wrongCode': ['Code incorrect', 'رمز غير صحيح', 'الكود غالط', 'Wrong code'],
    'requiredField': ['Champ obligatoire', 'حقل إلزامي', 'خاصك تعمرها', 'Required field'],
    'invalidPhone': [
      'Numéro de téléphone invalide',
      'رقم هاتف غير صالح',
      'النمرة ديال التيليفون غالطة',
      'Invalid phone number'
    ],
    'invalidEmail': ['Adresse e-mail invalide', 'بريد إلكتروني غير صالح', 'الإيميل غالط', 'Invalid email address'],
    'verifyPhoneFirst': [
      'Vérifiez d\'abord votre numéro par SMS',
      'تحقق أولا من رقمك عبر SMS',
      'تأكد من النمرة ديالك بـ SMS قبل',
      'Verify your number by SMS first'
    ],
    'phoneVerified': ['Numéro vérifié', 'تم التحقق من الرقم', 'النمرة تأكدات', 'Number verified'],
    'saveAccount': ['Enregistrer', 'حفظ', 'سجل', 'Save'],
    'continueDemo': ['Continuer en démo', 'المتابعة في الوضع التجريبي', 'كمل فالديمو', 'Continue in demo mode'],
    'accountCreated': ['Compte créé', 'تم إنشاء الحساب', 'الحساب تصايب', 'Account created'],
    'accountSaved': ['Compte mis à jour', 'تم تحديث الحساب', 'الحساب تبدل', 'Account updated'],
    'accountId': ['Identifiant du compte', 'معرف الحساب', 'الرقم ديال الحساب', 'Account ID'],
    'changeDestTitle': ['Changer de destination ?', 'تغيير الوجهة؟', 'نبدلو البلاصة؟', 'Change destination?'],
    'fromCurrentPosition': [
      'Depuis votre position actuelle, même type de taxi',
      'من موقعك الحالي، نفس نوع الطاكسي',
      'من فين نتا دابا، نفس نوع الطاكسي',
      'From your current position, same type of taxi'
    ],
    'currentPrice': ['Prix actuel', 'السعر الحالي', 'الثمن دابا', 'Current price'],
    'newPrice': ['Nouveau prix', 'السعر الجديد', 'الثمن الجديد', 'New price'],
    'newEta': ['Nouvelle arrivée', 'الوصول الجديد', 'الوصول الجديد', 'New arrival'],
    'confirmChange': ['Confirmer', 'تأكيد', 'أكد', 'Confirm'],
    'dialCode': ['Indicatif', 'رمز الاتصال الدولي', 'الرمز ديال البلاد', 'Country code'],
    'searchDialCode': [
      'Rechercher un pays ou un indicatif',
      'ابحث عن بلد أو رمز',
      'قلب على بلاد ولا رمز',
      'Search a country or code'
    ],
    'localNumber': ['Numéro de téléphone', 'رقم الهاتف', 'النمرة ديال التيليفون', 'Phone number'],
    'requestSound': ['Son des demandes', 'صوت الطلبات', 'الصوت ديال الطلبات', 'Request sound'],
    'requestSoundDesc': [
      'Petit son doux quand un passager apparaît sur votre route',
      'صوت خفيف عندما يظهر راكب على طريقك',
      'صوت خفيف ملي كيبان شي راكب فطريقك',
      'A soft chime when a passenger appears on your route'
    ],
    'driverSettings': ['Réglages chauffeur', 'إعدادات السائق', 'الإعدادات ديال الشيفور', 'Driver settings'],
    'requestVoice': [
      'Annonce vocale de la destination',
      'الإعلان الصوتي عن الوجهة',
      'قراية الوجهة بالصوت',
      'Spoken destination'
    ],
    'mapLabel': ['Carte', 'الخريطة', 'الخريطة', 'Map'],
    'navigate': ['Naviguer', 'التنقل', 'الطريق', 'Navigate'],
    'navigateTo': ['Naviguer vers', 'التوجه إلى', 'سير عند', 'Navigate to'],
    'navStayInApp': ['Rester dans l\'application', 'البقاء في التطبيق', 'بقى فالتطبيق', 'Stay in the app'],
    'navStayInAppDesc': [
      'Itinéraire sur la carte, sans quitter Bab Taxi',
      'المسار على الخريطة دون مغادرة التطبيق',
      'الطريق فالخريطة بلا ما تخرج',
      'Route on the map, without leaving Bab Taxi'
    ],
    'navOpenIn': ['Ouvrir dans', 'فتح في', 'حل ف', 'Open in'],
    'driverDest': ['Ma destination (facultatif)', 'وجهتي (اختياري)', 'فين غادي (اختياري)', 'My destination (optional)'],
    'driverDestDesc': [
      'Vous rentrez chez vous ? Recevez uniquement les passagers sur votre trajet.',
      'راجع إلى المنزل؟ استقبل فقط الركاب الذين في طريقك.',
      'راجع للدار؟ غير الكليان اللي فطريقك.',
      'Heading home? Only get riders along your route.'
    ],
    'goingHome': ['Je rentre chez moi', 'أعود إلى المنزل', 'راجع للدار', 'Going home'],
    'otherDest': ['Autre adresse', 'عنوان آخر', 'بلاصة أخرى', 'Other address'],
    'towards': ['Vers', 'نحو', 'لـ', 'To'],
    'onMyRouteOnly': [
      'Uniquement les passagers sur votre trajet',
      'فقط الركاب الذين في طريقك',
      'غير الكليان اللي فطريقك',
      'Only riders along your route'
    ],
    'clearDest': ['Retirer ma destination', 'إزالة وجهتي', 'حيد الوجهة', 'Remove my destination'],
    'driverDestReached': [
      'Arrivé, vous êtes hors ligne',
      'وصلت، أنت الآن غير متصل',
      'وصلتي، دابا راك مطفي',
      'Arrived, you are now offline'
    ],
    'navNotInstalled': [
      "Application non installée, ouverture du Play Store",
      "التطبيق غير مثبت، فتح متجر Play",
      "التطبيق ما كاينش، كنحلو Play Store",
      "App not installed, opening the Play Store"
    ],
    'liveMode': ["Test réel", "تجربة حقيقية", "تجربة بصح", "Live test"],
    'liveModeDesc': [
      "Relie les téléphones entre eux : vrais chauffeurs, vrais passagers, vraies positions",
      "يربط الهواتف ببعضها: سائقون وركاب ومواقع حقيقية",
      "كيربط التيليفونات: شيفورات وكليان وبلايص بصح",
      "Connects phones together: real drivers, real riders, real locations"
    ],
    'liveUnreachable': [
      "Serveur injoignable, nouvel essai…",
      "تعذر الوصول إلى الخادم، إعادة المحاولة…",
      "السيرفر ما جاوبش، كنعاودو…",
      "Server unreachable, retrying…"
    ],
    'noTaxiAccepted': [
      "Aucun chauffeur n'a accepté. Réessayez dans un instant.",
      "لم يقبل أي سائق. حاول بعد قليل.",
      "حتى شيفور ما قبل. عاود من بعد شوية.",
      "No driver accepted. Try again in a moment."
    ],
    'liveDriverIntro': [
      "Votre position GPS est partagée avec les passagers tant que vous êtes en ligne.",
      "يتم مشاركة موقعك مع الركاب ما دمت متصلا.",
      "البلاصة ديالك كتبان للكليان ما دام نتا شاعل.",
      "Your GPS location is shared with riders while you are online."
    ],
    'plateOptional': [
      "Plaque du taxi (facultatif)",
      "لوحة الطاكسي (اختياري)",
      "الماتريكولا (اختياري)",
      "Taxi plate (optional)"
    ],
    'liveServer': ["Adresse du serveur", "عنوان الخادم", "عنوان السيرفر", "Server address"],
    'navAsk': ['Demander à chaque fois', 'السؤال في كل مرة', 'سولني كل مرة', 'Ask every time'],
    'navSetting': ['Navigation vers les passagers', 'التنقل نحو الركاب', 'الطريق للزبناء', 'Navigation to passengers'],
    'navRemember': [
      'Toujours utiliser ce choix',
      'استخدام هذا الاختيار دائما',
      'ديما هاد الاختيار',
      'Always use this choice'
    ],
    'navWebFallback': [
      'Application non installée : itinéraire ouvert dans le navigateur',
      'التطبيق غير مثبت: تم فتح المسار في المتصفح',
      'التطبيق ماكاينش: تحل الطريق فالمتصفح',
      'App not installed: route opened in the browser'
    ],
    'navFailed': [
      'Impossible d\'ouvrir la navigation',
      'تعذر فتح التنقل',
      'ما قدرناش نحلو الطريق',
      'Could not open navigation'
    ],
    'navGuiding': ['Guidage vers', 'التوجيه نحو', 'الطريق عند', 'Guiding to'],
    'seeInGoogleMaps': ['Voir dans Google Maps', 'عرض في Google Maps', 'شوف ف Google Maps', 'View in Google Maps'],
    'requestVoiceDesc': [
      'Lue en arabe, seulement quand le taxi est vide',
      'تقرأ بالعربية، فقط عندما تكون سيارة الأجرة فارغة',
      'بالعربية، غير ملي يكون الطاكسي خاوي',
      'Read in Arabic, only when the taxi is empty'
    ],
    'hazardLights': [
      'Allumez vos feux de détresse',
      'شغّل أضواء التنبيه',
      'شعل الضو ديال الخطر',
      'Turn on your hazard lights'
    ],
    'hazardNear': [
      'Passager à moins de 50 m',
      'الراكب على بعد أقل من 50 م',
      'الراكب قريب، أقل من 50 متر',
      'Passenger less than 50 m away'
    ],
    'toggleDetails': [
      'Afficher ou masquer les détails',
      'إظهار التفاصيل أو إخفاؤها',
      'وري ولا خبي التفاصيل',
      'Show or hide details'
    ],
    'hideAd': ['Masquer la publicité', 'إخفاء الإشهار', 'خبي الإشهار', 'Hide the ad'],
    'arrivingShort': ['Arrive dans', 'يصل خلال', 'غادي يوصل فـ', 'Arrives in'],

    // Touristes : restaurants
    'restaurantsNear': ['Restaurants près de', 'مطاعم قرب', 'ريسطورات قراب من', 'Restaurants near'],
    'tripadvisorDemo': [
      'Note TripAdvisor (démo)',
      'تقييم تريب أدفايزر (تجريبي)',
      'تقييم تريب أدفايزر (تجريبي)',
      'TripAdvisor rating (demo)'
    ],
    'reviews': ['avis', 'تقييم', 'تقييم', 'reviews'],
    'goByTaxi': ['Y aller en taxi', 'الذهاب بالطاكسي', 'سير ليه بالطاكسي', 'Take a taxi there'],
    'newDestination': ['Nouvelle destination', 'وجهة جديدة', 'بلاصة جديدة', 'New destination'],
    'cuisineMoroccan': ['Marocaine', 'مغربي', 'مغربية', 'Moroccan'],
    'cuisineSeafood': ['Poisson et fruits de mer', 'سمك ومأكولات بحرية', 'الحوت', 'Fish & seafood'],
    'cuisineCafe': ['Café, pâtisserie', 'مقهى وحلويات', 'قهوة وحلويات', 'Café & pastries'],
    'cuisineJapanese': ['Japonaise', 'ياباني', 'يابانية', 'Japanese'],
    'cuisineGrill': ['Grillades', 'مشاوي', 'الشوا', 'Grill'],
    'cuisineItalian': ['Italienne', 'إيطالي', 'طاليانية', 'Italian'],

    // Taxis électriques
    'electricTaxi': ['Électrique', 'كهربائي', 'طاكسي كهربائي', 'Electric'],
    'electricDesc': [
      '0 essence, 0 CO₂ en route',
      '0 بنزين، 0 ثاني أكسيد الكربون',
      '0 ليصانص، 0 CO₂ فالطريق',
      '0 fuel, 0 CO₂ on the road'
    ],
    'colorGreen': ['verte', 'خضراء', 'خضرا', 'green'],
    'battery': ['Batterie', 'البطارية', 'الباطري', 'Battery'],
    'chargers': ['Bornes de recharge', 'محطات الشحن', 'بلايص الشارج', 'Charging stations'],
    'goThere': ['Y aller', 'اذهب', 'سير', 'Go there'],
    'charged': ['Batterie rechargée', 'تم شحن البطارية', 'الباطري تشارجات', 'Battery charged'],
    'lowBattery': ['Batterie faible', 'البطارية ضعيفة', 'الباطري قربات تسالي', 'Low battery'],

    // Chauffeur
    'driverMode': ['Mode chauffeur', 'وضع السائق', 'وضع الشيفور', 'Driver mode'],
    'online': ['En ligne', 'متصل', 'خدام', 'Online'],
    'offline': ['Hors ligne', 'غير متصل', 'ماشي خدام', 'Offline'],
    'goOnline': ['Passer en ligne', 'ابدأ العمل', 'بدا الخدمة', 'Go online'],
    'chooseTaxiType': ['Votre taxi', 'الطاكسي الخاص بك', 'الطاكسي ديالك', 'Your taxi'],
    'seats': ['places', 'مقاعد', 'بلايص', 'seats'],
    'seat': ['place', 'مقعد', 'بلاصة', 'seat'],
    'onBoard': ['Passagers à bord', 'الركاب على متن الطاكسي', 'الناس اللي راكبين', 'Riders on board'],
    'taxiFull': ['Taxi complet', 'الطاكسي ممتلئ', 'الطاكسي عامر', 'Taxi full'],
    'newRequest': ['Passager sur votre route', 'راكب في طريقك', 'كليان فطريقك', 'Rider on your route'],
    'pickupAhead': ['à récupérer devant vous', 'في انتظارك أمامك', 'كيتسناك قدامك', 'to pick up ahead'],
    'accept': ['Accepter', 'قبول', 'قبل', 'Accept'],
    'decline': ['Refuser', 'رفض', 'رفض', 'Decline'],
    'takenByOther': [
      'Course prise par un autre chauffeur',
      'أخذ سائق آخر الرحلة',
      'شيفور آخر داها',
      'Ride taken by another driver'
    ],
    'nextStops': ['Prochains arrêts', 'المحطات القادمة', 'الوقفات الجاية', 'Next stops'],
    'noStops': [
      'Roulez, les passagers sur votre route vont apparaître',
      'واصل، سيظهر الركاب في طريقك',
      'زيد، الناس اللي فطريقك غادي يبانو',
      'Keep driving, riders on your route will appear'
    ],
    'pickUp': ['Prendre', 'إركاب', 'ركب', 'Pick up'],
    'dropAt': ['Déposer', 'إنزال', 'نزل', 'Drop off'],
    'riderPickedUp': ['Passager pris en charge', 'تم إركاب الراكب', 'الكليان طلع', 'Rider picked up'],
    'riderDropped': ['Passager déposé', 'تم إنزال الراكب', 'الكليان نزل', 'Rider dropped off'],
    'earned': ['gagnés', 'مكسب', 'ربحتي', 'earned'],
    'passengersShort': ['passagers', 'ركاب', 'كليان', 'riders'],
    'ridesShort': ['courses', 'رحلات', 'كورصات', 'rides'],
  };

  /// Clés et textes des 4 langues de base (fr, ar, dr, en).
  static Map<String, List<String>> get table => _t;

  /// Tous les textes d'une langue, clé par clé (pour vérifier dans les tests qu'aucun ne manque).
  static Map<String, String> strings(String lang) {
    final i = _i[lang];
    if (i != null) return {for (final e in _t.entries) e.key: e.value[i]};
    return _other[lang] ?? const {};
  }

  String t(String key) {
    final i = _i[lang];
    if (i != null) return _t[key]?[i] ?? key;
    // Repli sur le français si un texte manque dans une langue.
    return _other[lang]?[key] ?? _t[key]?[0] ?? key;
  }
}
