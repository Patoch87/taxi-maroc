// Vidéos de la console de commande Bab Taxi (/admin), sur le serveur de démonstration (console/serveur-demo.js).
// Usage : node console.js <adresse du serveur> <dossier de sortie> [visite|publicites]
// Écrit <sortie>/<scénario>/frames + marks.json pour compose_fonction.py --format bureau.
const { chromium } = require('playwright');
const path = require('path');
const { demarrer, pointeur } = require('./enregistreur');

const [base, out, ...seuls] = process.argv.slice(2);
const CLE = process.env.BAB_ADMIN_TOKEN || 'demo';
const VIEW = { width: 1600, height: 820 };
const DPR = 1.25;

const SCENARIOS = {
  // Visite de la console : du tableau de bord aux plaintes.
  async visite(p, r) {
    r.caption('Une console web, protégée par une clé d’accès');
    await p.locator('#cle').click();
    await p.keyboard.type(CLE, { delay: 90 });
    await p.waitForTimeout(500);
    await p.clickDoux('button[type=submit]');
    await p.waitForSelector('main h2:has-text("Tableau de bord")');
    await p.waitForTimeout(1500);
    r.caption('Tableau de bord : taxis en ligne, courses du jour, chauffeurs à vérifier');
    await p.waitForTimeout(4500);
    await p.defiler(420);
    r.caption('Délais d’acceptation, durée des courses, commandes WhatsApp : tout est mesuré');
    await p.waitForTimeout(4000);

    await p.module('temps-reel');
    r.caption('Temps réel : chaque taxi Bab Taxi suivi en direct sur la carte');
    await p.waitForTimeout(6500);
    r.caption('Vert : libre. Or : en route vers un client. Rouge : en course');
    await p.waitForTimeout(5000);

    await p.module('chauffeurs');
    r.caption('Chauffeurs : tous les dossiers, avec leurs courses et leurs plaintes');
    await p.waitForTimeout(3500);
    await p.clickDoux('.filtres button[data-f="en_attente"]');
    await p.waitForTimeout(1200);
    await p.clickDoux('#tCh tr[data-id] >> nth=0');
    await p.waitForSelector('#tiroir.ouvert');
    await p.waitForTimeout(800);
    r.caption('Chaque dossier est vérifié : CIN, permis, carte pro, casier judiciaire, photo du taxi');
    await p.defilerDans('#tiroir', 380);
    await p.waitForTimeout(4500);
    p.once('dialog', (d) => d.accept());
    r.caption('Validé : le chauffeur peut recevoir des courses');
    await p.clickDoux('#tiroir [data-d="valide"]');
    await p.waitForTimeout(3000);
    if (await p.locator('#tiroir.ouvert').count()) await p.clickDoux('#fermer').catch(() => {});

    await p.module('passagers');
    r.caption('Passagers : comptes vérifiés par SMS, historique des courses');
    await p.waitForTimeout(3000);
    await p.clickDoux('#tPa tr[data-id] >> nth=2');
    await p.waitForTimeout(3500);
    r.caption('En cas d’abus, un passager peut être bloqué');
    await p.waitForTimeout(3000);
    await p.clickDoux('#fermer').catch(() => {});

    await p.module('courses');
    r.caption('Courses : application ou WhatsApp, statut, chauffeur, prix annoncé');
    await p.waitForTimeout(4000);
    await p.clickDoux('.filtres button[data-f="en_cours"]');
    await p.waitForTimeout(1500);
    r.caption('Incident en ville ? Toutes les courses en cours s’annulent d’un clic');
    await p.waitForTimeout(2500);
    p.once('dialog', (d) => d.accept());
    await p.clickDoux('#annulerTout');
    await p.waitForTimeout(3500);

    await p.module('reporting');
    r.caption('Reporting : données agrégées et anonymes (loi 09-08)');
    await p.waitForTimeout(3500);
    await p.clickDoux('.filtres button[data-j="90"]');
    await p.waitForTimeout(1500);
    r.caption('Courses par jour, heures de pointe, quartiers : prêt à imprimer en PDF');
    await p.defiler(500);
    await p.waitForTimeout(4500);

    await p.module('plaintes');
    r.caption('Plaintes et alertes SOS : traitées et suivies jusqu’à la réponse');
    await p.waitForTimeout(5000);
  },

  // Module Publicités : créer une publicité, la voir dans la liste, la mettre en pause.
  async publicites(p, r) {
    await p.connexion();
    await p.module('publicites');
    r.caption('Publicités : chaque annonce de l’application se gère ici');
    await p.waitForTimeout(4000);
    r.caption('Vues, clics et bons utilisés, pour chaque annonceur');
    await p.waitForTimeout(3500);
    await p.clickDoux('#nouvellePub');
    await p.waitForSelector('#formPub');
    await p.waitForTimeout(600);
    r.caption('Nouvelle publicité : emplacement, annonceur, offre');
    await p.locator('#formPub select[name=emplacement]').selectOption({ index: 1 });
    await p.waitForTimeout(700);
    await p.taper('#formPub input[name=annonceur]', 'Café Atlas (exemple fictif)');
    await p.taper('#formPub input[name=titre]', '-15 % sur le petit-déjeuner');
    await p.taper('#formPub input[name=texte]', 'Sur présentation du bon Bab Taxi, avant 11 h');
    await p.taper('#formPub input[name=adresse]', 'Bd d’Anfa, Casablanca');
    await p.clickDoux('#formPub input[name=bon]');
    await p.locator('#formPub input[name=exempleFictif]').check();
    r.caption('Dates de diffusion, bon de réduction avec QR code, aperçu en direct');
    await p.defilerDans('#tiroir', 500);
    await p.waitForTimeout(3500);
    await p.clickDoux('#formPub button[type=submit]');
    await p.waitForTimeout(2500);
    r.caption('Enregistrée : elle arrive dans l’application des passagers');
    await p.waitForTimeout(4000);
    if (await p.locator('#tiroir.ouvert').count()) await p.clickDoux('#fermer').catch(() => {});
    await p.waitForTimeout(800);
    await p.clickDoux('tr[data-id] >> nth=0');
    await p.waitForSelector('#formPub');
    r.caption('Une pause, une modification ? Un clic, sans mise à jour de l’application');
    await p.waitForTimeout(1200);
    await p.clickDoux('#formPub input[name=actif]');
    await p.waitForTimeout(1500);
    await p.clickDoux('#formPub button[type=submit]');
    await p.waitForTimeout(3500);
  },
};

const TITRES = {
  visite: ['La console de commande', 'Chauffeurs, passagers, courses et taxis en direct', 'Tout Bab Taxi, en un coup d’œil'],
  publicites: ['Gérer les publicités', 'Créer, programmer, mettre en pause', 'Des revenus pour Bab Taxi et ses chauffeurs'],
};

(async () => {
  const browser = await chromium.launch();
  const liste = seuls.length ? seuls : Object.keys(SCENARIOS);
  let echecs = 0;
  for (const nom of liste) {
    const dossier = path.join(out, nom);
    const context = await browser.newContext({ viewport: VIEW, deviceScaleFactor: DPR, locale: 'fr-FR' });
    await context.addInitScript(pointeur(true));
    const p = await context.newPage();
    // Aides : mouvements de souris visibles, défilement, navigation entre modules.
    let souris = { x: VIEW.width / 2, y: VIEW.height / 2 };
    p.allerA = async (x, y) => {
      await p.mouse.move(x, y, { steps: 18 });
      souris = { x, y };
    };
    p.clickDoux = async (sel) => {
      const el = p.locator(sel).first();
      await el.scrollIntoViewIfNeeded({ timeout: 10000 });
      const b = await el.boundingBox({ timeout: 10000 });
      await p.allerA(b.x + b.width / 2, b.y + b.height / 2);
      await p.waitForTimeout(150);
      await p.mouse.down();
      await p.waitForTimeout(80);
      await p.mouse.up();
    };
    p.taper = async (sel, texte) => {
      await p.clickDoux(sel);
      await p.keyboard.type(texte, { delay: 45 });
      await p.waitForTimeout(250);
    };
    p.defiler = async (dy) => {
      await p.allerA(VIEW.width * 0.6, VIEW.height * 0.6);
      for (let i = 0; i < 8; i++) {
        await p.mouse.wheel(0, dy / 8);
        await p.waitForTimeout(60);
      }
    };
    p.defilerDans = async (sel, dy) => {
      const b = await p.locator(sel).boundingBox();
      await p.allerA(b.x + b.width / 2, b.y + b.height / 2);
      for (let i = 0; i < 8; i++) {
        await p.mouse.wheel(0, dy / 8);
        await p.waitForTimeout(60);
      }
    };
    p.module = async (id) => {
      await p.clickDoux(`nav a[data-m="${id}"]`);
      await p.waitForTimeout(1600);
    };
    p.connexion = async () => {
      await p.locator('#cle').fill(CLE);
      await p.locator('button[type=submit]').click();
      await p.waitForSelector('main h2:has-text("Tableau de bord")');
      await p.waitForTimeout(1200);
    };
    await p.goto(`${base}/admin`);
    await p.waitForTimeout(1500);
    const r = await demarrer(context, p, dossier, { view: VIEW, dpr: DPR, curseur: true });
    try {
      await SCENARIOS[nom](p, r);
      r.caption(null);
      await p.waitForTimeout(800);
      const [titre, sousTitre, fin] = TITRES[nom];
      await r.fin({ titre, sousTitre, fin });
      console.log(`console ${nom} : ${r.marks.duration.toFixed(1)} s, ${r.marks.frames.length} images`);
    } catch (e) {
      echecs++;
      console.log(`::error title=Console ${nom}::${String(e.message || e).split('\n')[0]}`);
      await p.screenshot({ path: path.join(out, `echec-${nom}.png`) }).catch(() => {});
      await r.fin().catch(() => {});
    }
    await context.close();
  }
  await browser.close();
  process.exit(echecs ? 1 : 0);
})();
