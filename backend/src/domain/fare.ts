import { CASABLANCA_PETIT_TAXI, CAPACITE, LIGNES_GRAND_TAXI, RideMode, TaxiCategory, isNight } from './tariffs';

export interface FareEstimate {
  montantMad: number;
  details: { libelle: string; montantMad: number }[];
}

const round = (n: number) => Math.round(n * 100) / 100;

/**
 * Estimation du prix d'une course en petit taxi, affichée avant la course.
 * - Partagé : compteur.
 * - Seul : compteur + compensation chauffeur (places bloquées × 50 % du compteur : 2 places pour
 *   1 passager, 1 pour 2, aucune pour 3 ; au moins 10 MAD quand elle n'est pas nulle) + 3 MAD de frais Bab.
 * - Premium : prix « Seul » (même nombre de passagers) + 10 MAD de supplément premium.
 */
export function estimatePetitTaxi(input: {
  distanceM: number;
  mode: RideMode;
  categorie: TaxiCategory;
  date: Date;
  /** Nombre de personnes du groupe (1 à 3), pour la compensation de la course seule. */
  passagers?: number;
}): FareEstimate {
  const t = CASABLANCA_PETIT_TAXI;
  const details: FareEstimate['details'] = [];

  let base = t.priseEnChargeMad + (input.distanceM / 1000) * t.parKmMad;
  base = Math.max(base, t.minimumMad);
  details.push({ libelle: 'Compteur estimé', montantMad: round(base) });

  let compteur = base;
  if (isNight(input.date)) {
    const m = base * t.majorationNuit;
    details.push({ libelle: 'Majoration de nuit', montantMad: round(m) });
    compteur += m;
  }
  compteur = round(compteur);
  let total = compteur;
  const premium = input.categorie === 'premium';
  if (input.mode === 'seul' || premium) {
    const passagers = Math.min(Math.max(Math.round(input.passagers ?? 1), 1), CAPACITE.petit);
    const bloquees = CAPACITE.petit - passagers;
    let compensation = bloquees * t.compensationParPlace * compteur;
    if (compensation > 0) compensation = Math.max(compensation, t.compensationMinMad);
    compensation = round(compensation);
    details.push({ libelle: 'Compensation chauffeur', montantMad: compensation });
    details.push({ libelle: 'Frais Bab', montantMad: t.fraisBabMad });
    total += compensation + t.fraisBabMad;
  }
  if (premium) {
    details.push({ libelle: 'Supplément premium', montantMad: t.supplementPremiumMad });
    total += t.supplementPremiumMad;
  }
  return { montantMad: round(total), details };
}

/** Prix d'une réservation en grand taxi (prix fixe par place). */
export function estimateGrandTaxi(input: { ligne: string; places: number; taxiEntier: boolean }): FareEstimate {
  const ligne = LIGNES_GRAND_TAXI[input.ligne];
  if (!ligne) throw new Error(`Ligne inconnue : ${input.ligne}`);
  const places = input.taxiEntier ? CAPACITE.grand : input.places;
  if (places < 1 || places > CAPACITE.grand) throw new Error('Nombre de places invalide');
  const montant = places * ligne.prixPlaceMad;
  return {
    montantMad: round(montant),
    details: [{ libelle: `${places} place(s) vers ${ligne.destination}`, montantMad: round(montant) }],
  };
}
