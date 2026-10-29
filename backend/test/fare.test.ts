import { estimateGrandTaxi, estimatePetitTaxi } from '../src/domain/fare';

const jour = new Date('2026-10-02T12:00:00');
const nuit = new Date('2026-10-02T23:00:00');

describe('estimatePetitTaxi', () => {
  it('applique le minimum de course', () => {
    expect(estimatePetitTaxi({ distanceM: 200, mode: 'partage', categorie: 'standard', date: jour }).montantMad).toBe(12);
  });

  it('calcule le compteur selon la distance', () => {
    // 2 + 4 km x 3,5 = 16
    expect(estimatePetitTaxi({ distanceM: 4000, mode: 'partage', categorie: 'standard', date: jour }).montantMad).toBe(16);
  });

  it('course seule : compteur + compensation chauffeur + 3 MAD de frais Bab', () => {
    // 1 passager : 2 places bloquées, compensation = compteur ; 16 + 16 + 3 = 35
    expect(estimatePetitTaxi({ distanceM: 4000, mode: 'seul', categorie: 'standard', date: jour }).montantMad).toBe(35);
    // 2 passagers : 50 % du compteur, au moins 10 MAD ; 16 + 10 + 3 = 29
    expect(estimatePetitTaxi({ distanceM: 4000, mode: 'seul', categorie: 'standard', date: jour, passagers: 2 }).montantMad).toBe(29);
    // 3 passagers : aucune compensation ; 16 + 3 = 19
    expect(estimatePetitTaxi({ distanceM: 4000, mode: 'seul', categorie: 'standard', date: jour, passagers: 3 }).montantMad).toBe(19);
  });

  it('premium : prix « Seul » + 10 MAD de supplément premium, toujours plus cher que seul', () => {
    // Compteur 20 (2 + 18 / 3,5 km), 1 passager : 20 + 20 + 3 + 10 = 53
    expect(estimatePetitTaxi({ distanceM: (18 / 3.5) * 1000, mode: 'seul', categorie: 'premium', date: jour }).montantMad).toBe(53);
    for (const passagers of [1, 2, 3]) {
      for (const distanceM of [200, 4000, 12000]) {
        const seul = estimatePetitTaxi({ distanceM, mode: 'seul', categorie: 'standard', date: jour, passagers }).montantMad;
        const premium = estimatePetitTaxi({ distanceM, mode: 'seul', categorie: 'premium', date: jour, passagers }).montantMad;
        expect(premium).toBe(seul + 10);
      }
    }
  });

  it('ajoute la majoration de nuit, la compensation, les frais et le supplément premium', () => {
    const e = estimatePetitTaxi({ distanceM: 4000, mode: 'seul', categorie: 'premium', date: nuit });
    // 16 x 1,5 = 24 ; + compensation 24 + frais 3 + supplément premium 10 = 61
    expect(e.montantMad).toBe(61);
    expect(e.details.map((d) => d.libelle)).toEqual([
      'Compteur estimé',
      'Majoration de nuit',
      'Compensation chauffeur',
      'Frais Bab',
      'Supplément premium',
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
