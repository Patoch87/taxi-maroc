import { estimateGrandTaxi, estimatePetitTaxi } from '../src/domain/fare';

const jour = new Date('2026-10-02T12:00:00');
const nuit = new Date('2026-10-02T23:00:00');

describe('estimatePetitTaxi', () => {
  it('applique le minimum de course', () => {
    expect(estimatePetitTaxi({ distanceM: 200, mode: 'partage', categorie: 'standard', date: jour }).montantMad).toBe(7.5);
  });

  it('calcule le compteur selon la distance', () => {
    // 2 + 4 km x 3,5 = 16
    expect(estimatePetitTaxi({ distanceM: 4000, mode: 'partage', categorie: 'standard', date: jour }).montantMad).toBe(16);
  });

  it('ajoute la majoration de nuit, le supplément seul et le premium', () => {
    const e = estimatePetitTaxi({ distanceM: 4000, mode: 'seul', categorie: 'premium', date: nuit });
    // 16 x 1,5 = 24 ; x 1,3 = 31,2 ; x 1,5 = 46,8
    expect(e.montantMad).toBe(46.8);
    expect(e.details.map((d) => d.libelle)).toEqual([
      'Compteur estimé',
      'Majoration de nuit',
      'Supplément course seul',
      'Service premium',
    ]);
  });
});

describe('estimateGrandTaxi', () => {
  it('multiplie le prix par place', () => {
    expect(estimateGrandTaxi({ ligne: 'casa-mohammedia', places: 2, taxiEntier: false }).montantMad).toBe(24);
  });

  it('facture 6 places pour le taxi entier', () => {
    expect(estimateGrandTaxi({ ligne: 'casa-mohammedia', places: 1, taxiEntier: true }).montantMad).toBe(72);
  });

  it('refuse une ligne inconnue', () => {
    expect(() => estimateGrandTaxi({ ligne: 'x', places: 1, taxiEntier: false })).toThrow('Ligne inconnue');
  });
});
