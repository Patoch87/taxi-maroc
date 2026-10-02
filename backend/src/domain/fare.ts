import { CASABLANCA_PETIT_TAXI, CAPACITE, LIGNES_GRAND_TAXI, RideMode, TaxiCategory, isNight } from './tariffs';

export interface FareEstimate {
  montantMad: number;
  details: { libelle: string; montantMad: number }[];
}

const round = (n: number) => Math.round(n * 100) / 100;

/** Estimation du prix d'une course en petit taxi, affichée avant la course. */
export function estimatePetitTaxi(input: {
  distanceM: number;
  mode: RideMode;
  categorie: TaxiCategory;
  date: Date;
}): FareEstimate {
  const t = CASABLANCA_PETIT_TAXI;
  const details: FareEstimate['details'] = [];

  let base = t.priseEnChargeMad + (input.distanceM / 1000) * t.parKmMad;
  base = Math.max(base, t.minimumMad);
  details.push({ libelle: 'Compteur estimé', montantMad: round(base) });

  let total = base;
  if (isNight(input.date)) {
    const m = base * t.majorationNuit;
    details.push({ libelle: 'Majoration de nuit', montantMad: round(m) });
    total += m;
  }
  if (input.mode === 'seul') {
    const s = total * t.supplementCourseSeul;
    details.push({ libelle: 'Supplément course seul', montantMad: round(s) });
    total += s;
  }
  if (input.categorie === 'premium') {
    const p = total * (t.coefficientPremium - 1);
    details.push({ libelle: 'Service premium', montantMad: round(p) });
    total += p;
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
