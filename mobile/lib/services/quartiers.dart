import 'places.dart';

/// Quartiers de Casablanca (centre approximatif) : le chauffeur dit à voix haute vers lequel il va,
/// et ne reçoit plus que les passagers sur sa route.
const casablancaQuartiers = [
  Place('Maârif', 33.5850, -7.6330, ['maarif', 'maaref', 'lmaarif', 'el maarif', 'المعاريف', 'معاريف'],
      subtitle: 'Quartier', ar: 'المعاريف'),
  Place('Gauthier', 33.5905, -7.6275, ['gauthier', 'gautier', 'goti', 'غوتيي', 'غوتييه'],
      subtitle: 'Quartier', ar: 'غوتيي'),
  Place('Racine', 33.5885, -7.6395, ['racine', 'rasine', 'راسين'], subtitle: 'Quartier', ar: 'راسين'),
  Place('Bourgogne', 33.5985, -7.6400, ['bourgogne', 'bourgoune', 'bourgogn', 'بوركون', 'بورغون'],
      subtitle: 'Quartier', ar: 'بوركون'),
  Place('Centre-ville', 33.5960, -7.6180, ['centre ville', 'centre', 'downtown', 'wast lmdina', 'وسط المدينة'],
      subtitle: 'Quartier', ar: 'وسط المدينة'),
  Place('Ancienne Médina', 33.6030, -7.6190, ['ancienne medina', 'medina', 'mdina l9dima', 'المدينة القديمة'],
      subtitle: 'Quartier', ar: 'المدينة القديمة'),
  Place('Anfa', 33.5960, -7.6520, ['anfa', 'anfa superieur', 'أنفا', 'انفا'], subtitle: 'Quartier', ar: 'أنفا'),
  Place('Aïn Diab', 33.5900, -7.6900, ['ain diab', 'ain dyab', 'ayn diab', 'corniche', 'عين الذئاب', 'عين الدياب'],
      subtitle: 'Quartier', ar: 'عين الذئاب'),
  Place('Palmier', 33.5795, -7.6225, ['palmier', 'palmiers', 'النخيل'], subtitle: 'Quartier', ar: 'النخيل'),
  Place('Mers Sultan', 33.5855, -7.6130, ['mers sultan', 'mers soltane', 'مرس السلطان'],
      subtitle: 'Quartier', ar: 'مرس السلطان'),
  Place('Habous', 33.5780, -7.6050, ['habous', 'lahbous', 'hbous', 'الأحباس', 'الحبوس'],
      subtitle: 'Quartier', ar: 'الأحباس'),
  Place('Derb Sultan', 33.5745, -7.5985, ['derb sultan', 'derb soltane', 'derb sultane', 'درب السلطان'],
      subtitle: 'Quartier', ar: 'درب السلطان'),
  Place('Belvédère', 33.5980, -7.5900, ['belvedere', 'belveder', 'بلفدير'], subtitle: 'Quartier', ar: 'بلفدير'),
  Place('Roches Noires', 33.6020, -7.5750, ['roches noires', 'roche noire', 'roch noir', 'الصخور السوداء'],
      subtitle: 'Quartier', ar: 'الصخور السوداء'),
  Place('Hay Mohammadi', 33.5895, -7.5650, ['hay mohammadi', 'hay mohamadi', 'lhay lmohammadi', 'الحي المحمدي'],
      subtitle: 'Quartier', ar: 'الحي المحمدي'),
  Place('Aïn Sebaâ', 33.6060, -7.5380, ['ain sebaa', 'ain seba', 'ayn sebaa', 'عين السبع'],
      subtitle: 'Quartier', ar: 'عين السبع'),
  Place('Sidi Bernoussi', 33.6100, -7.5000, ['sidi bernoussi', 'bernoussi', 'sidi bernousi', 'سيدي البرنوصي'],
      subtitle: 'Quartier', ar: 'سيدي البرنوصي'),
  Place('Sidi Moumen', 33.5820, -7.5100, ['sidi moumen', 'sidi momen', 'سيدي مومن'], subtitle: 'Quartier', ar: 'سيدي مومن'),
  Place('Ben M\'Sik', 33.5600, -7.5750, ['ben msik', 'ben m sik', 'benmsik', 'بن امسيك', 'بنمسيك'],
      subtitle: 'Quartier', ar: 'بن امسيك'),
  Place('Sbata', 33.5480, -7.5600, ['sbata', 'sebata', 'سباتة'], subtitle: 'Quartier', ar: 'سباتة'),
  Place('Moulay Rachid', 33.5650, -7.5250, ['moulay rachid', 'moulay rachide', 'مولاي رشيد'],
      subtitle: 'Quartier', ar: 'مولاي رشيد'),
  Place('Aïn Chock', 33.5450, -7.5950, ['ain chock', 'ain chok', 'ain chouk', 'عين الشق'],
      subtitle: 'Quartier', ar: 'عين الشق'),
  Place('Polo', 33.5545, -7.6030, ['polo', 'بولو'], subtitle: 'Quartier', ar: 'بولو'),
  Place('Oasis', 33.5560, -7.6280, ['oasis', 'loasis', 'الواحة', 'لوازيس'], subtitle: 'Quartier', ar: 'الواحة'),
  Place('Californie', 33.5420, -7.6250, ['californie', 'california', 'كاليفورنيا'],
      subtitle: 'Quartier', ar: 'كاليفورنيا'),
  Place('Sidi Maârouf', 33.5300, -7.6420, ['sidi maarouf', 'sidi marouf', 'sidi maaruf', 'سيدي معروف'],
      subtitle: 'Quartier', ar: 'سيدي معروف'),
  Place('CIL', 33.5730, -7.6500, ['cil', 'hay cil', 'سيل'], subtitle: 'Quartier', ar: 'سيل'),
  Place('Hay Hassani', 33.5650, -7.6750, ['hay hassani', 'hay hasani', 'lhay lhassani', 'الحي الحسني'],
      subtitle: 'Quartier', ar: 'الحي الحسني'),
  Place('Oulfa', 33.5530, -7.6680, ['oulfa', 'ulfa', 'olfa', 'الألفة', 'الالفة'], subtitle: 'Quartier', ar: 'الألفة'),
  Place('Lissasfa', 33.5350, -7.6750, ['lissasfa', 'lisasfa', 'ليساسفة'], subtitle: 'Quartier', ar: 'ليساسفة'),
  Place('Bouskoura', 33.4500, -7.6500, ['bouskoura', 'bouskora', 'بوسكورة'], subtitle: 'Quartier', ar: 'بوسكورة'),
];

const _accents = {
  'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ç': 'c', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', //
  'î': 'i', 'ï': 'i', 'í': 'i', 'ô': 'o', 'ö': 'o', 'ó': 'o', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u',
  'أ': 'ا', 'إ': 'ا', 'آ': 'ا', 'ٱ': 'ا', 'ة': 'ه', 'ى': 'ي', 'ؤ': 'و', 'ئ': 'ي', 'ڭ': 'ك', 'گ': 'ك',
};

/// Écriture simplifiée pour comparer ce qui est dit et le nom du quartier :
/// sans accents ni ponctuation, « ou » = « u », « y » = « i », lettres doublées simplifiées,
/// arabe sans voyelles ni article « ال » (ni « لل » : « غادي للمعاريف »).
String normalizeQuartier(String text) {
  var t = text.toLowerCase();
  t = t.split('').map((c) => _accents[c] ?? c).join();
  t = t.replaceAll(RegExp('[ً-ْـ]'), ''); // voyelles arabes et tatweel
  t = t.replaceAll(RegExp(r"[^a-z0-9؀-ۿ]+"), ' ');
  t = t.replaceAll('ou', 'u').replaceAll('y', 'i').replaceAll('sh', 'ch');
  t = t.replaceAllMapped(RegExp(r'([a-z])\1+'), (m) => m[1]!);
  return t
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => w.length <= 3
          ? w
          : w.startsWith('ال') || w.startsWith('لل')
              ? w.substring(2)
              // « بال », « وال », « فال », « كال » : préposition collée à l'article.
              : RegExp('^[وبفك]ال').hasMatch(w) && w.length > 4
                  ? w.substring(3)
                  : w)
      .join(' ');
}

int _distance(String a, String b) {
  if (a == b) return 0;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = [i, ...List.filled(b.length, 0)];
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      cur[j] = [prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost].reduce((x, y) => x < y ? x : y);
    }
    prev = cur;
  }
  return prev[b.length];
}

/// Trouve le quartier dit à voix haute (« Je vais au Maârif », « l'Maarif », « المعاريف »...), sinon null.
Place? findQuartier(String spoken) {
  final q = normalizeQuartier(spoken);
  if (q.isEmpty) return null;
  final words = q.split(' ');
  Place? best;
  var bestScore = 0.0;
  for (final p in casablancaQuartiers) {
    for (final alias in [p.name, ...p.aliases]) {
      final k = normalizeQuartier(alias);
      if (k.isEmpty) continue;
      final n = k.split(' ').length;
      final key = k.replaceAll(' ', '');
      // Les mots dits, regroupés par autant de mots que le nom du quartier (« sidi » + « maarouf »).
      for (var i = 0; i + n <= words.length; i++) {
        final said = words.sublist(i, i + n).join();
        final d = _distance(said, key);
        // Petite faute de reconnaissance tolérée sur les noms assez longs.
        final allowed = key.length <= 4 ? 0 : (key.length <= 8 ? 1 : 2);
        if (d > allowed) continue;
        final score = key.length - d * 2.0;
        if (score > bestScore) {
          bestScore = score;
          best = p;
        }
      }
    }
  }
  return best;
}
