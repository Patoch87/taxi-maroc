import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';

describe('API', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const mod = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = mod.createNestApplication();
    await app.init();
  });
  afterAll(() => app.close());

  it('le chauffeur publie sa route et le passager le trouve', async () => {
    await request(app.getHttpServer())
      .put('/taxis/CASA-123/route')
      .send({
        type: 'petit',
        categorie: 'standard',
        passagersABord: 0,
        reserveSeul: false,
        itineraire: [
          { lat: 33.57, lng: -7.63 },
          { lat: 33.59, lng: -7.61 },
        ],
      })
      .expect(200);

    const res = await request(app.getHttpServer())
      .post('/rides/match')
      .send({ depart: { lat: 33.575, lng: -7.625 }, destination: { lat: 33.588, lng: -7.612 } })
      .expect(201);
    expect(res.body[0].taxiId).toBe('CASA-123');
  });

  it('estime un prix et enregistre une plainte', async () => {
    const prix = await request(app.getHttpServer())
      .post('/fares/petit-taxi')
      .send({ depart: { lat: 33.57, lng: -7.63 }, destination: { lat: 33.59, lng: -7.61 }, date: '2026-10-02T12:00:00' })
      .expect(201);
    expect(prix.body.montantMad).toBeGreaterThan(7.5);

    const plainte = await request(app.getHttpServer())
      .post('/complaints')
      .send({ taxiId: 'CASA-123', motif: 'prix_abusif', message: 'Le chauffeur a demandé 50 DH' })
      .expect(201);
    expect(plainte.body.statut).toBe('recue');

    await request(app.getHttpServer()).post('/complaints').send({ motif: 'n_importe_quoi' }).expect(400);
  });
});

describe('Premier chauffeur qui accepte', () => {
  let app: INestApplication;
  const route = (id: string) => ({
    type: 'petit',
    categorie: 'standard',
    passagersABord: 0,
    reserveSeul: false,
    itineraire: [
      { lat: 33.57, lng: -7.63 },
      { lat: 33.59, lng: -7.61 },
    ],
  });

  beforeAll(async () => {
    const mod = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = mod.createNestApplication();
    await app.init();
  });
  afterAll(() => app.close());

  it('bloque les autres chauffeurs dès que le premier accepte', async () => {
    const http = app.getHttpServer();
    for (const id of ['A', 'B', 'C']) await request(http).put(`/taxis/${id}/route`).send(route(id)).expect(200);

    const demande = await request(http)
      .post('/rides/requests')
      .send({ depart: { lat: 33.575, lng: -7.625 }, destination: { lat: 33.588, lng: -7.612 } })
      .expect(201);
    expect(demande.body.proposeeA.map((c: { taxiId: string }) => c.taxiId).sort()).toEqual(['A', 'B', 'C']);
    expect((await request(http).get('/taxis/B/offers').expect(200)).body).toHaveLength(1);

    const ok = await request(http).post(`/rides/requests/${demande.body.id}/accept`).send({ taxiId: 'B' }).expect(201);
    expect(ok.body.accepteePar).toBe('B');

    const refus = await request(http).post(`/rides/requests/${demande.body.id}/accept`).send({ taxiId: 'A' }).expect(409);
    expect(refus.body.message).toBe('Course déjà prise par un autre chauffeur');
    expect((await request(http).get('/taxis/C/offers').expect(200)).body).toHaveLength(0);

    await request(http).post(`/rides/requests/${demande.body.id}/accept`).send({ taxiId: 'Z' }).expect(409);
  });
});

describe('Test réel : un chauffeur, deux passagers', () => {
  let app: INestApplication;
  const casa = { lat: 33.5731, lng: -7.5898 };

  beforeAll(async () => {
    const mod = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = mod.createNestApplication();
    await app.init();
  });
  afterAll(() => app.close());

  it('taxi sans destination : demande proche, acceptée, prise en charge, déposée', async () => {
    const http = app.getHttpServer();
    // Chauffeur en ligne sans destination : un seul point (sa position).
    await request(http)
      .put('/taxis/T1/route')
      .send({ type: 'petit', categorie: 'standard', passagersABord: 0, reserveSeul: false, itineraire: [casa], nom: 'Youssef', plaque: '12345-A-6' })
      .expect(200);
    const autour = await request(http).get('/taxis/nearby').query({ lat: 33.574, lng: -7.59 }).expect(200);
    expect(autour.body.map((t: { id: string }) => t.id)).toEqual(['T1']);

    const d = await request(http)
      .post('/rides/requests')
      .send({ depart: { lat: 33.575, lng: -7.59 }, destination: { lat: 33.59, lng: -7.62 }, passager: { nom: 'Amina' }, destinationNom: 'Maârif' })
      .expect(201);
    const offres = (await request(http).get('/taxis/T1/offers').expect(200)).body;
    expect(offres.map((o: { id: string }) => o.id)).toEqual([d.body.id]);
    expect(offres[0].demande.passager.nom).toBe('Amina');

    await request(http).post(`/rides/requests/${d.body.id}/accept`).send({ taxiId: 'T1' }).expect(201);
    const vu = (await request(http).get(`/rides/requests/${d.body.id}`).expect(200)).body;
    expect(vu.statut).toBe('acceptee');
    expect(vu.taxi).toMatchObject({ id: 'T1', nom: 'Youssef', plaque: '12345-A-6', position: casa });

    expect((await request(http).get('/taxis/T1/rides').expect(200)).body).toHaveLength(1);
    await request(http).post(`/rides/requests/${d.body.id}/pickup`).send({ taxiId: 'T2' }).expect(409);
    await request(http).post(`/rides/requests/${d.body.id}/pickup`).send({ taxiId: 'T1' }).expect(201);
    expect((await request(http).get(`/rides/requests/${d.body.id}`)).body.statut).toBe('a_bord');
    await request(http).post(`/rides/requests/${d.body.id}/dropoff`).send({ taxiId: 'T1' }).expect(201);
    expect((await request(http).get(`/rides/requests/${d.body.id}`)).body.statut).toBe('terminee');
    expect((await request(http).get('/taxis/T1/rides').expect(200)).body).toHaveLength(0);
  });

  it('un refus retire la demande ; un taxi trop loin ne la reçoit pas', async () => {
    const http = app.getHttpServer();
    const base = { type: 'petit', categorie: 'standard', passagersABord: 0, reserveSeul: false };
    await request(http).put('/taxis/T3/route').send({ ...base, itineraire: [casa] }).expect(200);
    await request(http).put('/taxis/LOIN/route').send({ ...base, itineraire: [{ lat: 34.02, lng: -6.84 }] }).expect(200);
    const d = await request(http)
      .post('/rides/requests')
      .send({ depart: { lat: 33.575, lng: -7.59 }, destination: { lat: 33.59, lng: -7.62 } })
      .expect(201);
    expect((await request(http).get('/taxis/LOIN/offers')).body).toHaveLength(0);
    expect((await request(http).get('/taxis/T3/offers')).body.map((o: { id: string }) => o.id)).toContain(d.body.id);
    await request(http).post(`/rides/requests/${d.body.id}/decline`).send({ taxiId: 'T3' }).expect(201);
    expect((await request(http).get('/taxis/T3/offers')).body.map((o: { id: string }) => o.id)).not.toContain(d.body.id);
  });
});
