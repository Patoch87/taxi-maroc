import { haversine, Point } from '../domain/geo';

/** Lieu que le passager peut dire : lieu connu, quartier, ou adresse trouvée sur OpenStreetMap. */
export interface Lieu {
  id: string;
  nom: string;
  /** Nom en arabe, pour les réponses en darija. */
  ar: string;
  quartier: string;
  type: 'lieu' | 'quartier' | 'adresse';
  lat: number;
  lng: number;
  alias?: string[];
  /** Ligne de grand taxi (domain/tariffs.ts) pour les destinations hors de Casablanca. */
  ligne?: string;
}

/** Lieux connus et quartiers de Casablanca, repris de l'appli (mobile/lib/services/places.dart et quartiers.dart). */
export const CATALOGUE: Lieu[] = [
  {id: "L1", nom: "Gare Casa Voyageurs", ar: "محطة الدار البيضاء المسافرين", quartier: "Boulevard Ba Hmad", type: "lieu", lat: 33.5897, lng: -7.5906, alias: ["casa voyageurs", "gare", "محطة", "train station"]},
  {id: "L2", nom: "Mosquée Hassan II", ar: "مسجد الحسن الثاني", quartier: "Boulevard de la Corniche", type: "lieu", lat: 33.6083, lng: -7.6328, alias: ["hassan 2", "hassan ii", "mosquée", "مسجد الحسن الثاني", "mosque"]},
  {id: "L3", nom: "Twin Center", ar: "توين سنتر", quartier: "Maârif", type: "lieu", lat: 33.5866, lng: -7.6324, alias: ["twin", "maarif", "المعاريف"]},
  {id: "L4", nom: "Morocco Mall", ar: "موروكو مول", quartier: "Aïn Diab", type: "lieu", lat: 33.5765, lng: -7.7056, alias: ["morocco mall", "mall", "موروكو مول"]},
  {id: "L5", nom: "Place des Nations Unies", ar: "ساحة الأمم المتحدة", quartier: "Centre-ville", type: "lieu", lat: 33.5967, lng: -7.6189, alias: ["nations unies", "centre ville", "وسط المدينة", "downtown"]},
  {id: "L6", nom: "Ain Diab", ar: "عين الذئاب", quartier: "La Corniche", type: "lieu", lat: 33.5917, lng: -7.6744, alias: ["ain diab", "corniche", "عين الذئاب", "beach"]},
  {id: "L7", nom: "Gare Casa Port", ar: "محطة الدار البيضاء الميناء", quartier: "Boulevard des Almohades", type: "lieu", lat: 33.6006, lng: -7.6158, alias: ["casa port", "port", "ميناء"]},
  {id: "L8", nom: "Anfa Place", ar: "أنفا بلاص", quartier: "Boulevard de la Corniche", type: "lieu", lat: 33.598, lng: -7.662, alias: ["anfa place", "anfa"]},
  {id: "L9", nom: "Habous", ar: "حي الأحباس", quartier: "Nouvelle médina", type: "lieu", lat: 33.579, lng: -7.607, alias: ["habous", "quartier habous", "الأحباس"]},
  {id: "L10", nom: "Aéroport Mohammed V", ar: "مطار محمد الخامس", quartier: "Nouaceur", type: "lieu", lat: 33.3675, lng: -7.5898, alias: ["aéroport", "aeroport", "airport", "مطار"]},
  {id: "L11", nom: "Mohammedia", ar: "المحمدية", quartier: "Grand taxi", type: "lieu", lat: 33.6866, lng: -7.383, alias: ["mohammedia", "المحمدية"], ligne: "casa-mohammedia"},
  {id: "L12", nom: "Berrechid", ar: "برشيد", quartier: "Grand taxi", type: "lieu", lat: 33.2655, lng: -7.5876, alias: ["berrechid", "برشيد"], ligne: "casa-berrechid"},
  {id: "L13", nom: "El Jadida", ar: "الجديدة", quartier: "Grand taxi", type: "lieu", lat: 33.2316, lng: -8.5007, alias: ["el jadida", "jadida", "الجديدة"], ligne: "casa-eljadida"},
  {id: "Q14", nom: "Maârif", ar: "المعاريف", quartier: "Quartier", type: "quartier", lat: 33.585, lng: -7.633, alias: ["maarif", "maaref", "lmaarif", "el maarif", "المعاريف", "معاريف"]},
  {id: "Q15", nom: "Gauthier", ar: "غوتيي", quartier: "Quartier", type: "quartier", lat: 33.5905, lng: -7.6275, alias: ["gauthier", "gautier", "goti", "غوتيي", "غوتييه"]},
  {id: "Q16", nom: "Racine", ar: "راسين", quartier: "Quartier", type: "quartier", lat: 33.5885, lng: -7.6395, alias: ["racine", "rasine", "راسين"]},
  {id: "Q17", nom: "Bourgogne", ar: "بوركون", quartier: "Quartier", type: "quartier", lat: 33.5985, lng: -7.64, alias: ["bourgogne", "bourgoune", "bourgogn", "بوركون", "بورغون"]},
  {id: "Q18", nom: "Centre-ville", ar: "وسط المدينة", quartier: "Quartier", type: "quartier", lat: 33.596, lng: -7.618, alias: ["centre ville", "centre", "downtown", "wast lmdina", "وسط المدينة"]},
  {id: "Q19", nom: "Ancienne Médina", ar: "المدينة القديمة", quartier: "Quartier", type: "quartier", lat: 33.603, lng: -7.619, alias: ["ancienne medina", "medina", "mdina l9dima", "المدينة القديمة"]},
  {id: "Q20", nom: "Anfa", ar: "أنفا", quartier: "Quartier", type: "quartier", lat: 33.596, lng: -7.652, alias: ["anfa", "anfa superieur", "أنفا", "انفا"]},
  {id: "Q21", nom: "Aïn Diab", ar: "عين الذئاب", quartier: "Quartier", type: "quartier", lat: 33.59, lng: -7.69, alias: ["ain diab", "ain dyab", "ayn diab", "corniche", "عين الذئاب", "عين الدياب"]},
  {id: "Q22", nom: "Palmier", ar: "النخيل", quartier: "Quartier", type: "quartier", lat: 33.5795, lng: -7.6225, alias: ["palmier", "palmiers", "النخيل"]},
  {id: "Q23", nom: "Mers Sultan", ar: "مرس السلطان", quartier: "Quartier", type: "quartier", lat: 33.5855, lng: -7.613, alias: ["mers sultan", "mers soltane", "مرس السلطان"]},
  {id: "Q24", nom: "Habous", ar: "الأحباس", quartier: "Quartier", type: "quartier", lat: 33.578, lng: -7.605, alias: ["habous", "lahbous", "hbous", "الأحباس", "الحبوس"]},
  {id: "Q25", nom: "Derb Sultan", ar: "درب السلطان", quartier: "Quartier", type: "quartier", lat: 33.5745, lng: -7.5985, alias: ["derb sultan", "derb soltane", "derb sultane", "درب السلطان"]},
  {id: "Q26", nom: "Belvédère", ar: "بلفدير", quartier: "Quartier", type: "quartier", lat: 33.598, lng: -7.59, alias: ["belvedere", "belveder", "بلفدير"]},
  {id: "Q27", nom: "Roches Noires", ar: "الصخور السوداء", quartier: "Quartier", type: "quartier", lat: 33.602, lng: -7.575, alias: ["roches noires", "roche noire", "roch noir", "الصخور السوداء"]},
  {id: "Q28", nom: "Hay Mohammadi", ar: "الحي المحمدي", quartier: "Quartier", type: "quartier", lat: 33.5895, lng: -7.565, alias: ["hay mohammadi", "hay mohamadi", "lhay lmohammadi", "الحي المحمدي"]},
  {id: "Q29", nom: "Aïn Sebaâ", ar: "عين السبع", quartier: "Quartier", type: "quartier", lat: 33.606, lng: -7.538, alias: ["ain sebaa", "ain seba", "ayn sebaa", "عين السبع"]},
  {id: "Q30", nom: "Sidi Bernoussi", ar: "سيدي البرنوصي", quartier: "Quartier", type: "quartier", lat: 33.61, lng: -7.5, alias: ["sidi bernoussi", "bernoussi", "sidi bernousi", "سيدي البرنوصي"]},
  {id: "Q31", nom: "Sidi Moumen", ar: "سيدي مومن", quartier: "Quartier", type: "quartier", lat: 33.582, lng: -7.51, alias: ["sidi moumen", "sidi momen", "سيدي مومن"]},
  {id: "Q32", nom: "Ben M'Sik", ar: "بن امسيك", quartier: "Quartier", type: "quartier", lat: 33.56, lng: -7.575, alias: ["ben msik", "ben m sik", "benmsik", "بن امسيك", "بنمسيك"]},
  {id: "Q33", nom: "Sbata", ar: "سباتة", quartier: "Quartier", type: "quartier", lat: 33.548, lng: -7.56, alias: ["sbata", "sebata", "سباتة"]},
  {id: "Q34", nom: "Moulay Rachid", ar: "مولاي رشيد", quartier: "Quartier", type: "quartier", lat: 33.565, lng: -7.525, alias: ["moulay rachid", "moulay rachide", "مولاي رشيد"]},
  {id: "Q35", nom: "Aïn Chock", ar: "عين الشق", quartier: "Quartier", type: "quartier", lat: 33.545, lng: -7.595, alias: ["ain chock", "ain chok", "ain chouk", "عين الشق"]},
  {id: "Q36", nom: "Polo", ar: "بولو", quartier: "Quartier", type: "quartier", lat: 33.5545, lng: -7.603, alias: ["polo", "بولو"]},
  {id: "Q37", nom: "Oasis", ar: "الواحة", quartier: "Quartier", type: "quartier", lat: 33.556, lng: -7.628, alias: ["oasis", "loasis", "الواحة", "لوازيس"]},
  {id: "Q38", nom: "Californie", ar: "كاليفورنيا", quartier: "Quartier", type: "quartier", lat: 33.542, lng: -7.625, alias: ["californie", "california", "كاليفورنيا"]},
  {id: "Q39", nom: "Sidi Maârouf", ar: "سيدي معروف", quartier: "Quartier", type: "quartier", lat: 33.53, lng: -7.642, alias: ["sidi maarouf", "sidi marouf", "sidi maaruf", "سيدي معروف"]},
  {id: "Q40", nom: "CIL", ar: "سيل", quartier: "Quartier", type: "quartier", lat: 33.573, lng: -7.65, alias: ["cil", "hay cil", "سيل"]},
  {id: "Q41", nom: "Hay Hassani", ar: "الحي الحسني", quartier: "Quartier", type: "quartier", lat: 33.565, lng: -7.675, alias: ["hay hassani", "hay hasani", "lhay lhassani", "الحي الحسني"]},
  {id: "Q42", nom: "Oulfa", ar: "الألفة", quartier: "Quartier", type: "quartier", lat: 33.553, lng: -7.668, alias: ["oulfa", "ulfa", "olfa", "الألفة", "الالفة"]},
  {id: "Q43", nom: "Lissasfa", ar: "ليساسفة", quartier: "Quartier", type: "quartier", lat: 33.535, lng: -7.675, alias: ["lissasfa", "lisasfa", "ليساسفة"]},
  {id: "Q44", nom: "Bouskoura", ar: "بوسكورة", quartier: "Quartier", type: "quartier", lat: 33.45, lng: -7.65, alias: ["bouskoura", "bouskora", "بوسكورة"]},];

const ACCENTS: Record<string, string> = {
  à: 'a', â: 'a', ä: 'a', á: 'a', ç: 'c', é: 'e', è: 'e', ê: 'e', ë: 'e', î: 'i', ï: 'i', í: 'i',
  ô: 'o', ö: 'o', ó: 'o', ù: 'u', û: 'u', ü: 'u', ú: 'u',
  'أ': 'ا', 'إ': 'ا', 'آ': 'ا', 'ٱ': 'ا', 'ة': 'ه', 'ى': 'ي', 'ؤ': 'و', 'ئ': 'ي', 'ڭ': 'ك', 'گ': 'ك',
};

/**
 * Même écriture simplifiée que l'appli (normalizeQuartier) : sans accents, « ou » = « u », « y » = « i »,
 * lettres doublées simplifiées, arabe sans voyelles ni article « ال ».
 */
export function normaliser(texte: string): string {
  let t = [...texte.toLowerCase()].map((c) => ACCENTS[c] ?? c).join('');
  t = t.replace(/[ً-ْـ]/g, '');
  t = t.replace(/[^a-z0-9؀-ۿ]+/g, ' ');
  t = t.replace(/ou/g, 'u').replace(/y/g, 'i').replace(/sh/g, 'ch');
  t = t.replace(/([a-z])\1+/g, '$1');
  return t
    .split(' ')
    .filter((w) => w)
    .map((w) =>
      w.length <= 3 ? w : w.startsWith('ال') || w.startsWith('لل') ? w.slice(2) : /^[وبفك]ال/.test(w) && w.length > 4 ? w.slice(3) : w,
    )
    .join(' ');
}

function distanceEdition(a: string, b: string): number {
  if (a === b) return 0;
  let prev = Array.from({ length: b.length + 1 }, (_, i) => i);
  for (let i = 1; i <= a.length; i++) {
    const cur = [i];
    for (let j = 1; j <= b.length; j++) {
      cur[j] = Math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1));
    }
    prev = cur;
  }
  return prev[b.length];
}

/** Lieux du catalogue reconnus dans une phrase (« je vais au Maarif », « لمطار »), les plus sûrs d'abord. */
export function chercherCatalogue(texte: string): Lieu[] {
  const mots = normaliser(texte).split(' ').filter((w) => w);
  const scores = new Map<Lieu, number>();
  for (const lieu of CATALOGUE) {
    for (const alias of [lieu.nom, lieu.ar, ...(lieu.alias ?? [])]) {
      const k = normaliser(alias);
      if (!k) continue;
      const n = k.split(' ').length;
      const cle = k.replace(/ /g, '');
      for (let i = 0; i + n <= mots.length; i++) {
        const dit = mots.slice(i, i + n).join('');
        const d = distanceEdition(dit, cle);
        // Petite faute de reconnaissance vocale tolérée sur les noms assez longs.
        const tolere = cle.length <= 4 ? 0 : cle.length <= 8 ? 1 : 2;
        if (d > tolere) continue;
        // À égalité, le lieu dont c'est le vrai nom passe avant celui qui l'a en alias (Maârif avant Twin Center).
        const score = cle.length - d * 2 + (alias === lieu.nom || alias === lieu.ar ? 1 : 0);
        if (score > (scores.get(lieu) ?? 0)) scores.set(lieu, score);
      }
    }
  }
  return [...scores.entries()].sort((a, b) => b[1] - a[1]).map(([l]) => l);
}

export function trouverParId(id: string, extra: Lieu[] = []): Lieu | undefined {
  return [...CATALOGUE, ...extra].find((l) => l.id === id);
}

/** Centre de Casablanca : sert à préférer les adresses proches. */
export const CASABLANCA: Point = { lat: 33.5731, lng: -7.5898 };

/**
 * Adresse précise (rue, immeuble, commerce) sur OpenStreetMap Nominatim, autour de Casablanca.
 * Sans réseau ou en cas d'erreur : liste vide (le catalogue suffit pour la démo).
 */
export async function chercherAdresse(texte: string, pres: Point = CASABLANCA): Promise<Lieu[]> {
  if (process.env.BAB_GEOCODAGE === 'non' || texte.trim().length < 3) return [];
  const params = new URLSearchParams({
    q: texte,
    format: 'jsonv2',
    limit: '5',
    countrycodes: 'ma',
    'accept-language': 'fr',
    viewbox: `${pres.lng - 0.3},${pres.lat + 0.3},${pres.lng + 0.3},${pres.lat - 0.3}`,
  });
  try {
    const res = await fetch(`https://nominatim.openstreetmap.org/search?${params}`, {
      headers: { 'User-Agent': 'BabTaxi/0.1 (agent WhatsApp)' },
      signal: AbortSignal.timeout(6000),
    });
    if (!res.ok) return [];
    const liste = (await res.json()) as { place_id: number; name?: string; display_name: string; lat: string; lon: string }[];
    return liste
      .map((r) => ({
        id: `A${r.place_id}`,
        nom: r.name || r.display_name.split(',')[0],
        ar: r.name || r.display_name.split(',')[0],
        quartier: r.display_name.split(',').slice(1, 3).map((s) => s.trim()).join(', '),
        type: 'adresse' as const,
        lat: Number(r.lat),
        lng: Number(r.lon),
      }))
      .sort((a, b) => haversine(a, pres) - haversine(b, pres));
  } catch {
    return [];
  }
}
