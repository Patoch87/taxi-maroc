/// Lieux connus de Casablanca, en attendant la recherche d'adresses (Google Places).
/// Sert aussi à reconnaître une destination dite à voix haute.
class Place {
  const Place(this.name, this.lat, this.lng, this.aliases, {this.subtitle = 'Casablanca', this.ligne});
  final String name;
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
      subtitle: 'Boulevard Ba Hmad'),
  Place('Mosquée Hassan II', 33.6083, -7.6328, ['hassan 2', 'hassan ii', 'mosquée', 'مسجد الحسن الثاني', 'mosque'],
      subtitle: 'Boulevard de la Corniche'),
  Place('Twin Center', 33.5866, -7.6324, ['twin', 'maarif', 'المعاريف'], subtitle: 'Maârif'),
  Place('Morocco Mall', 33.5765, -7.7056, ['morocco mall', 'mall', 'موروكو مول'], subtitle: 'Aïn Diab'),
  Place('Place des Nations Unies', 33.5967, -7.6189, ['nations unies', 'centre ville', 'وسط المدينة', 'downtown'],
      subtitle: 'Centre-ville'),
  Place('Ain Diab', 33.5917, -7.6744, ['ain diab', 'corniche', 'عين الذئاب', 'beach'], subtitle: 'La Corniche'),
  Place('Gare Casa Port', 33.6006, -7.6158, ['casa port', 'port', 'ميناء'], subtitle: 'Boulevard des Almohades'),
  Place('Anfa Place', 33.5980, -7.6620, ['anfa place', 'anfa'], subtitle: 'Boulevard de la Corniche'),
  Place('Habous', 33.5790, -7.6070, ['habous', 'quartier habous', 'الأحباس'], subtitle: 'Nouvelle médina'),
  Place('Aéroport Mohammed V', 33.3675, -7.5898, ['aéroport', 'aeroport', 'airport', 'مطار'], subtitle: 'Nouaceur'),
  Place('Mohammedia', 33.6866, -7.3830, ['mohammedia', 'المحمدية'], subtitle: 'Grand taxi', ligne: 'casa-mohammedia'),
  Place('Berrechid', 33.2655, -7.5876, ['berrechid', 'برشيد'], subtitle: 'Grand taxi', ligne: 'casa-berrechid'),
  Place('El Jadida', 33.2316, -8.5007, ['el jadida', 'jadida', 'الجديدة'], subtitle: 'Grand taxi', ligne: 'casa-eljadida'),
];

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
  return casablancaPlaces
      .where((p) => p.name.toLowerCase().contains(q) || p.aliases.any((a) => a.toLowerCase().contains(q)))
      .toList();
}
