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
  /**
   * Course seule : le chauffeur est compensé pour les places qu'il ne pourra pas proposer
   * (50 % du compteur par place bloquée, au moins 10 MAD quand elle n'est pas nulle).
   */
  compensationParPlace: 0.5,
  compensationMinMad: 10,
  /** Frais Bab ajoutés à la course seule. */
  fraisBabMad: 3,
  /** Supplément premium, ajouté au prix « Seul » : 5 MAD pour le chauffeur, 5 MAD pour Bab. */
  supplementPremiumMad: 10,
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
