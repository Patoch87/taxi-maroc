import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { normaliserTelephone } from '../src/accounts/accounts.service';
import { AppModule } from '../src/app.module';

describe('Comptes et code SMS', () => {
  let app: INestApplication;
  const http = () => request(app.getHttpServer());

  beforeAll(async () => {
    const mod = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = mod.createNestApplication();
    await app.init();
  });
  afterAll(() => app.close());

  it('ramène les numéros marocains à la forme WhatsApp', () => {
    for (const n of ['+212 6 12 34 56 78', '0612345678', '00212612345678', '+212 0612345678', '212-612.345.678']) {
      expect(normaliserTelephone(n)).toBe('212612345678');
    }
    expect(normaliserTelephone('+33 6 12 34 56 78')).toBe('33612345678');
  });

  it('sans Twilio, envoie le code de test et marque le compte vérifié après le bon code', async () => {
    const code = await http().post('/auth/code').send({ phone: '+212 612345670' }).expect(200);
    expect(code.body).toEqual({ mode: 'test', longueur: 4, codeTest: '1234' });
    expect((await http().post('/auth/verify').send({ phone: '0612345670', code: '0000' }).expect(200)).body.ok).toBe(false);
    expect((await http().post('/auth/verify').send({ phone: '0612345670', code: '1234' }).expect(200)).body.ok).toBe(true);
    const compte = await http().post('/accounts').send({ id: 'UVERIF', phone: '+212 612345670', firstName: 'A', lastName: 'B' }).expect(201);
    expect(compte.body).toEqual({ id: 'UVERIF', verifie: true });
  });

  it('limite le nombre de codes demandés par numéro', async () => {
    for (let i = 0; i < 5; i++) await http().post('/auth/code').send({ phone: '0699999999' }).expect(200);
    await http().post('/auth/code').send({ phone: '0699999999' }).expect(429);
  });

  it('refuse un compte sans numéro valable et donne la configuration publique', async () => {
    await http().post('/accounts').send({ id: 'UX', phone: '12' }).expect(400);
    const c = await http().get('/config').expect(200);
    expect(c.body).toMatchObject({ sms: 'test', carte: false });
  });
});

// Avec une vraie base (TEST_DATABASE_URL=postgres://…), les comptes et les courses survivent au redémarrage.
const base = process.env.TEST_DATABASE_URL;
(base ? describe : describe.skip)('Base PostgreSQL', () => {
  const demarrer = async () => {
    process.env.DATABASE_URL = base;
    const mod = await Test.createTestingModule({ imports: [AppModule] }).compile();
    const app = mod.createNestApplication();
    await app.init();
    return app;
  };
  afterAll(() => delete process.env.DATABASE_URL);

  it('garde comptes, plaintes et compteurs de pub après un redémarrage', async () => {
    let app = await demarrer();
    await request(app.getHttpServer()).post('/accounts').send({ id: 'UPERSI', phone: '0677777777', firstName: 'Nadia', lastName: 'Z' }).expect(201);
    const plainte = (await request(app.getHttpServer()).post('/complaints').send({ motif: 'refus' }).expect(201)).body;
    const avant = (await request(app.getHttpServer()).get('/ads').expect(200)).body[0].id;
    const vues = (await request(app.getHttpServer()).get(`/ads/${avant}/stats`)).body.vue;
    await request(app.getHttpServer()).post(`/ads/${avant}/events`).send({ type: 'vue' }).expect(204);
    await app.close();

    app = await demarrer();
    const { AccountsService } = await import('../src/accounts/accounts.service');
    expect(app.get(AccountsService).parNumero('212677777777')?.prenom).toBe('Nadia');
    expect((await request(app.getHttpServer()).get(`/complaints/${plainte.id}`)).body.motif).toBe('refus');
    expect((await request(app.getHttpServer()).get(`/ads/${avant}/stats`)).body.vue).toBe(vues + 1);
    await app.close();
  });
});

describe('Connexion à la base', () => {
  it('chiffre seulement les adresses externes', async () => {
    const { sslPour } = await import('../src/store/store.service');
    expect(sslPour('postgresql://u:p@dpg-abc123-a/babtaxi')).toBeUndefined();
    expect(sslPour('postgres://postgres@localhost:5433/postgres')).toBeUndefined();
    expect(sslPour('postgresql://u:p@dpg-abc123-a.frankfurt-postgres.render.com/babtaxi')).toEqual({ rejectUnauthorized: false });
  });
});
