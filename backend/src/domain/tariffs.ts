export type TaxiType = 'petit' | 'grand';
export type RideMode = 'seul' | 'partage';
export type TaxiCategory = 'standard' | 'premium';

/**
 * Tarifs du petit taxi à Casablanca.
 * ATTENTION : valeurs indicatives, à confirmer avec le tarif officiel de la wilaya
 * avant le lancement. Elles sont centralisées ici pour être modifiées facilement.
 */
export const CASABLANCA_PETIT_TAXI = {
  priseEnChargeMad: 2.0,
  parKmMad: 3.5,
  minimumMad: 7.5,
  /** Majoration de nuit (20h à 6h) : +50 %. */
  majorationNuit: 0.5,
  /** Supplément quand le passager veut le taxi pour lui seul. */
  supplementCourseSeul: 0.3,
  /** Coefficient appliqué aux taxis premium. */
  coefficientPremium: 1.5,
};

/** Capacité réglementaire en passagers. */
export const CAPACITE: Record<TaxiType, number> = { petit: 3, grand: 6 };

/** Lignes de grand taxi au départ de Casablanca. Prix par place, indicatifs. */
export const LIGNES_GRAND_TAXI: Record<string, { destination: string; prixPlaceMad: number }> = {
  'casa-mohammedia': { destination: 'Mohammedia', prixPlaceMad: 12 },
  'casa-berrechid': { destination: 'Berrechid', prixPlaceMad: 15 },
  'casa-eljadida': { destination: 'El Jadida', prixPlaceMad: 40 },
};

export function isNight(date: Date): boolean {
  const h = date.getHours();
  return h >= 20 || h < 6;
}
