import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { configureApp } from '../src/setup';

describe('SOS : vidéo en direct vers le centre de sécurité', () => {
  let app: INestApplication;

  beforeAll(async () => {
    process.env.SOS_CENTRE_TOKEN = 'secret-test';
    const mod = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = mod.createNestApplication();
    configureApp(app);
    await app.init();
  });
  afterAll(() => app.close());

  it('crée l’alerte, reçoit les séquences et la position, puis termine', async () => {
    const http = app.getHttpServer();
    const a = await request(http)
      .post('/sos')
      .send({ passagerId: 'UABCDE', taxiId: 'CASA-123', lat: 33.57, lng: -7.63 })
      .expect(201);
    expect(a.body.statut).toBe('en_direct');
    const id = a.body.id;

    const video = Buffer.from('fausse vidéo mp4');
    const seg = await request(http)
      .post(`/sos/${id}/segments`)
      .set('Content-Type', 'video/mp4')
      .set('x-segment', '0')
      .send(video)
      .expect(201);
    expect(seg.body.segments).toBe(1);

    await request(http).post(`/sos/${id}/position`).send({ lat: 33.58, lng: -7.62 }).expect(201);
    const fin = await request(http).post(`/sos/${id}/end`).expect(201);
    expect(fin.body.statut).toBe('terminee');
    expect(fin.body.derniere.lat).toBe(33.58);

    // Vidéos et liste réservées au centre de sécurité (clé).
    await request(http).get('/sos').expect(403);
    await request(http).get(`/sos/${id}/segments/0`).expect(403);
    await request(http).get('/sos/centre?cle=mauvaise').expect(403);
    const liste = await request(http).get('/sos?cle=secret-test').expect(200);
    expect(liste.body[0].videos[0].taille).toBe(video.length);
    const lu = await request(http).get(`/sos/${id}/segments/0?cle=secret-test`).expect(200);
    expect(Buffer.from(lu.body).toString()).toBe('fausse vidéo mp4');
    await request(http).get('/sos/centre?cle=secret-test').expect(200).expect('Content-Type', /html/);
  });

  it('refuse une séquence vide ou une alerte inconnue', async () => {
    const http = app.getHttpServer();
    await request(http).post('/sos/inconnue/end').expect(404);
    const a = await request(http).post('/sos').send({}).expect(201);
    await request(http).post(`/sos/${a.body.id}/segments`).set('Content-Type', 'video/mp4').send(Buffer.alloc(0)).expect(400);
  });
});
