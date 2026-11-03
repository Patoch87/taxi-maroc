// Vidéo « Commander sur WhatsApp » : conversation avec le vrai agent Bab Taxi (serveur, /whatsapp/demo/...),
// affichée dans un écran WhatsApp (whatsapp/whatsapp.html), puis « Suivre mon taxi » ouvre l'application.
// Usage : node whatsapp.js <serveur> <application web> <dossier de sortie> [vocal de la passagère .mp3]
// Sans vocal (ou si le serveur ne sait pas l'écouter) : la passagère écrit son message.
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const { demarrer, pointeur } = require('./enregistreur');

const [serveur, appli, out, vocalPassagere] = process.argv.slice(2);
const VIEW = { width: 412, height: 820 };
// Densité 2 (824 x 1640) : l'écran est affiché sur 736 points de large au montage, et les captures sont plus rapides.
const DPR = 2;
const ID = 'film-' + Date.now().toString(36);
const PHRASE = "Bonjour, je voudrais aller au Twin Center, s'il vous plaît.";
const duree = (f) => Number(execFileSync('ffprobe', ['-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', f]).toString().trim());

async function api(chemin, corps, type = 'application/json') {
  const r = await fetch(serveur + chemin, {
    method: corps === undefined ? 'GET' : 'POST',
    headers: { 'content-type': type },
    body: corps === undefined ? undefined : type === 'application/json' ? JSON.stringify(corps) : corps,
  });
  if (!r.ok) throw new Error(`${chemin} : ${r.status} ${await r.text()}`);
  return r.json();
}

(async () => {
  fs.mkdirSync(path.join(out, 'sons'), { recursive: true });
  const browser = await chromium.launch();
  const context = await browser.newContext({ viewport: VIEW, deviceScaleFactor: DPR, locale: 'fr-FR' });
  await context.addInitScript(pointeur(false));
  const page = await context.newPage();
  await page.goto('file://' + path.resolve(__dirname, 'whatsapp/whatsapp.html'));
  await page.waitForTimeout(600);
  const r = await demarrer(context, page, out, { view: VIEW, dpr: DPR });
  const sons = [];
  const wait = (ms) => page.waitForTimeout(ms);
  const toucher = async (sel) => {
    const b = await page.locator(sel).last().boundingBox();
    await page.mouse.move(b.x + b.width / 2, b.y + b.height / 2);
    await page.mouse.down();
    await wait(120);
    await page.mouse.up();
  };
  // Un vocal joué : son placé dans la vidéo à cet instant, barre de lecture animée.
  const jouer = async (id, fichier, d) => {
    await toucher(`#${id} .pl`);
    sons.push({ t: r.now(), file: path.relative(out, fichier) });
    await page.evaluate(([i, du]) => window.wa.lire(i, du), [id, d]);
    await wait(d * 1000 + 500);
  };
  let nSon = 0;
  // Réponses de l'agent : vocal (voix des films) puis texte avec ses boutons.
  const repondre = async (reponses) => {
    await page.evaluate(() => window.wa.ecrit(true));
    await wait(1400);
    for (const rep of reponses) {
      if (rep.audio) {
        const [entete, b64] = rep.audio.split(',');
        const ext = entete.includes('ogg') ? 'ogg' : entete.includes('wav') ? 'wav' : 'mp3';
        const f = path.join(out, 'sons', `agent${nSon++}.${ext}`);
        fs.writeFileSync(f, Buffer.from(b64, 'base64'));
        const d = duree(f);
        await page.evaluate(() => window.wa.ecrit(false));
        const id = await page.evaluate((du) => window.wa.vocal(false, du), d);
        await wait(700);
        await jouer(id, f, d);
      }
      await page.evaluate(() => window.wa.ecrit(false));
      await page.evaluate((x) => window.wa.texte(false, x.texte, x), rep);
      await wait(900);
    }
  };
  const ecrire = async (texte) => {
    await toucher('.saisie');
    for (const c of texte) {
      await page.evaluate((t) => window.wa.saisir(t), texte.slice(0, texte.indexOf(c) + 1));
      await wait(70);
    }
    await page.evaluate(() => window.wa.envoiVisible(true));
    await wait(400);
    await toucher('#micro');
    await page.evaluate((t) => { window.wa.saisir(''); window.wa.envoiVisible(false); return window.wa.texte(true, t); }, texte);
  };

  try {
    // 1. Le vocal de la passagère.
    r.caption('Commander un taxi sur WhatsApp : un simple message vocal');
    await wait(1800);
    let reponses;
    if (vocalPassagere && fs.existsSync(vocalPassagere)) {
      const d = duree(vocalPassagere);
      const f = path.join(out, 'sons', 'passagere.mp3');
      fs.copyFileSync(vocalPassagere, f);
      const b = await page.locator('#micro').boundingBox();
      await page.mouse.move(b.x + b.width / 2, b.y + b.height / 2);
      await page.mouse.down();
      await page.evaluate(() => window.wa.enregistre(true));
      sons.push({ t: r.now() + 0.2, file: path.relative(out, f) });
      const t0 = Date.now();
      while (Date.now() - t0 < d * 1000 + 400) {
        await page.evaluate((s) => window.wa.chrono(s), (Date.now() - t0) / 1000);
        await wait(200);
      }
      await page.mouse.up();
      await page.evaluate(() => window.wa.enregistre(false));
      let transcription = PHRASE;
      try {
        const res = await api(`/whatsapp/demo/vocal?id=${ID}&nom=Salma`, fs.readFileSync(vocalPassagere), 'audio/mpeg');
        transcription = res.transcription || PHRASE;
        reponses = res.reponses;
      } catch (e) {
        console.log('vocal non compris par le serveur, message écrit à la place :', e.message);
      }
      await page.evaluate(([du, tr]) => window.wa.vocal(true, du, tr), [d, transcription]);
      if (!reponses) reponses = (await api('/whatsapp/demo/message', { id: ID, nom: 'Salma', texte: PHRASE })).reponses;
    } else {
      await ecrire(PHRASE);
      reponses = (await api('/whatsapp/demo/message', { id: ID, nom: 'Salma', texte: PHRASE })).reponses;
    }
    await wait(600);
    r.caption('L’agent Bab Taxi répond aussitôt, à la voix, et répète la destination');
    await repondre(reponses);
    await wait(1500);

    // 2. Confirmation.
    r.caption('Elle confirme d’un mot');
    await ecrire('Oui');
    reponses = (await api('/whatsapp/demo/message', { id: ID, texte: 'Oui' })).reponses;
    await repondre(reponses);
    await wait(1200);

    // 3. Position en un bouton.
    r.caption('Sa position : un bouton, pas d’adresse à taper');
    await wait(1200);
    await toucher('[data-bt="position"]');
    await wait(500);
    await page.evaluate(() => window.wa.position('Gare Casa Voyageurs', 'Bd Ba Hmad, Casablanca'));
    reponses = (await api('/whatsapp/demo/message', { id: ID, position: { lat: 33.5897, lng: -7.5906, nom: 'Gare Casa Voyageurs' } })).reponses;
    await wait(800);
    r.caption('Partagé, Seul ou Premium : le prix total, annoncé avant de commander');
    await repondre(reponses);
    await wait(3000);

    // 4. Choix de l'offre : la course part.
    r.caption('Un bouton, et la course est commandée');
    await toucher('[data-bt="offre:partage"]');
    await wait(400);
    await page.evaluate(() => window.wa.texte(true, 'Partagé'));
    reponses = (await api('/whatsapp/demo/message', { id: ID, bouton: 'offre:partage' })).reponses;
    await repondre(reponses);
    await wait(2500);

    // 5. Un chauffeur accepte.
    r.caption(null);
    r.skip(true);
    await api('/whatsapp/demo/chauffeur', { id: ID });
    let boite = [];
    for (let i = 0; i < 10 && !boite.length; i++) {
      await wait(500);
      boite = await api(`/whatsapp/demo/boite?id=${ID}`);
    }
    await page.evaluate(() => window.wa.chip('Quelques instants plus tard'));
    r.skip(false);
    if (boite.length) {
      r.caption('Un chauffeur a accepté : elle est prévenue sur WhatsApp');
      await repondre(boite);
      await wait(2500);
    }

    // 6. « Suivre mon taxi » ouvre l'application.
    r.caption('« Suivre mon taxi » ouvre l’application Bab Taxi');
    await wait(1500);
    await toucher('[data-bt="lien"]');
    await wait(700);
    r.skip(true);
    r.caption(null);
    // Application (démo), dans un nouvel onglet : même course, du Twin Center, pour montrer le suivi en direct.
    const ctxApp = await browser.newContext({ viewport: VIEW, deviceScaleFactor: DPR, locale: 'fr-FR' });
    await ctxApp.addInitScript(pointeur(false));
    const app = await ctxApp.newPage();
    await app.goto(`${appli}?demo=1&video=1`, { waitUntil: 'load' });
    await app.waitForTimeout(5000);
    await app.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
    const label = (t) => app.locator(`[role][aria-label*="${t}"], flt-semantics[role]:has-text("${t}"), input[aria-label*="${t}"]`).last();
    await label('Rechercher une destination').click({ timeout: 60000 });
    await app.waitForTimeout(1000);
    await app.keyboard.type('twin', { delay: 80 });
    await label('Twin Center').click({ timeout: 20000 });
    await label('Commander').waitFor({ timeout: 20000 });
    await app.waitForTimeout(800);
    await label('Commander').click();
    await app
      .locator('flt-semantics:has-text("a accepté en premier"), [aria-label*="a accepté en premier"]')
      .first()
      .waitFor({ timeout: 60000 });
    await app.waitForTimeout(2500);
    await r.changerPage(app);
    r.skip(false);
    r.caption('Le taxi arrive, suivi en direct sur la carte');
    await app.waitForTimeout(6000);
    r.caption(null);
    await app.waitForTimeout(600);
    r.marks.sons = sons;
    await r.fin({
      titre: 'Commander sur WhatsApp',
      sousTitre: 'Un vocal, deux boutons, le taxi arrive',
      fin: 'Sur WhatsApp ou dans l’application',
    });
    console.log(`whatsapp : ${r.marks.duration.toFixed(1)} s, ${r.marks.frames.length} images, ${sons.length} sons`);
  } catch (e) {
    console.log(`::error title=Vidéo WhatsApp::${String(e.message || e).split('\n')[0]}`);
    await page.screenshot({ path: path.join(out, 'echec.png') }).catch(() => {});
    process.exitCode = 1;
  }
  await browser.close();
})();
