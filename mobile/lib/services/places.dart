/// Lieux connus de Casablanca, en attendant la recherche d'adresses (Google Places).
/// Sert aussi à reconnaître une destination dite à voix haute.
class Place {
  const Place(this.name, this.lat, this.lng, this.aliases, {this.subtitle = 'Casablanca', this.ligne, this.ar});
  final String name;

  /// Nom en arabe (annonce vocale de la destination aux chauffeurs) ; sinon le nom français.
  final String? ar;
  String get arabicName => ar ?? name;
  final double lat;
  final double lng;
  final List<String> aliases;
  final String subtitle;

  /// Ligne de grand taxi (backend/src/domain/tariffs.ts) pour les destinations hors de la ville.
  final String? ligne;

  bool get intercity => ligne != null;

  Map<String, double> toJson() => {'lat': lat, 'lng': lng};
}

const casablancaPlaces = [
  Place('Gare Casa Voyageurs', 33.5897, -7.5906, ['casa voyageurs', 'gare', 'محطة', 'train station'],
      subtitle: 'Boulevard Ba Hmad', ar: 'محطة الدار البيضاء المسافرين'),
  Place('Mosquée Hassan II', 33.6083, -7.6328, ['hassan 2', 'hassan ii', 'mosquée', 'مسجد الحسن الثاني', 'mosque'],
      subtitle: 'Boulevard de la Corniche', ar: 'مسجد الحسن الثاني'),
  Place('Twin Center', 33.5866, -7.6324, ['twin', 'maarif', 'المعاريف'], subtitle: 'Maârif', ar: 'توين سنتر'),
  Place('Morocco Mall', 33.5765, -7.7056, ['morocco mall', 'mall', 'موروكو مول'],
      subtitle: 'Aïn Diab', ar: 'موروكو مول'),
  Place('Place des Nations Unies', 33.5967, -7.6189, ['nations unies', 'centre ville', 'وسط المدينة', 'downtown'],
      subtitle: 'Centre-ville', ar: 'ساحة الأمم المتحدة'),
  Place('Ain Diab', 33.5917, -7.6744, ['ain diab', 'corniche', 'عين الذئاب', 'beach'],
      subtitle: 'La Corniche', ar: 'عين الذئاب'),
  Place('Gare Casa Port', 33.6006, -7.6158, ['casa port', 'port', 'ميناء'],
      subtitle: 'Boulevard des Almohades', ar: 'محطة الدار البيضاء الميناء'),
  Place('Anfa Place', 33.5980, -7.6620, ['anfa place', 'anfa'], subtitle: 'Boulevard de la Corniche', ar: 'أنفا بلاص'),
  Place('Habous', 33.5790, -7.6070, ['habous', 'quartier habous', 'الأحباس'],
      subtitle: 'Nouvelle médina', ar: 'حي الأحباس'),
  Place('Aéroport Mohammed V', 33.3675, -7.5898, ['aéroport', 'aeroport', 'airport', 'مطار'],
      subtitle: 'Nouaceur', ar: 'مطار محمد الخامس'),
  Place('Mohammedia', 33.6866, -7.3830, ['mohammedia', 'المحمدية'],
      subtitle: 'Grand taxi', ligne: 'casa-mohammedia', ar: 'المحمدية'),
  Place('Berrechid', 33.2655, -7.5876, ['berrechid', 'برشيد'],
      subtitle: 'Grand taxi', ligne: 'casa-berrechid', ar: 'برشيد'),
  Place('El Jadida', 33.2316, -8.5007, ['el jadida', 'jadida', 'الجديدة'],
      subtitle: 'Grand taxi', ligne: 'casa-eljadida', ar: 'الجديدة'),
];

/// Nom arabe d'un lieu connu (pour l'annonce vocale), sinon le nom tel quel.
String arabicPlaceName(String name) =>
    [...casablancaPlaces, homePlace, workPlace].where((p) => p.name == name).firstOrNull?.arabicName ?? name;

/// Adresses enregistrées de la démo.
const homePlace =
    Place('Maison', 33.5891, -7.6326, ['maison', 'dar', 'الدار', 'home'], subtitle: 'Quartier Gauthier', ar: 'الدار');
const workPlace = Place('Travail', 33.5617, -7.6587, ['travail', 'khedma', 'الخدمة', 'work'],
    subtitle: 'Casablanca Finance City', ar: 'الخدمة');

/// Trouve un lieu à partir d'un texte tapé ou dicté.
Place? findPlace(String text) {
  final q = text.toLowerCase();
  for (final p in casablancaPlaces) {
    if (q.contains(p.name.toLowerCase()) || p.aliases.any((a) => q.contains(a.toLowerCase()))) {
      return p;
    }
  }
  return null;
}

/// Lieux dont le nom ou un alias contient le texte recherché.
List<Place> searchPlaces(String text) {
  final q = text.trim().toLowerCase();
  if (q.isEmpty) return casablancaPlaces;
  bool hit(String a) => a.toLowerCase().contains(q) || (q.length > 3 && q.contains(a.toLowerCase()));
  return casablancaPlaces.where((p) => hit(p.name) || p.aliases.any(hit)).toList();
}

/// Bornes de recharge pour les taxis électriques (données de démo).
const chargingStations = [
  Place('Borne Anfa', 33.5935, -7.6455, ['anfa'], subtitle: 'Boulevard d\'Anfa'),
  Place('Borne Maârif', 33.5845, -7.6360, ['maarif'], subtitle: 'Rue Abou Bakr El Kadiri'),
  Place('Borne Sidi Maârouf', 33.5340, -7.6430, ['sidi maarouf'], subtitle: 'Technopark'),
  Place('Borne Aïn Sebaâ', 33.6050, -7.5330, ['ain sebaa'], subtitle: 'Route de Rabat'),
];
