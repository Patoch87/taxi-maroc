/**
 * Catalogue des publicités de l'application. Annonceurs FICTIFS uniquement (exemples de démo),
 * toujours affichés avec la mention « exemple fictif ».
 *
 * Règles : publicités contextuelles (trajet, lieu, heure), jamais selon le revenu ou la catégorie
 * sociale ; jamais sur l'écran du chauffeur en conduite. Les textes sont traduits dans l'application
 * (clés titreCle / texteCle) ; titre et texte sont donnés ici en français.
 */
export type Emplacement = 'accueil' | 'attente' | 'course' | 'lieu' | 'destination' | 'recu';

export const EMPLACEMENTS: Emplacement[] = ['accueil', 'attente', 'course', 'lieu', 'destination', 'recu'];

export interface Publicite {
  id: string;
  emplacement: Emplacement;
  annonceur: string;
  titre: string;
  texte: string;
  titreCle: string;
  texteCle: string;
  /** Bon de réduction avec QR code (sinon simple lien vers l'offre). */
  bon: boolean;
  adresse?: string;
  position?: { lat: number; lng: number };
  exempleFictif: true;
}

export const PUBLICITES: Publicite[] = [
  {
    id: 'SOUK',
    emplacement: 'accueil',
    annonceur: 'Souk Mode',
    titre: '-15 % sur la nouvelle collection',
    texte: 'En boutique, sur présentation du bon',
    titreCle: 'adSoukTitle',
    texteCle: 'adSoukText',
    bon: true,
    adresse: 'Souk Mode, boulevard d’Anfa (exemple fictif)',
    exempleFictif: true,
  },
  {
    id: 'TELE',
    emplacement: 'attente',
    annonceur: 'Télé-Maroc Démo',
    titre: '20 Go d’internet pour 49 DH',
    texte: 'Offre 5G sans engagement, 30 jours',
    titreCle: 'adTeleTitle',
    texteCle: 'adTeleText',
    bon: false,
    exempleFictif: true,
  },
  {
    id: 'DARBANK',
    emplacement: 'course',
    annonceur: 'Dar Bank',
    titre: 'Ouvrez un compte en 10 minutes',
    texte: 'Carte bancaire offerte la 1re année',
    titreCle: 'adBankTitle',
    texteCle: 'adBankText',
    bon: true,
    adresse: 'Agences Dar Bank (exemple fictif)',
    exempleFictif: true,
  },
  {
    id: 'ATLAS',
    emplacement: 'lieu',
    annonceur: 'Café Atlas',
    titre: 'Café Atlas',
    texte: 'Café et pâtisseries',
    titreCle: 'adAtlasPlace',
    texteCle: 'adAtlasPlace',
    bon: false,
    adresse: 'Rue Tahar Sebti (exemple fictif)',
    position: { lat: 33.5905, lng: -7.619 },
    exempleFictif: true,
  },
  {
    id: 'AMAL',
    emplacement: 'destination',
    annonceur: 'Pharmacie Al Amal',
    titre: 'Pharmacie Al Amal',
    texte: 'Pharmacie de garde, ouverte 24 h/24',
    titreCle: 'adAmalText',
    texteCle: 'adAmalText',
    bon: false,
    adresse: 'Maârif (exemple fictif)',
    position: { lat: 33.585, lng: -7.625 },
    exempleFictif: true,
  },
  {
    id: 'ATLASBON',
    emplacement: 'recu',
    annonceur: 'Café Atlas',
    titre: 'Un café offert pour un café acheté',
    texte: 'Valable dans tous les Café Atlas',
    titreCle: 'adAtlasCouponTitle',
    texteCle: 'adAtlasCouponText',
    bon: true,
    adresse: 'Cafés Atlas de Casablanca (exemple fictif)',
    exempleFictif: true,
  },
];
