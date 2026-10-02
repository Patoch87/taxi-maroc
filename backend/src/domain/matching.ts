import { Point, haversine, projectOnSegment } from './geo';
import { CAPACITE, RideMode, TaxiCategory, TaxiType } from './tariffs';

export interface TaxiEnRoute {
  id: string;
  type: TaxiType;
  categorie: TaxiCategory;
  /** Itinéraire restant du taxi : position actuelle en premier, destination en dernier. */
  itineraire: Point[];
  passagersABord: number;
  /** Un passager « seul » a réservé le taxi entier. */
  reserveSeul: boolean;
}

export interface DemandePassager {
  depart: Point;
  destination: Point;
  mode: RideMode;
  passagers: number;
  categorie?: TaxiCategory;
}

export interface Correspondance {
  taxiId: string;
  /** Distance entre le passager et l'itinéraire du taxi (m). */
  ecartDepartM: number;
  /** Distance entre la destination du passager et l'itinéraire du taxi (m). */
  ecartDestinationM: number;
  /** Distance que le taxi parcourt avant d'arriver au passager (m). */
  distanceAvantPriseEnChargeM: number;
}

/** Distance maximale entre le passager et la route du taxi pour qu'il s'arrête. */
export const ECART_MAX_DEPART_M = 300;
/** Distance maximale entre la destination du passager et la route du taxi. */
export const ECART_MAX_DESTINATION_M = 800;

/** Position la plus proche d'un point sur l'itinéraire, exprimée en (segment + t). */
function locate(route: Point[], p: Point): { distance: number; position: number } {
  let best = { distance: Infinity, position: 0 };
  for (let i = 1; i < route.length; i++) {
    const { distance, t } = projectOnSegment(p, route[i - 1], route[i]);
    if (distance < best.distance) best = { distance, position: i - 1 + t };
  }
  return best;
}

/** Distance parcourue sur l'itinéraire jusqu'à une position (segment + t). */
function distanceAlong(route: Point[], position: number): number {
  let total = 0;
  const full = Math.floor(position);
  for (let i = 1; i <= full && i < route.length; i++) total += haversine(route[i - 1], route[i]);
  const frac = position - full;
  if (frac > 0 && full + 1 < route.length) total += frac * haversine(route[full], route[full + 1]);
  return total;
}

function placesLibres(taxi: TaxiEnRoute): number {
  if (taxi.reserveSeul) return 0;
  return CAPACITE[taxi.type] - taxi.passagersABord;
}

/**
 * Trouve les taxis qui passent près du passager ET vont vers sa destination finale.
 * Le passager doit se trouver devant le taxi sur sa route, et sa destination après lui :
 * le taxi ne fait pas demi-tour et ne s'arrête que pour des passagers qui vont dans sa direction.
 */
export function trouverTaxis(demande: DemandePassager, taxis: TaxiEnRoute[]): Correspondance[] {
  const resultats: Correspondance[] = [];
  for (const taxi of taxis) {
    if (taxi.itineraire.length < 2) continue;
    if (demande.categorie && taxi.categorie !== demande.categorie) continue;

    const libres = placesLibres(taxi);
    if (demande.mode === 'seul') {
      if (taxi.passagersABord > 0 || taxi.reserveSeul) continue;
    } else if (libres < demande.passagers) {
      continue;
    }

    const dep = locate(taxi.itineraire, demande.depart);
    const dest = locate(taxi.itineraire, demande.destination);
    if (dep.distance > ECART_MAX_DEPART_M) continue;
    if (dest.distance > ECART_MAX_DESTINATION_M) continue;
    if (dest.position <= dep.position) continue; // destination derrière le passager : mauvaise direction

    resultats.push({
      taxiId: taxi.id,
      ecartDepartM: Math.round(dep.distance),
      ecartDestinationM: Math.round(dest.distance),
      distanceAvantPriseEnChargeM: Math.round(distanceAlong(taxi.itineraire, dep.position)),
    });
  }
  return resultats.sort((a, b) => a.distanceAvantPriseEnChargeM - b.distanceAvantPriseEnChargeM);
}
