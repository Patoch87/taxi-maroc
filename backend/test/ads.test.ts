import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';

describe('Module Publicités de la console', () => {
  let app: INestApplication;
  const cle = { 'x-cle-admin': 'admin-test' };

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

  it('créer, diffuser, mettre en pause, dates, image, supprimer', async () => {
    const http = app.getHttpServer();
    await request(http).get('/admin/api/publicites').expect(403);

    // Les 6 pubs d'exemple deviennent modifiables.
    const depart = (await request(http).get('/admin/api/publicites').set(cle).expect(200)).body;
    expect(depart).toHaveLength(6);
    expect((await request(http).get('/ads').expect(200)).body).toHaveLength(6);

    // Création : champs obligatoires, lien en https, position pour un lieu.
    await request(http).post('/admin/api/publicites').set(cle).send({ emplacement: 'accueil', titre: 'x' }).expect(400);
    await request(http).post('/admin/api/publicites').set(cle).send({ emplacement: 'accueil', annonceur: 'A', titre: 'x', lien: 'http://a.ma' }).expect(400);
    await request(http).post('/admin/api/publicites').set(cle).send({ emplacement: 'lieu', annonceur: 'A', titre: 'x' }).expect(400);
    const pub = (
      await request(http)
        .post('/admin/api/publicites')
        .set(cle)
        .send({ emplacement: 'accueil', annonceur: 'Riad Atlas', titre: '-20 % ce week-end', texte: 'Sur réservation', lien: 'https://riad.example.ma', couleur: '#006233', priorite: 0 })
        .expect(201)
    ).body;
    expect(pub.exempleFictif).toBe(false);
    const accueil = (await request(http).get('/ads?emplacement=accueil').expect(200)).body;
    expect(accueil[0]).toMatchObject({ id: pub.id, annonceur: 'Riad Atlas', lien: 'https://riad.example.ma', exempleFictif: false });

    // Pause, puis période terminée : plus diffusée.
    await request(http).post(`/admin/api/publicites/${pub.id}`).set(cle).send({ actif: false }).expect(200);
    expect((await request(http).get('/ads?emplacement=accueil').expect(200)).body.some((p: { id: string }) => p.id === pub.id)).toBe(false);
    await request(http).post(`/admin/api/publicites/${pub.id}`).set(cle).send({ actif: true, debut: '2020-01-01', fin: '2020-01-31' }).expect(200);
    expect((await request(http).get('/ads').expect(200)).body.some((p: { id: string }) => p.id === pub.id)).toBe(false);
    await request(http).post(`/admin/api/publicites/${pub.id}`).set(cle).send({ debut: '2020-02-01', fin: '2020-01-01' }).expect(400);
    await request(http).post(`/admin/api/publicites/${pub.id}`).set(cle).send({ debut: '', fin: '' }).expect(200);
    expect((await request(http).get('/ads').expect(200)).body.some((p: { id: string }) => p.id === pub.id)).toBe(true);

    // Texte d'une pub d'exemple modifié : sa traduction automatique est retirée.
    const souk = (await request(http).post('/admin/api/publicites/SOUK').set(cle).send({ titre: '-30 % sur tout' }).expect(200)).body;
    expect(souk.titreCle).toBeUndefined();

    // Logo de l'annonceur.
    const png = Buffer.from('89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c4890000000d4944415478da63f8ffff3f0005fe02fea7d6a4c70000000049454e44ae426082', 'hex');
    await request(http).post(`/admin/api/publicites/${pub.id}/image`).set(cle).set('Content-Type', 'text/plain').send('abc').expect(400);
    const avecImage = (await request(http).post(`/admin/api/publicites/${pub.id}/image`).set(cle).set('Content-Type', 'image/png').send(png).expect(200)).body;
    expect(avecImage.imageId).toBeTruthy();
    const liste = (await request(http).get('/ads?emplacement=accueil').expect(200)).body;
    const image = liste.find((p: { id: string }) => p.id === pub.id).image as string;
    expect((await request(http).get(image).expect(200)).headers['content-type']).toBe('image/png');

    // Statistiques et suppression.
    await request(http).post(`/ads/${pub.id}/events`).send({ type: 'clic' }).expect(204);
    const vue = (await request(http).get('/admin/api/publicites').set(cle).expect(200)).body.find((p: { id: string }) => p.id === pub.id);
    expect(vue).toMatchObject({ clic: 1, bons: 0, bon: false, diffusee: true });
    await request(http).post(`/admin/api/publicites/${pub.id}/supprimer`).set(cle).expect(200);
    expect((await request(http).get('/admin/api/publicites').set(cle).expect(200)).body).toHaveLength(6);
    await request(http).post(`/ads/${pub.id}/events`).send({ type: 'vue' }).expect(404);
  });
});
