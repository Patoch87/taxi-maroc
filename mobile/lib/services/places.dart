/// Lieux connus de Casablanca, en attendant la recherche d'adresses (Google Places).
/// Sert aussi à reconnaître une destination dite à voix haute.
class Place {
  const Place(this.name, this.lat, this.lng, this.aliases);
  final String name;
  final double lat;
  final double lng;
  final List<String> aliases;

  Map<String, double> toJson() => {'lat': lat, 'lng': lng};
}

const casablancaPlaces = [
  Place('Gare Casa Voyageurs', 33.5897, -7.5906, ['casa voyageurs', 'gare', 'محطة', 'train station']),
  Place('Mosquée Hassan II', 33.6083, -7.6328, ['hassan 2', 'hassan ii', 'mosquée', 'مسجد الحسن الثاني', 'mosque']),
  Place('Twin Center', 33.5866, -7.6324, ['twin', 'maarif', 'المعاريف']),
  Place('Morocco Mall', 33.5765, -7.7056, ['morocco mall', 'mall', 'موروكو مول']),
  Place('Place des Nations Unies', 33.5967, -7.6189, ['nations unies', 'centre ville', 'وسط المدينة', 'downtown']),
  Place('Ain Diab', 33.5917, -7.6744, ['ain diab', 'corniche', 'عين الذئاب', 'beach']),
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
