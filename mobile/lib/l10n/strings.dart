/// Textes de l'application en français, arabe, darija marocaine et anglais.
class S {
  S(this.lang);
  final String lang;

  /// fr : français, ar : arabe, dr : darija marocaine (écrite en arabe), en : anglais.
  static const supported = ['fr', 'ar', 'dr', 'en'];
  static const names = {'fr': 'Français', 'ar': 'العربية', 'dr': 'الدارجة', 'en': 'English'};

  static const _i = {'fr': 0, 'ar': 1, 'dr': 2, 'en': 3};

  /// Langues écrites de droite à gauche.
  bool get rtl => lang == 'ar' || lang == 'dr';

  /// Langue de la reconnaissance et de la synthèse vocales.
  String get speechLocale => switch (lang) { 'ar' || 'dr' => 'ar-MA', 'en' => 'en-US', _ => 'fr-FR' };

  static const Map<String, List<String>> _t = {
    // Général
    'appTitle': ['Taxi Maroc', 'طاكسي المغرب', 'طاكسي المغرب', 'Taxi Morocco'],
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
      'Le premier qui accepte prend la course, les autres sont bloqués',
      'أول سائق يقبل يأخذ الرحلة والباقي يتوقف',
      'اللي قبل اللول هو اللي غادي يجي، والباقين يتبلوكاو',
      'The first to accept gets the ride, the others are blocked'
    ],
    'acceptedFirst': ['a accepté en premier', 'قبل أولا', 'قبل هو اللول', 'accepted first'],
    'declined': ['a refusé', 'رفض', 'رفض', 'declined'],
    'blocked': ['bloqué', 'محظور', 'تبلوكا', 'blocked'],
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
      'Je suis en taxi avec Taxi Maroc',
      'أنا في طاكسي مع طاكسي المغرب',
      'راني فطاكسي مع طاكسي المغرب',
      'I\'m in a taxi with Taxi Morocco'
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
    'tripDone': ['Vous êtes arrivé 🎉', 'لقد وصلت 🎉', 'وصلتي 🎉', 'You have arrived 🎉'],
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
      'un taxi a été commandé pour vous avec Taxi Maroc.',
      'تم طلب طاكسي لك عبر طاكسي المغرب.',
      'طلبنا ليك طاكسي مع طاكسي المغرب.',
      'a taxi has been booked for you with Taxi Morocco.'
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
    'offersSetting': [
      'Offres personnalisées selon mes trajets',
      'عروض مخصصة حسب رحلاتي',
      'عروض على حساب الكورصات ديالي',
      'Offers based on my trips'
    ],
    'offersWhy': [
      'Basé sur votre destination et vos trajets, jamais sur vos données personnelles',
      'حسب وجهتك ورحلاتك، وليس أبدا حسب بياناتك الشخصية',
      'على حساب فين غادي والكورصات ديالك، عمرو ما على المعلومات الشخصية ديالك',
      'Based on your destination and trips, never on your personal data'
    ],
    'seeOffer': ['Voir une offre', 'عرض متاح', 'شوف واحد العرض', 'See an offer'],
    'promoZara': [
      '-15 % chez Zara au Morocco Mall',
      '-15٪ في زارا بموروكو مول',
      '-15٪ عند زارا فموروكو مول',
      '15% off at Zara, Morocco Mall'
    ],
    'promoZaraDetail': [
      'Montrez ce trajet en caisse, valable aujourd\'hui',
      'أظهر هذه الرحلة عند الأداء، صالح اليوم',
      'وري هاد الكورصة فالكيس، صالح اليوم',
      'Show this trip at checkout, valid today'
    ],
    'promoKool': [
      'Koolsmoothie : un smoothie offert pour un acheté',
      'كولسموذي: عصير مجاني عند شراء واحد',
      'كولسموذي: شري واحد وخود واحد فابور',
      'Koolsmoothie: buy one smoothie, get one free'
    ],
    'promoKoolDetail': [
      'Près de votre destination, jusqu\'à 20 h',
      'قرب وجهتك، حتى الساعة 20',
      'قريب من فين غادي، حتى ل 8 دالليل',
      'Near your destination, until 8 pm'
    ],
    'promoCafe': [
      'Café de la Gare : café offert avec un croissant',
      'مقهى المحطة: قهوة مجانية مع كرواسون',
      'قهوة لاكار: قهوة فابور مع كرواصة',
      'Café de la Gare: free coffee with a croissant'
    ],
    'promoCafeDetail': [
      'Avant 11 h, sur présentation du trajet',
      'قبل الساعة 11، بتقديم الرحلة',
      'قبل 11، وري الكورصة',
      'Before 11 am, show your trip'
    ],

    'promoGeneric': ['Votre publicité ici', 'إشهارك هنا', 'الإشهار ديالك هنا', 'Your ad here'],
    'promoGenericDetail': [
      'Annonce non personnalisée',
      'إعلان غير مخصص',
      'إشهار ماشي على حسابك',
      'Non-personalised ad'
    ],
    'mapView': ['Carte plein écran', 'الخريطة بملء الشاشة', 'الخريطة فالشاشة كاملة', 'Full-screen map'],
    'detailsView': ['Afficher les détails', 'عرض التفاصيل', 'وري التفاصيل', 'Show details'],
    'hideAd': ['Masquer la publicité', 'إخفاء الإشهار', 'خبي الإشهار', 'Hide the ad'],
    'arrivingShort': ['Arrive dans', 'يصل خلال', 'غادي يوصل فـ', 'Arrives in'],

    // Touristes : restaurants
    'touristMode': ['Je suis touriste', 'أنا سائح', 'أنا سائح', 'I am a tourist'],
    'touristDesc': [
      'Restaurants proposés près de votre destination',
      'مطاعم مقترحة قرب وجهتك',
      'ريسطورات قراب من فين غادي',
      'Restaurant ideas near your destination'
    ],
    'restaurantsNear': ['Restaurants près de', 'مطاعم قرب', 'ريسطورات قراب من', 'Restaurants near'],
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

  /// Clés et traductions (pour vérifier dans les tests que chaque texte existe dans les 4 langues).
  static Map<String, List<String>> get table => _t;

  String t(String key) {
    final row = _t[key];
    if (row == null) return key;
    return row[_i[lang] ?? 0];
  }
}
