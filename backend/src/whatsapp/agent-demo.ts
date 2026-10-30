import { Commande, Conversation, Langue, Offre, prixOffres } from './commande';
import { chercherCatalogue, normaliser } from './lieux';

/**
 * Agent de démonstration, sans IA : un parcours guidé par mots-clés (français et darija), pour tester le circuit
 * WhatsApp avant d'avoir une clé Claude, et en secours si l'API ne répond pas.
 */

const OUI = ['oui', 'ouais', 'ui', 'wi', 'daccord', 'ok', 'okay', 'exact', 'exactement', 'cest ca', 'parfait', 'yes', 'iyeh', 'iyah', 'ah', 'wakha', 'waha', 'safi', 'naam', 'نعم', 'اه', 'ايه', 'واخا', 'صافي', 'هو هداك', 'مزيان'];
const NON = ['non', 'no', 'pas ca', 'la', 'lla', 'machi', 'لا', 'ماشي', 'لالا'];
const ANNULER = ['annule', 'annuler', 'cancel', 'bhal walo', 'lghi', 'nlghi', 'لغي', 'نلغي', 'الغي', 'إلغاء'];
const OU_EST = ['ou est', 'ou en est', 'il arrive', 'fin howa', 'fin wsal', 'فين', 'وصل', 'taxi'];
const MOTS_DARIJA = ['bghit', 'bghina', 'ghadi', 'mchi', 'nmchi', '3afak', 'afak', 'wach', 'fin', 'dyal', 'safi', 'wakha', 'iyeh', 'salam', 'labas', 'chhal', 'bzaf', 'daba', 'ana', 'nta', 'nti', 'hna', 'lhih', 'dghya'];
const MOTS_FRANCAIS = ['je', 'vais', 'suis', 'veux', 'voudrais', 'bonjour', 'bonsoir', 'merci', 'oui', 'non', 'au', 'aux', 'le', 'les', 'des', 'du', 'est', 'pour', 'avec', 'svp', 'stp'];

function contient(texte: string, mots: string[]): boolean {
  const t = ` ${normaliser(texte.replace(/'/g, ''))} `;
  return mots.some((m) => t.includes(` ${normaliser(m)} `));
}

export function detecterLangue(texte: string, precedente: Langue): Langue {
  if (/[؀-ۿ]/.test(texte)) return 'darija';
  if (contient(texte, MOTS_DARIJA)) return 'darija';
  if (contient(texte, MOTS_FRANCAIS)) return 'fr';
  // Un nom de lieu seul (« Gare Casa Voyageurs ») ne change pas la langue de la conversation.
  return precedente;
}

const oui = (t: string) => contient(t, OUI);
const non = (t: string) => contient(t, NON) && !oui(t);

function offreDite(t: string): Offre | undefined {
  if (contient(t, ['premium', 'confort', 'بريميوم', 'brimiom', 'premyom', '3'])) return 'premium';
  if (contient(t, ['seul', 'tout seul', 'wahdi', 'bouhdi', 'bohdi', 'وحدي', 'بوحدي', '2'])) return 'seul';
  if (contient(t, ['partage', 'partager', 'partagé', 'm3a nas', 'mea nas', 'معا الناس', 'مع الناس', 'مشترك', '1'])) return 'partage';
  return undefined;
}

/** « ل » + nom arabe : « للمعاريف », « لتوين سنتر ». */
const vers = (nom: string) => (nom.startsWith('ال') ? 'ل' + nom.slice(1) : 'ل' + nom);

type Phrases = Record<string, (...a: string[]) => string>;
const FR: Phrases = {
  bonjour: () => 'Bonjour, ici Bab Taxi. Où voulez-vous aller ?',
  positionRecue: () => 'Merci, votre position est bien reçue.',
  pasCompris: () => "Je n'ai pas trouvé ce lieu. Dites un quartier ou un lieu connu de Casablanca, par exemple Maârif ou Gare Casa Voyageurs.",
  repeter: (nom, quartier) => `Vous allez à ${nom}, ${quartier}. C'est bien ça ?`,
  autreDestination: () => "D'accord. Où voulez-vous aller ?",
  position: () => "Où êtes-vous ? Envoyez votre position WhatsApp avec le trombone, puis Position, ou dites le lieu où vous êtes.",
  prix: (p) => `Trois offres : ${p}. Laquelle voulez-vous ?`,
  prixGrand: (p) => `En grand taxi : ${p}. Vous confirmez ?`,
  offreInconnue: () => 'Dites partagé, seul ou premium.',
  resume: (dest, offre, prix) => `Je résume : ${offre} vers ${dest}, ${prix} dirhams, paiement en espèces. Je commande ?`,
  commande: (n) => (n === '0' ? "C'est commandé. Je cherche un taxi sur votre route, je vous préviens ici dès qu'un chauffeur accepte." : `C'est commandé. La demande est partie à ${n} taxi${n === '1' ? '' : 's'} sur votre route, je vous préviens dès qu'un chauffeur accepte.`),
  pasCommande: () => 'Pas de souci, rien n’est commandé. Où voulez-vous aller ?',
  annulee: () => 'Votre course est annulée.',
  rienAAnnuler: () => "Vous n'avez pas de course en cours.",
  attente: () => 'Je cherche toujours un taxi sur votre route. Dites « annuler » pour annuler.',
  taxi: (nom, plaque, dist) => `Votre taxi ${nom}, plaque ${plaque}, est à ${dist}.`,
  aBord: () => 'Vous êtes en route. Bon trajet !',
  erreur: (e) => e,
};
const DARIJA: Phrases = {
  bonjour: () => 'السلام، معاك باب طاكسي. فين بغيتي تمشي؟',
  positionRecue: () => 'شكرا، وصلاتني البلاصة ديالك.',
  pasCompris: () => 'ما لقيتش هاد البلاصة. قول ليا الحومة ولا بلاصة معروفة فكازا، بحال المعاريف ولا لاكار كازا فوياجور.',
  repeter: (nom) => `غادي ${vers(nom)}، ياك؟`,
  autreDestination: () => 'واخا. فين بغيتي تمشي؟',
  position: () => 'فين نتا دابا؟ صيفط لوكاليزاسيون ديالك فواتساب، ولا قول ليا البلاصة اللي نتا فيها.',
  prix: (p) => `عندك تلاتة ديال الاختيارات: ${p}. شنو بغيتي؟`,
  prixGrand: (p) => `فالطاكسي الكبير: ${p}. واخا؟`,
  offreInconnue: () => 'قول مشترك، بوحدك ولا بريميوم.',
  resume: (dest, offre, prix) => `${offre} ${vers(dest)}، ${prix} درهم، الخلاص كاش. نطلب ليك الطاكسي؟`,
  commande: (n) => (n === '0' ? 'طلبت ليك. كنقلب على طاكسي فطريقك، غادي نعلمك هنا ملي يقبل شي شيفور.' : `طلبت ليك. الطلب مشى ل${n} طاكسي فطريقك، غادي نعلمك ملي يقبل شي شيفور.`),
  pasCommande: () => 'ماشي مشكل، ما طلبت والو. فين بغيتي تمشي؟',
  annulee: () => 'تلغات الكورسة ديالك.',
  rienAAnnuler: () => 'ما عندك حتى كورسة دابا.',
  attente: () => 'باقي كنقلب على طاكسي فطريقك. قول "لغي" باش تلغي.',
  taxi: (nom, plaque, dist) => `الطاكسي ديالك ${nom}، النمرة \u2066${plaque}\u2069، بعيد عليك ب${dist}.`,
  aBord: () => 'راك فالطريق. طريق السلامة!',
  erreur: (e) => e,
};
const NOMS_OFFRES: Record<string, Record<string, string>> = {
  fr: { partage: 'partagé', seul: 'seul', premium: 'premium', grand_taxi: 'grand taxi' },
  darija: { partage: 'مشترك', seul: 'بوحدك', premium: 'بريميوم', grand_taxi: 'طاكسي كبير' },
};

export function phrases(langue: Langue): Phrases {
  return langue === 'darija' || langue === 'ar' ? DARIJA : FR;
}

export class AgentDemo {
  /** Le passager a envoyé sa position WhatsApp. */
  async positionRecue(cmd: Commande): Promise<string> {
    if (cmd.conv.etape === 'depart') return this.repondre(cmd, '');
    return phrases(cmd.conv.langue).positionRecue();
  }

  async repondre(cmd: Commande, texte: string): Promise<string> {
    const c = cmd.conv;
    const P = phrases(c.langue);
    const noms = NOMS_OFFRES[c.langue === 'darija' || c.langue === 'ar' ? 'darija' : 'fr'];
    const enCours = c.courseId && ['en_attente', 'acceptee', 'a_bord'].includes(c.dernierStatut ?? '');

    if (contient(texte, ANNULER)) {
      if (enCours) {
        cmd.annulerCourse();
        c.etape = 'destination';
        return P.annulee();
      }
      if (c.etape && c.etape !== 'destination') {
        c.etape = 'destination';
        return P.pasCommande();
      }
      return P.rienAAnnuler();
    }
    if (enCours) {
      const e = cmd.etatCourse();
      if (e.statut === 'a_bord') return P.aBord();
      if (e.taxi) return P.taxi(e.taxi.nom ?? 'Bab', e.taxi.plaque ?? '', e.taxi.distance_m !== undefined ? `${e.taxi.distance_m} m` : '…');
      return P.attente();
    }

    const annoncerPrix = () => {
      cmd.estimerPrix();
      c.etape = 'offre';
      const offres = prixOffres(c);
      const liste = offres.map((o) => `${noms[o.offre]} ${o.totalMad} ${c.langue === 'darija' ? 'درهم' : 'dirhams'}`).join(c.langue === 'darija' ? '، ' : ', ');
      if (offres[0]?.offre === 'grand_taxi') {
        c.offre = 'partage';
        c.etape = 'confirmer_commande';
        return P.prixGrand(liste);
      }
      return P.prix(liste);
    };

    switch (c.etape) {
      case 'confirmer_destination':
        if (oui(texte)) {
          if (!c.depart) {
            c.etape = 'depart';
            return P.position();
          }
          return annoncerPrix();
        }
        if (non(texte)) {
          c.etape = 'destination';
          c.destination = undefined;
          return P.autreDestination();
        }
        break;
      case 'depart': {
        if (c.depart) return annoncerPrix();
        const lieu = chercherCatalogue(texte)[0];
        if (lieu) {
          cmd.definirDepart(lieu.id);
          return annoncerPrix();
        }
        return P.position();
      }
      case 'offre': {
        const offre = offreDite(texte);
        if (!offre) return P.offreInconnue();
        c.offre = offre;
        c.etape = 'confirmer_commande';
        const prix = prixOffres(c).find((o) => o.offre === offre)!.totalMad;
        return P.resume(c.destination!.lieu[c.langue === 'darija' ? 'ar' : 'nom'], noms[offre], String(prix));
      }
      case 'confirmer_commande':
        if (oui(texte)) {
          const grand = prixOffres(c)[0]?.offre === 'grand_taxi';
          const r = cmd.commander(grand ? 'grand_taxi' : (c.offre ?? 'partage'));
          c.etape = 'suivi';
          return P.commande(String(r.taxis_prevenus));
        }
        if (non(texte)) {
          c.etape = 'destination';
          c.destination = undefined;
          return P.pasCommande();
        }
        return P.resume(c.destination!.lieu.nom, noms[c.offre ?? 'partage'], String(prixOffres(c).find((o) => o.offre === c.offre)?.totalMad ?? ''));
    }

    // Nouvelle destination.
    const lieu = chercherCatalogue(texte)[0] ?? (await cmd.chercherLieu(texte)).resultats[0];
    if (!lieu) return c.etape ? P.pasCompris() : ((c.etape = 'destination'), P.bonjour());
    cmd.choisirDestination(lieu.id);
    c.etape = 'confirmer_destination';
    const l = c.destination!.lieu;
    return P.repeter(c.langue === 'darija' ? l.ar : l.nom, l.quartier);
  }
}
