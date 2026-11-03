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

  const webhook = async (de: string, texte: string, msgId: string) => {
    process.env.WHATSAPP_APP_SECRET = 'cle-app';
    const corps = JSON.stringify({
      entry: [{ changes: [{ value: { messages: [{ id: msgId, from: de, type: 'text', text: { body: texte } }] } }] }],
    });
    const signe = 'sha256=' + createHmac('sha256', 'cle-app').update(corps).digest('hex');
    await http().post('/whatsapp/webhook').set('content-type', 'application/json').set('x-hub-signature-256', signe).send(corps).expect(200);
    await new Promise((r) => setTimeout(r, 50));
    return service.relever(de);
  };

  it("répond avec le lien de l'application à un numéro sans compte, puis commande une fois le compte créé", async () => {
    const avant = await webhook('212611223344', 'Je vais au Maârif', 'wamid.sans-compte');
    expect(avant[0].texte).toContain('installez');
    expect(avant[0].texte).toContain('taxi-maroc.apk');
    // Compte créé dans l'application avec le numéro écrit à la marocaine.
    await http().post('/accounts').send({ id: 'UABCDE', phone: '06 11 22 33 44', firstName: 'Karim', lastName: 'B' }).expect(201);
    const apres = await webhook('212611223344', 'Je vais au Maârif', 'wamid.avec-compte');
    expect(apres[0].texte).not.toContain('installez');
    expect(apres[0].texte).toContain('Maârif');
    expect(service.conversation('212611223344').nom).toBe('Karim');
  });

  it('refuse un webhook mal signé et traite une seule fois un message renvoyé par Meta', async () => {
    await http().post('/accounts').send({ id: 'USALMA', phone: '+212 600000001', firstName: 'Salma', lastName: 'K' }).expect(201);
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
    expect(prix).toMatch(/partagé entre \d+ et \d+ dirhams, seul entre \d+ et \d+ dirhams, premium entre \d+ et \d+ dirhams/);
    expect(prix).not.toMatch(/compensation|frais|supplément|compteur/i);
    expect(await dire(id, { texte: 'Seul' })).toMatch(/seul vers Maârif, entre \d+ et \d+ dirhams.*Je commande/);
    expect(await dire(id, { texte: "oui c'est ça" })).toContain("C'est commandé");

    const conv = service.conversation(`demo-${id}`);
    const course = rides.getRequest(conv.courseId!);
    expect(course.demande.mode).toBe('seul');
    expect(course.demande.destinationNom).toBe('Maârif');

    // Un chauffeur accepte : seul message de suivi (plaque, sécurité) avec le bouton vers l'application.
    // Ensuite WhatsApp se tait : le suivi se fait dans l'application (publicités).
    await http().post('/whatsapp/demo/chauffeur').send({ id }).expect(201);
    await service.suivreCourses();
    const accepte = (await http().get(`/whatsapp/demo/boite?id=${id}`)).body;
    expect(accepte[0].texte).toMatch(/Hamid, plaque 12345-A-6, à \d+ mètres/);
    expect(accepte[0].lien.url).toContain(`/ouvrir?c=${conv.courseId}`);
    await http().post('/whatsapp/demo/chauffeur').send({ id }).expect(201);
    await service.suivreCourses();
    expect((await http().get(`/whatsapp/demo/boite?id=${id}`)).body).toEqual([]);
    await http().post('/whatsapp/demo/chauffeur').send({ id }).expect(201);
    await service.suivreCourses();
    expect((await http().get(`/whatsapp/demo/boite?id=${id}`)).body).toEqual([]);
  });

  it('parcours court : bouton de position, boutons Partagé/Seul/Premium, course lancée, bouton vers l’application', async () => {
    const id = 'test-boutons';
    const envoyer = async (corps: object) =>
      (await http().post('/whatsapp/demo/message').send({ id, ...corps }).expect(201)).body.reponses[0];
    await envoyer({ texte: 'Bonjour' });
    await envoyer({ texte: 'Je vais au Maarif' });
    const pos = await envoyer({ texte: 'oui' });
    expect(pos.demandePosition).toBe(true);
    const prix = await envoyer({ position: { lat: 33.5897, lng: -7.5906 } });
    expect(prix.boutons.map((b: { titre: string }) => b.titre)).toEqual(['Partagé', 'Seul', 'Premium']);
    expect(prix.boutons[0].id).toBe('offre:partage');
    const lance = await envoyer({ texte: 'Partagé', bouton: 'offre:partage' });
    expect(lance.texte).toMatch(/C'est parti : partagé vers Maârif, entre \d+ et \d+ dirhams/);
    expect(lance.lien.libelle).toBe('Suivre mon taxi');
    const conv = service.conversation(`demo-${id}`);
    expect(lance.lien.url).toBe(`https://bab-taxi-eu.onrender.com/ouvrir?c=${conv.courseId}`);
    expect(rides.getRequest(conv.courseId!).demande.mode).toBe('partage');
    // Page /ouvrir : ouvre l'application (Android) ou le téléchargement.
    const page = await http().get(`/ouvrir?c=${conv.courseId}`).expect(200);
    expect(page.text).toContain('intent://');
    expect(page.text).toContain('ma.taxi.taxi_maroc');
  });

  it('darija : le bouton « Envoyer ma position » est proposé comme en français', async () => {
    const r = (await http().post('/whatsapp/demo/message').send({ id: 'test-pos-dr', texte: 'بغيت نمشي للمعاريف' }).expect(201)).body.reponses[0];
    expect(r.demandePosition).toBe(true);
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

  it('chemin rapide : destination claire et position -> prix et boutons tout de suite, sans appeler l’IA', async () => {
    const appels: unknown[] = [];
    const faux = { beta: { messages: { create: async (p: unknown) => { appels.push(p); return { stop_reason: 'end_turn', content: [{ type: 'text', text: 'IA' }] }; } } } };
    service.utiliserAgentIA(new AgentIA(faux as any));
    try {
      const envoyer = async (id: string, corps: object) =>
        (await http().post('/whatsapp/demo/message').send({ id, ...corps }).expect(201)).body.reponses[0];
      const debut = Date.now();
      const r = await envoyer('rapide-fr', { texte: 'Je vais au Maarif' });
      expect(Date.now() - debut).toBeLessThan(1000);
      expect(r.texte).toMatch(/^Maârif\. Partagé entre \d+ et \d+ dirhams, seul entre \d+ et \d+ dirhams, premium entre \d+ et \d+ dirhams\. Lequel voulez-vous \? Touchez « Envoyer ma position »/);
      expect(r.demandePosition).toBe(true);
      const p = await envoyer('rapide-fr', { position: { lat: 33.5897, lng: -7.5906 } });
      expect(p.texte).toMatch(/^Position reçue\. Maârif\./);
      expect(p.boutons).toHaveLength(3);
      const dr = await envoyer('rapide-dr', { texte: 'بغيت نمشي للمعاريف' });
      expect(dr.texte).toMatch(/مشارك بين \d+ و \d+ درهم/);
      expect(dr.demandePosition).toBe(true);
      expect(appels).toHaveLength(0);
      // Phrase sans lieu clair : l'agent IA répond.
      await envoyer('rapide-fr2', { texte: 'Bonjour, je voudrais un taxi' });
      expect(appels).toHaveLength(1);
    } finally {
      service.utiliserAgentIA(undefined);
    }
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
      process.env.BAB_WHATSAPP_RAPIDE = 'non';
      const r = await dire('test-ia', { texte: 'Morocco Mall stp' });
      delete process.env.BAB_WHATSAPP_RAPIDE;
      expect(r).toContain('Morocco Mall');
      expect(appels[0].model).toBe('claude-sonnet-5-5');
      const resultats = appels[2].messages.at(-1).content;
      expect(resultats[0].content).toContain('Morocco Mall');
      expect(resultats[1].is_error).toBe(true);
      expect(resultats[1].content).toMatch(/pas encore confirmé/);
      expect(JSON.stringify(appels[0].messages[0].content)).toMatch(/message écrit/);
    } finally {
      service.utiliserAgentIA(undefined);
    }
  });
});

describe('Agent WhatsApp : rapidité et voix', () => {
  it('cache sur le dernier message sans modifier l’historique', () => {
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const { avecCache } = require('../src/whatsapp/agent-ia');
    const h = [{ role: 'user', content: 'bonjour' }, { role: 'assistant', content: [{ type: 'text', text: 'Où allez-vous ?' }] }];
    const c = avecCache(h);
    expect(c[1].content[0].cache_control).toEqual({ type: 'ephemeral' });
    expect((h[1].content as { cache_control?: unknown }[])[0].cache_control).toBeUndefined();
    expect(c[0]).toBe(h[0]);
  });

  it('mêmes voix que les films : Nicolas (français), Hamid (darija)', () => {
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const v = require('../src/whatsapp/voix');
    expect(v.VOIX_FRANCAIS_FILMS).toBe('aQROLel5sQbj1vuIVi6B');
    expect(v.VOIX_DARIJA_FILMS).toBe('A9ATTqUUQ6GHu0coCz8t');
  });
});
