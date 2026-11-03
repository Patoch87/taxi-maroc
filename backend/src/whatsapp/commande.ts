import { estimateGrandTaxi, estimatePetitTaxi } from '../domain/fare';
import { haversine, Point } from '../domain/geo';
import { LIGNES_GRAND_TAXI } from '../domain/tariffs';
import { RidesService, StatutCourse } from '../rides/rides.service';
import { chercherAdresse, chercherCatalogue, Lieu, trouverParId } from './lieux';

export type Offre = 'partage' | 'seul' | 'premium';
export type Langue = 'fr' | 'darija' | 'ar' | 'en' | 'autre';

/** Une conversation WhatsApp avec un passager (un numéro de téléphone). */
export interface Conversation {
  /** Numéro WhatsApp du passager (format international sans « + »). */
  id: string;
  nom?: string;
  langue: Langue;
  /** Numéro du message du passager : sert à vérifier qu'il a répondu après avoir entendu la destination et les prix. */
  tour: number;
  /** Le dernier message du passager était un vocal : on lui répond aussi en vocal. */
  vocal: boolean;
  derniereTranscription?: string;
  /** Langue du dernier vocal quand la transcription est fiable (sinon la langue de la conversation est gardée). */
  langueVocal?: string;
  depart?: { point: Point; nom?: string };
  destination?: { lieu: Lieu; tour: number };
  /** Tour où les prix ont été annoncés. */
  prixAuTour?: number;
  passagers: number;
  courseId?: string;
  dernierStatut?: StatutCourse;
  /** Adresses OpenStreetMap trouvées pendant la conversation (choix par identifiant). */
  adresses: Lieu[];
  /** Étape de l'agent de démonstration (sans IA). */
  etape?: string;
  offre?: Offre;
  majLe: number;
}

const FACTEUR_ROUTE = 1.3;
const arrondi = (n: number) => Math.round(n);

/**
 * Fourchette annoncée au passager : le prix réel est celui du compteur (−10 % à +15 %, dirhams entiers,
 * au moins 2 DH d'écart). Même calcul que l'application (priceRange).
 */
export function fourchette(totalMad: number): { min: number; max: number } {
  const min = Math.floor(totalMad * 0.9);
  let max = Math.ceil(totalMad * 1.15);
  if (max - min < 2) max = min + 2;
  return { min, max };
}

/** Texte « 26 à 34 » (petit taxi, au compteur) ou le prix fixe du grand taxi. */
export function prixParle(o: { offre: Offre | 'grand_taxi'; totalMad: number; fixe?: boolean }, darija: boolean): string {
  if (o.fixe) return String(o.totalMad);
  const f = fourchette(o.totalMad);
  return darija ? `بين ${f.min} و ${f.max}` : `entre ${f.min} et ${f.max}`;
}

/** Prix TOTAL de chaque offre. Le détail (compensation, frais, supplément) n'est jamais donné au passager. */
export function prixOffres(
  conv: Conversation,
  date = new Date(),
): { offre: Offre | 'grand_taxi'; totalMad: number; libelle: string; fixe?: boolean }[] {
  if (!conv.destination) return [];
  const dest = conv.destination.lieu;
  const passagers = conv.passagers;
  if (dest.ligne && LIGNES_GRAND_TAXI[dest.ligne]) {
    const places = estimateGrandTaxi({ ligne: dest.ligne, places: Math.min(passagers, 6), taxiEntier: false });
    const entier = estimateGrandTaxi({ ligne: dest.ligne, places: 6, taxiEntier: true });
    return [
      // Grand taxi entre deux villes : tarif fixe par place, pas de compteur.
      { offre: 'grand_taxi', totalMad: arrondi(places.montantMad), libelle: `Grand taxi, ${passagers} place(s)`, fixe: true },
      { offre: 'seul', totalMad: arrondi(entier.montantMad), libelle: 'Grand taxi entier', fixe: true },
    ];
  }
  const depart = conv.depart?.point ?? dest;
  const distanceM = Math.max(haversine(depart, dest), 1000) * FACTEUR_ROUTE;
  const prix = (mode: 'partage' | 'seul', categorie: 'standard' | 'premium') =>
    arrondi(estimatePetitTaxi({ distanceM, mode, categorie, date, passagers }).montantMad);
  return [
    { offre: 'partage', totalMad: prix('partage', 'standard'), libelle: 'Partagé' },
    { offre: 'seul', totalMad: prix('seul', 'standard'), libelle: 'Seul' },
    { offre: 'premium', totalMad: prix('seul', 'premium'), libelle: 'Premium' },
  ];
}

/** Vue publique d'un lieu pour l'agent. */
function vueLieu(l: Lieu) {
  return { id: l.id, nom: l.nom, nom_arabe: l.ar, quartier: l.quartier, type: l.type, hors_casablanca: !!l.ligne };
}

/**
 * Actions de commande partagées par l'agent IA et l'agent de démonstration. Les garde-fous sont ici, pas dans le
 * texte du prompt : impossible de commander sans départ, ni avant que le passager ait répondu après avoir entendu
 * la destination et les prix.
 */
export class Commande {
  constructor(
    private readonly rides: RidesService,
    readonly conv: Conversation,
  ) {}

  async chercherLieu(texte: string) {
    let trouves = chercherCatalogue(texte).slice(0, 4);
    if (trouves.length === 0) {
      trouves = (await chercherAdresse(texte, this.conv.depart?.point)).slice(0, 4);
      for (const a of trouves) if (!this.conv.adresses.some((x) => x.id === a.id)) this.conv.adresses.push(a);
    }
    return { resultats: trouves.map(vueLieu) };
  }

  private lieu(id: string): Lieu {
    const l = trouverParId(id, this.conv.adresses);
    if (!l) throw new Error(`Lieu inconnu : ${id}. Utilisez d'abord chercher_lieu.`);
    return l;
  }

  choisirDestination(lieuId: string) {
    const lieu = this.lieu(lieuId);
    this.conv.destination = { lieu, tour: this.conv.tour };
    this.conv.prixAuTour = undefined;
    return { destination: vueLieu(lieu), a_faire: 'Dans ce même tour, appelez estimer_prix, puis répétez la destination avec les fourchettes de prix et demandez quelle offre il veut.' };
  }

  definirDepart(lieuId: string) {
    const lieu = this.lieu(lieuId);
    this.conv.depart = { point: { lat: lieu.lat, lng: lieu.lng }, nom: lieu.nom };
    return { depart: vueLieu(lieu) };
  }

  definirPositionGps(point: Point, nom?: string) {
    this.conv.depart = { point, nom };
  }

  estimerPrix(passagers?: number) {
    if (!this.conv.destination) throw new Error("Pas encore de destination : demandez d'abord où va le passager.");
    if (passagers) this.conv.passagers = Math.min(Math.max(Math.round(passagers), 1), 6);
    if (this.conv.passagers > 3 && !this.conv.destination.lieu.ligne) this.conv.passagers = 3;
    this.conv.prixAuTour = this.conv.tour;
    return {
      passagers: this.conv.passagers,
      depart_connu: !!this.conv.depart,
      offres: prixOffres(this.conv).map((o) =>
        o.fixe
          ? { offre: o.offre, libelle: o.libelle, prix_fixe_mad: o.totalMad }
          : { offre: o.offre, libelle: o.libelle, fourchette_mad: fourchette(o.totalMad) },
      ),
      rappel:
        "Petit taxi : le prix final est celui du compteur, annoncez seulement la fourchette (« entre 26 et 34 dirhams »), jamais un prix exact ni son détail. Grand taxi : prix fixe.",
    };
  }

  commander(offre: Offre | 'grand_taxi', paiement: 'especes' | 'carte' = 'especes') {
    const c = this.conv;
    if (!c.destination) throw new Error('Pas de destination.');
    if (c.tour <= c.destination.tour) {
      throw new Error("Le passager n'a pas encore confirmé la destination : répétez-la et attendez sa réponse.");
    }
    if (c.prixAuTour === undefined || c.tour <= c.prixAuTour) {
      throw new Error("Annoncez d'abord les prix (estimer_prix) et attendez que le passager choisisse et confirme.");
    }
    if (!c.depart) {
      throw new Error("Point de départ inconnu : demandez au passager d'envoyer sa position WhatsApp ou de dire où il est.");
    }
    if (c.courseId) {
      const st = this.rides.getRequest(c.courseId).statut;
      if (st === 'en_attente' || st === 'acceptee' || st === 'a_bord') throw new Error('Une course est déjà en cours.');
    }
    const prix = prixOffres(c).find((o) => o.offre === offre) ?? prixOffres(c)[0];
    const dest = c.destination.lieu;
    const d = this.rides.createRequest({
      depart: c.depart.point,
      destination: { lat: dest.lat, lng: dest.lng },
      mode: offre === 'seul' || offre === 'premium' ? 'seul' : 'partage',
      passagers: c.passagers,
      categorie: offre === 'premium' ? 'premium' : undefined,
      passager: { nom: `${c.nom ?? 'Passager'} (WhatsApp)`, telephone: c.id.startsWith('demo-') ? undefined : c.id },
      source: 'whatsapp',
      destinationNom: dest.nom,
      prixMad: prix.totalMad,
    });
    c.courseId = d.id;
    c.offre = offre === 'grand_taxi' ? 'partage' : offre;
    c.dernierStatut = d.statut;
    return {
      course_id: d.id,
      statut: d.statut,
      taxis_prevenus: d.proposeeA.length,
      ...(prix.fixe ? { prix_fixe_mad: prix.totalMad } : { fourchette_mad: fourchette(prix.totalMad) }),
      paiement,
      a_faire: 'Dites en une phrase que la demande est envoyée aux taxis sur sa route et qu’il suit son taxi dans l’application Bab Taxi (bouton « Suivre mon taxi » ajouté sous votre message).',
    };
  }

  etatCourse() {
    if (!this.conv.courseId) return { course: null };
    const d = this.rides.getRequest(this.conv.courseId);
    const depart = this.conv.depart?.point;
    return {
      statut: d.statut,
      destination: d.demande.destinationNom,
      taxi: d.taxi
        ? {
            nom: d.taxi.nom,
            plaque: d.taxi.plaque,
            type: d.taxi.type,
            distance_m: depart ? Math.round(haversine(d.taxi.position, depart)) : undefined,
          }
        : null,
    };
  }

  annulerCourse() {
    if (!this.conv.courseId) return { annulee: false, raison: 'Aucune course en cours.' };
    const d = this.rides.cancel(this.conv.courseId);
    this.conv.dernierStatut = d.statut;
    return { annulee: d.statut === 'annulee', statut: d.statut };
  }
}

/** Distance approximative du taxi, à dire à voix haute. */
export function distanceParlee(m: number, langue: Langue): string {
  if (m < 1000) return langue === 'darija' || langue === 'ar' ? `${Math.max(50, Math.round(m / 50) * 50)} متر` : `${Math.max(50, Math.round(m / 50) * 50)} mètres`;
  const km = (Math.round(m / 100) / 10).toString().replace('.', ',');
  return langue === 'darija' || langue === 'ar' ? `${km} كيلومتر` : `${km} km`;
}
