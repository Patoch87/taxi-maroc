import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';

process.env.BAB_CHAUFFEUR_VALIDATION = 'non';

const route = (lat: number, lng: number) => ({
  type: 'petit',
  categorie: 'standard',
  passagersABord: 0,
  reserveSeul: false,
  position: { lat, lng },
  itineraire: [
    { lat, lng },
    { lat: lat + 0.02, lng: lng + 0.02 },
  ],
});

describe('Panne ou accident : appel aux taxis proches', () => {
  let app: INestApplication;
  const http = () => request(app.getHttpServer());

  beforeAll(async () => {
    const mod = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = mod.createNestApplication();
    await app.init();
  });
  afterAll(() => app.close());

  it('prévient les chauffeurs proches, un seul reprend les passagers, le passager voit le nouveau taxi', async () => {
    await http().put('/taxis/PANNE-1/route').send({ ...route(33.57, -7.63), nom: 'Hamid' }).expect(200);
    await http().put('/taxis/AIDE-1/route').send({ ...route(33.575, -7.625), nom: 'Youssef' }).expect(200);
    await http().put('/taxis/AIDE-2/route').send({ ...route(33.572, -7.628), nom: 'Karim' }).expect(200);
    await http().put('/taxis/LOIN/route').send(route(34.02, -6.83)).expect(200); // Rabat

    // Une course en cours sur le taxi qui tombe en panne.
    const course = await http()
      .post('/rides/requests')
      .send({ depart: { lat: 33.575, lng: -7.625 }, destination: { lat: 33.588, lng: -7.612 }, destinationNom: 'Maarif', passagers: 2 })
      .expect(201);
    await http().post(`/rides/requests/${course.body.id}/accept`).send({ taxiId: 'PANNE-1' }).expect(201);
    await http().post(`/rides/requests/${course.body.id}/pickup`).send({ taxiId: 'PANNE-1' }).expect(201);

    const panne = { lat: 33.578, lng: -7.622 };
    const alerte = await http().post('/assistance').send({ taxiId: 'PANNE-1', motif: 'panne', position: panne }).expect(201);
    expect(alerte.body).toMatchObject({ motif: 'panne', nom: 'Hamid', passagers: 2, destinations: ['Maarif'], prevenus: 2, statut: 'ouverte' });

    // Un deuxième appui garde le même appel.
    const bis = await http().post('/assistance').send({ taxiId: 'PANNE-1', motif: 'panne', position: panne }).expect(201);
    expect(bis.body.id).toBe(alerte.body.id);

    // Les collègues proches le voient, pas celui de Rabat ni le chauffeur en panne.
    const proches = await http().get('/assistance/proches?taxiId=AIDE-1&lat=33.575&lng=-7.625').expect(200);
    expect(proches.body).toHaveLength(1);
    expect(proches.body[0].distanceM).toBeLessThan(1000);
    expect((await http().get('/assistance/proches?taxiId=LOIN&lat=34.02&lng=-6.83')).body).toHaveLength(0);
    expect((await http().get('/assistance/proches?taxiId=PANNE-1&lat=33.57&lng=-7.63')).body).toHaveLength(0);

    await http().post(`/assistance/${alerte.body.id}/reponse`).send({ taxiId: 'AIDE-2', action: 'arrive' }).expect(201);
    const reprise = await http().post(`/assistance/${alerte.body.id}/reponse`).send({ taxiId: 'AIDE-1', action: 'reprend' }).expect(201);
    expect(reprise.body.courses).toHaveLength(1);
    expect(reprise.body.courses[0].demande.depart).toEqual(panne);
    // Le deuxième qui veut reprendre arrive trop tard.
    await http().post(`/assistance/${alerte.body.id}/reponse`).send({ taxiId: 'AIDE-2', action: 'reprend' }).expect(409);

    // Le passager voit le nouveau taxi : course acceptée de nouveau, relais indiqué.
    const vue = await http().get(`/rides/requests/${course.body.id}`).expect(200);
    expect(vue.body).toMatchObject({ statut: 'acceptee', accepteePar: 'AIDE-1', relais: { deTaxi: 'PANNE-1', motif: 'panne', etaitABord: true } });
    expect(vue.body.taxi.nom).toBe('Youssef');
    // Le nouveau chauffeur démarre la course et la termine ; l'ancien ne peut plus y toucher.
    await http().post(`/rides/requests/${course.body.id}/dropoff`).send({ taxiId: 'PANNE-1' }).expect(409);
    await http().post(`/rides/requests/${course.body.id}/pickup`).send({ taxiId: 'AIDE-1' }).expect(201);

    const suivi = await http().get(`/assistance/${alerte.body.id}`).expect(200);
    expect(suivi.body.reponses.map((r: { nom: string; action: string }) => `${r.nom}:${r.action}`).sort()).toEqual(['Karim:arrive', 'Youssef:reprend']);

    // Seul le chauffeur qui a appelé peut fermer l'appel.
    await http().post(`/assistance/${alerte.body.id}/fin`).send({ taxiId: 'AIDE-1' }).expect(403);
    await http().post(`/assistance/${alerte.body.id}/fin`).send({ taxiId: 'PANNE-1' }).expect(201);
    expect((await http().get('/assistance/proches?taxiId=AIDE-1&lat=33.575&lng=-7.625')).body).toHaveLength(0);
    await http().post(`/assistance/${alerte.body.id}/reponse`).send({ taxiId: 'AIDE-2', action: 'arrive' }).expect(409);
  });

  it('refuse un appel sans motif ou sans position', async () => {
    await http().post('/assistance').send({ taxiId: 'X1', motif: 'crevaison', position: { lat: 33.5, lng: -7.6 } }).expect(400);
    await http().post('/assistance').send({ taxiId: 'X1', motif: 'accident' }).expect(400);
  });
});
