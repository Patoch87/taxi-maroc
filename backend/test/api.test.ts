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
