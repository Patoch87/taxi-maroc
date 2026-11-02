import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { PIECES } from '../src/drivers/drivers.service';

describe('Dossiers chauffeurs', () => {
  let app: INestApplication;
  const image = Buffer.alloc(5000, 7);
  const route = {
    type: 'petit',
    categorie: 'standard',
    passagersABord: 0,
    reserveSeul: false,
    itineraire: [{ lat: 33.57, lng: -7.63 }],
    nom: 'Faux nom',
  };

  beforeAll(async () => {
    process.env.BAB_ADMIN_TOKEN = 'admin-test';
    const mod = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = mod.createNestApplication();
    await app.init();
  });
  afterAll(async () => {
    delete process.env.BAB_ADMIN_TOKEN;
    await app.close();
  });

  it("inscription, validation par Bab Taxi, puis le taxi peut se mettre en ligne", async () => {
    const http = app.getHttpServer();
    await request(http).post('/accounts').send({ id: 'chauf-1', phone: '0661000001', firstName: 'Hamid', lastName: 'Mansouri' }).expect(201);

    // Sans dossier validé : pas de courses.
    await request(http).put('/taxis/chauf-1/route').send(route).expect(403);

    const pieces: Record<string, string> = {};
    for (const p of PIECES) {
      const r = await request(http).post(`/chauffeurs/chauf-1/pieces/${p}`).set('content-type', 'image/jpeg').send(image).expect(201);
      pieces[p] = r.body.id;
    }
    // Pièce d'un autre chauffeur refusée.
    await request(http)
      .post('/chauffeurs/chauf-1/dossier')
      .send({ cin: 'BE123456', permis: 'P1', cartePro: 'C1', taxiNumero: '2417', plaque: '12345-A-6', pieces: { ...pieces, casier: 'chauffeur-autre-casier-00' } })
      .expect(400);
    await request(http).put('/taxis/chauf-1/route').send(route).expect(403);

    const d = await request(http)
      .post('/chauffeurs/chauf-1/dossier')
      .send({ cin: 'be123456', permis: 'P1', cartePro: 'C1', taxiNumero: '2417', plaque: '12345-A-6', langues: ['ar', 'fr'], pieces })
      .expect(200);
    expect(d.body).toMatchObject({ statut: 'en_attente', prenom: 'Hamid' });
    expect(d.body.cin).toBeUndefined();
    expect((await request(http).get('/chauffeurs/chauf-1')).body.statut).toBe('en_attente');

    // Page des dossiers : clé obligatoire, documents lisibles avec la clé.
    await request(http).get('/admin/chauffeurs.json').expect(403);
    const liste = await request(http).get('/admin/chauffeurs.json?cle=admin-test').expect(200);
    expect(liste.body[0].cin).toBe('BE123456');
    await request(http).get(`/admin/fichiers/${pieces.casier}?cle=admin-test`).expect(200);
    await request(http).get(`/admin/fichiers/${pieces.casier}`).expect(403);
    await request(http).get('/chauffeurs/chauf-1/photo').expect(404);

    await request(http).post('/admin/chauffeurs/chauf-1/decision?cle=admin-test').send({ decision: 'refuse' }).expect(400);
    await request(http).post('/admin/chauffeurs/chauf-1/decision?cle=admin-test').send({ decision: 'valide' }).expect(200);

    await request(http).put('/taxis/chauf-1/route').send(route).expect(200);
    const proches = await request(http).get('/taxis/nearby?lat=33.57&lng=-7.63').expect(200);
    const taxi = proches.body.find((t: { id: string }) => t.id === 'chauf-1');
    // Le passager voit l'identité du dossier, pas le nom envoyé par le téléphone.
    expect(taxi).toMatchObject({ nom: 'Hamid M.', plaque: '12345-A-6', photo: '/chauffeurs/chauf-1/photo', langues: ['ar', 'fr'] });
    await request(http).get('/chauffeurs/chauf-1/photo').expect(200);
  });
});
