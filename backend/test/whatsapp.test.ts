import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { createHmac } from 'crypto';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { RidesService } from '../src/rides/rides.service';
import { AgentIA } from '../src/whatsapp/agent-ia';
import { Commande, Conversation } from '../src/whatsapp/commande';
import { chercherCatalogue } from '../src/whatsapp/lieux';
import { WhatsappService } from '../src/whatsapp/whatsapp.service';

process.env.BAB_GEOCODAGE = 'non';

describe('Agent WhatsApp', () => {
  let app: INestApplication;
  let service: WhatsappService;
  let rides: RidesService;
  const http = () => request(app.getHttpServer());

  beforeAll(async () => {
    const mod = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = mod.createNestApplication({ rawBody: true });
    await app.init();
    service = app.get(WhatsappService);
    rides = app.get(RidesService);
    service.utiliserAgentIA(undefined);
  });
  afterAll(() => app.close());
  afterEach(() => {
    delete process.env.WHATSAPP_APP_SECRET;
    delete process.env.WHATSAPP_VERIFY_TOKEN;
  });

  const dire = async (id: string, corps: object) =>
    (await http().post('/whatsapp/demo/message').send({ id, ...corps }).expect(201)).body.reponses[0]?.texte as string;

  it('reconnaît les lieux dits à voix haute, avec fautes et en arabe', () => {
    expect(chercherCatalogue('je vais au maaref')[0].nom).toBe('Maârif');
    expect(chercherCatalogue('bghit nmchi l sidi marouf')[0].nom).toBe('Sidi Maârouf');
    expect(chercherCatalogue('غادي للمطار عافاك')[0].nom).toBe('Aéroport Mohammed V');
  });

  it("vérifie l'adresse du webhook pour Meta", async () => {
    process.env.WHATSAPP_VERIFY_TOKEN = 'secret-bab';
    const ok = await http().get('/whatsapp/webhook?hub.mode=subscribe&hub.verify_token=secret-bab&hub.challenge=1234').expect(200);
    expect(ok.text).toBe('1234');
    await http().get('/whatsapp/webhook?hub.mode=subscribe&hub.verify_token=faux&hub.challenge=1234').expect(403);
  });

  it('refuse un webhook mal signé et traite une seule fois un message renvoyé par Meta', async () => {
    process.env.WHATSAPP_APP_SECRET = 'cle-app';
    const corps = JSON.stringify({
      entry: [{ changes: [{ value: {
        contacts: [{ wa_id: '212600000001', profile: { name: 'Salma' } }],
        messages: [{ id: 'wamid.1', from: '212600000001', type: 'text', text: { body: 'Je vais au Twin Center' } }],
      } }] }],
    });
    const signe = 'sha256=' + createHmac('sha256', 'cle-app').update(corps).digest('hex');
    await http().post('/whatsapp/webhook').set('content-type', 'application/json').set('x-hub-signature-256', 'sha256=00').send(corps).expect(403);
    await http().post('/whatsapp/webhook').set('content-type', 'application/json').set('x-hub-signature-256', signe).send(corps).expect(200);
    await http().post('/whatsapp/webhook').set('content-type', 'application/json').set('x-hub-signature-256', signe).send(corps).expect(200);
    await new Promise((r) => setTimeout(r, 50));
    const recus = service.relever('212600000001');
    expect(recus).toHaveLength(1);
    expect(recus[0].texte).toContain('Twin Center');
    expect(service.conversation('212600000001').nom).toBe('Salma');
  });

  it('commande une course de bout en bout en français, sans détail de prix', async () => {
    const id = 'test-fr';
    expect(await dire(id, { texte: 'Bonjour' })).toContain('Où voulez-vous aller');
    expect(await dire(id, { texte: 'Je vais au Maarif' })).toMatch(/Maârif.*C'est bien ça/);
    expect(await dire(id, { texte: 'oui' })).toContain('position');
    const prix = await dire(id, { position: { lat: 33.5897, lng: -7.5906 } });
    expect(prix).toMatch(/partagé \d+ dirhams, seul \d+ dirhams, premium \d+ dirhams/);
    expect(prix).not.toMatch(/compensation|frais|supplément|compteur/i);
    expect(await dire(id, { texte: 'Seul' })).toMatch(/seul vers Maârif, \d+ dirhams.*Je commande/);
    expect(await dire(id, { texte: "oui c'est ça" })).toContain("C'est commandé");

    const conv = service.conversation(`demo-${id}`);
    const course = rides.getRequest(conv.courseId!);
    expect(course.demande.mode).toBe('seul');
    expect(course.demande.destinationNom).toBe('Maârif');

    // Un chauffeur accepte, démarre puis termine : le passager est prévenu à chaque fois.
    await http().post('/whatsapp/demo/chauffeur').send({ id }).expect(201);
    await service.suivreCourses();
    expect((await http().get(`/whatsapp/demo/boite?id=${id}`)).body[0].texte).toMatch(/Hamid, plaque 12345-A-6, à \d+ mètres/);
    await http().post('/whatsapp/demo/chauffeur').send({ id }).expect(201);
    await service.suivreCourses();
    expect((await http().get(`/whatsapp/demo/boite?id=${id}`)).body[0].texte).toContain('démarré la course');
    await http().post('/whatsapp/demo/chauffeur').send({ id }).expect(201);
    await service.suivreCourses();
    expect((await http().get(`/whatsapp/demo/boite?id=${id}`)).body[0].texte).toContain('Vous êtes arrivé');
  });

  it('répond en darija à un passager qui parle darija', async () => {
    const id = 'test-darija';
    expect(await dire(id, { texte: 'Salam, bghit nmchi l Maarif 3afak' })).toBe('غادي للمعاريف، ياك؟');
    expect(await dire(id, { texte: 'iyeh' })).toContain('لوكاليزاسيون');
    expect(await dire(id, { texte: 'ana f Gare Casa Voyageurs' })).toContain('درهم');
  });

  it("refuse de commander avant que le passager ait confirmé la destination et entendu les prix", () => {
    const conv: Conversation = { id: 'x', langue: 'fr', tour: 1, vocal: false, passagers: 1, adresses: [], majLe: Date.now() };
    const cmd = new Commande(rides, conv);
    cmd.definirPositionGps({ lat: 33.5897, lng: -7.5906 });
    cmd.choisirDestination(chercherCatalogue('maarif')[0].id);
    expect(() => cmd.commander('partage')).toThrow(/pas encore confirmé/);
    conv.tour++;
    cmd.estimerPrix(1);
    expect(() => cmd.commander('partage')).toThrow(/prix/);
    conv.tour++;
    expect(cmd.commander('partage').course_id).toBeDefined();
  });

  it("l'agent IA appelle les outils et renvoie l'erreur au modèle quand il va trop vite", async () => {
    const appels: any[] = [];
    const reponses = [
      { stop_reason: 'tool_use', content: [{ type: 'tool_use', id: 't1', name: 'chercher_lieu', input: { texte: 'Morocco Mall' } }] },
      { stop_reason: 'tool_use', content: [{ type: 'tool_use', id: 't2', name: 'choisir_destination', input: { lieu_id: 'L4' } }, { type: 'tool_use', id: 't3', name: 'commander', input: { offre: 'seul', paiement: 'especes' } }] },
      { stop_reason: 'end_turn', content: [{ type: 'text', text: 'Vous allez au Morocco Mall, à Aïn Diab. C’est bien ça ?' }] },
    ];
    const faux = { beta: { messages: { create: async (p: any) => { appels.push(JSON.parse(JSON.stringify(p))); return reponses.shift(); } } } };
    service.utiliserAgentIA(new AgentIA(faux as any));
    try {
      const r = await dire('test-ia', { texte: 'Morocco Mall stp' });
      expect(r).toContain('Morocco Mall');
      expect(appels[0].model).toBe('claude-opus-5-5');
      const resultats = appels[2].messages.at(-1).content;
      expect(resultats[0].content).toContain('Morocco Mall');
      expect(resultats[1].is_error).toBe(true);
      expect(resultats[1].content).toMatch(/pas encore confirmé/);
      expect(appels[0].messages[0].content).toMatch(/message écrit/);
    } finally {
      service.utiliserAgentIA(undefined);
    }
  });
});
