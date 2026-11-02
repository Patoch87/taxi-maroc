import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';

describe("Console d'administration", () => {
  let app: INestApplication;
  const cle = { 'x-cle-admin': 'admin-test' };

  beforeAll(async () => {
    process.env.BAB_ADMIN_TOKEN = 'admin-test';
    process.env.BAB_CHAUFFEUR_VALIDATION = 'non';
    const mod = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = mod.createNestApplication();
    await app.init();
  });
  afterAll(async () => {
    delete process.env.BAB_ADMIN_TOKEN;
    delete process.env.BAB_CHAUFFEUR_VALIDATION;
    await app.close();
  });

  it('page, clé obligatoire, chiffres, carte, passagers, courses, reporting, blocage', async () => {
    const http = app.getHttpServer();
    expect((await request(http).get('/admin').expect(200)).text).toContain('Console');
    await request(http).get('/admin/api/resume').expect(403);
    await request(http).get('/admin/api/resume').set('x-cle-admin', 'faux').expect(403);

    await request(http).post('/accounts').send({ id: 'pass-1', phone: '0661000002', firstName: 'Salma', lastName: 'B' }).expect(201);
    await request(http)
      .put('/taxis/taxi-1/route')
      .send({ type: 'petit', categorie: 'standard', passagersABord: 0, reserveSeul: false, itineraire: [{ lat: 33.57, lng: -7.63 }, { lat: 33.59, lng: -7.61 }] })
      .expect(200);
    const course = await request(http)
      .post('/rides/requests')
      .send({ depart: { lat: 33.571, lng: -7.629 }, destination: { lat: 33.589, lng: -7.611 }, passager: { nom: 'Salma B.', id: 'pass-1' }, source: 'app', destinationNom: 'Maârif', prixMad: 20 })
      .expect(201);
    const id = course.body.id;
    await request(http).post(`/rides/requests/${id}/accept`).send({ taxiId: 'taxi-1' }).expect(201);

    const tr = await request(http).get('/admin/api/temps-reel').set(cle).expect(200);
    expect(tr.body.taxis[0]).toMatchObject({ id: 'taxi-1', etat: 'vers_client' });

    await request(http).post(`/rides/requests/${id}/pickup`).send({ taxiId: 'taxi-1' }).expect(201);
    await request(http).post(`/rides/requests/${id}/dropoff`).send({ taxiId: 'taxi-1' }).expect(201);

    const r = await request(http).get('/admin/api/resume').set(cle).expect(200);
    expect(r.body.taxis.enLigne).toBe(1);
    expect(r.body.courses.termineesAujourdhui).toBe(1);
    expect(r.body.montants.aujourdhui).toBe(20);

    const p = await request(http).get('/admin/api/passagers').set(cle).expect(200);
    expect(p.body.find((x: { id: string }) => x.id === 'pass-1')).toMatchObject({ courses: 1, terminees: 1 });
    const c = await request(http).get('/admin/api/courses').set(cle).expect(200);
    expect(c.body[0]).toMatchObject({ statut: 'terminee', destination: 'Maârif', source: 'app' });
    expect(typeof c.body[0].delaiAcceptationMin).toBe('number');
    const csv = await request(http).get('/admin/api/courses.csv?cle=admin-test').expect(200);
    expect(csv.text).toContain('Maârif');
    const rep = await request(http).get('/admin/api/reporting?jours=7').set(cle).expect(200);
    expect(rep.body.parJour).toHaveLength(7);
    expect(rep.body.parJour.at(-1).terminees).toBe(1);
    expect(rep.body.topDestinations[0]).toEqual({ nom: 'Maârif', n: 1 });

    // Passager bloqué : plus de commande.
    await request(http).post('/admin/api/passagers/pass-1/blocage').set(cle).send({ bloque: true }).expect(400);
    await request(http).post('/admin/api/passagers/pass-1/blocage').set(cle).send({ bloque: true, motif: 'Fraude' }).expect(200);
    await request(http)
      .post('/rides/requests')
      .send({ depart: { lat: 33.571, lng: -7.629 }, destination: { lat: 33.589, lng: -7.611 }, passager: { nom: 'Salma', id: 'pass-1' } })
      .expect(403);
  });
});
