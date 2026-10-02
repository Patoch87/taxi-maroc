export interface Point {
  lat: number;
  lng: number;
}

const EARTH_RADIUS_M = 6_371_000;
const toRad = (deg: number) => (deg * Math.PI) / 180;

/** Distance à vol d'oiseau entre deux points, en mètres. */
export function haversine(a: Point, b: Point): number {
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(a.lat)) * Math.cos(toRad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * EARTH_RADIUS_M * Math.asin(Math.sqrt(h));
}

/**
 * Projection d'un point sur le segment [a, b].
 * Retourne la distance au segment (mètres) et la position t (0 = a, 1 = b).
 * Approximation plane, suffisante à l'échelle d'une ville.
 */
export function projectOnSegment(p: Point, a: Point, b: Point): { distance: number; t: number } {
  const cosLat = Math.cos(toRad(a.lat));
  const ax = 0, ay = 0;
  const bx = (b.lng - a.lng) * cosLat, by = b.lat - a.lat;
  const px = (p.lng - a.lng) * cosLat, py = p.lat - a.lat;
  const len2 = bx * bx + by * by;
  let t = len2 === 0 ? 0 : ((px - ax) * bx + (py - ay) * by) / len2;
  t = Math.max(0, Math.min(1, t));
  const proj = { lat: a.lat + t * (b.lat - a.lat), lng: a.lng + t * (b.lng - a.lng) };
  return { distance: haversine(p, proj), t };
}

/** Longueur totale d'un itinéraire, en mètres. */
export function routeLength(route: Point[]): number {
  let total = 0;
  for (let i = 1; i < route.length; i++) total += haversine(route[i - 1], route[i]);
  return total;
}
