import { TaxiEnRoute, trouverTaxis } from '../src/domain/matching';

// Itinéraire en ligne droite d'environ 3,5 km dans Casablanca, du sud-ouest au nord-est.
const itineraire = [
  { lat: 33.57, lng: -7.63 },
  { lat: 33.58, lng: -7.62 },
  { lat: 33.59, lng: -7.61 },
];

const taxi = (over: Partial<TaxiEnRoute> = {}): TaxiEnRoute => ({
  id: 't1',
  type: 'petit',
  categorie: 'standard',
  itineraire,
  passagersABord: 0,
  reserveSeul: false,
  ...over,
});

const surLaRoute = { depart: { lat: 33.575, lng: -7.625 }, destination: { lat: 33.588, lng: -7.612 } };

describe('trouverTaxis', () => {
  it('propose un taxi dont la route passe par le passager et sa destination', () => {
    const r = trouverTaxis({ ...surLaRoute, mode: 'partage', passagers: 1 }, [taxi()]);
    expect(r).toHaveLength(1);
    expect(r[0].taxiId).toBe('t1');
    expect(r[0].ecartDepartM).toBeLessThan(50);
  });

  it('ignore un passager qui va dans la direction opposée', () => {
    const inverse = { depart: surLaRoute.destination, destination: surLaRoute.depart };
    expect(trouverTaxis({ ...inverse, mode: 'partage', passagers: 1 }, [taxi()])).toHaveLength(0);
  });

  it('ignore un passager trop loin de la route', () => {
    const loin = { depart: { lat: 33.575, lng: -7.6 }, destination: surLaRoute.destination };
    expect(trouverTaxis({ ...loin, mode: 'partage', passagers: 1 }, [taxi()])).toHaveLength(0);
  });

  it('respecte les places libres (3 en petit taxi)', () => {
    expect(trouverTaxis({ ...surLaRoute, mode: 'partage', passagers: 1 }, [taxi({ passagersABord: 3 })])).toHaveLength(0);
    expect(trouverTaxis({ ...surLaRoute, mode: 'partage', passagers: 1 }, [taxi({ passagersABord: 2 })])).toHaveLength(1);
  });

  it('course seule : seulement les taxis vides, et un taxi réservé seul refuse les autres', () => {
    expect(trouverTaxis({ ...surLaRoute, mode: 'seul', passagers: 1 }, [taxi({ passagersABord: 1 })])).toHaveLength(0);
    expect(trouverTaxis({ ...surLaRoute, mode: 'partage', passagers: 1 }, [taxi({ reserveSeul: true })])).toHaveLength(0);
  });

  it('filtre les taxis premium et trie par proximité', () => {
    const proche = taxi({ id: 'proche', itineraire: [{ lat: 33.574, lng: -7.626 }, ...itineraire.slice(1)] });
    const premium = taxi({ id: 'premium', categorie: 'premium' });
    const r = trouverTaxis({ ...surLaRoute, mode: 'partage', passagers: 1 }, [taxi(), proche, premium]);
    expect(r.map((c) => c.taxiId)).toEqual(['proche', 't1', 'premium']);
    const p = trouverTaxis({ ...surLaRoute, mode: 'partage', passagers: 1, categorie: 'premium' }, [taxi(), premium]);
    expect(p.map((c) => c.taxiId)).toEqual(['premium']);
  });
});
