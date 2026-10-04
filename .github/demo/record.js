// Vidéo de démo : enregistre la version web de l'application (vraie carte) avec Playwright.
// Usage : node record.js <url> <dossier de sortie>
// Écrit <sortie>/frames/*.jpg (images 780 x 1268 horodatées) et <sortie>/marks.json
// (images, légendes et passages à couper, en secondes).
// Chaque étape vérifie que l'écran attendu est bien affiché : sinon le script s'arrête en erreur
// (jamais de vidéo dont les légendes ne correspondent pas à l'image).
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

// Texte de la carte de fin (modifiable ici).
const END_LINE = 'Casablanca 2026 → Mondial 2030';
// Écran de téléphone 390 x 634 points, densité 2 : images 780 x 1268, ramenées à 720 x 1170 au montage ;
// la légende (110 px) est ajoutée dessous.
const VIEW = { width: 390, height: 634 };

(async () => {
  const [url, out] = process.argv.slice(2);
  const framesDir = path.join(out, 'frames');
  fs.mkdirSync(framesDir, { recursive: true });
  const browser = await chromium.launch();
  const context = await browser.newContext({
    viewport: VIEW,
    deviceScaleFactor: 2,
    locale: 'fr-FR',
    ignoreHTTPSErrors: true,
  });
  // Réseau particulier (tests locaux derrière un proxy) : module facultatif.
  if (process.env.DEMO_NET) await require(path.resolve(process.env.DEMO_NET))(context);
  const page = await context.newPage();
  const t0 = Date.now() / 1000;
  const now = () => Date.now() / 1000 - t0;
  const marks = { frames: [], captions: [], skips: [] };

  // Images de l'écran en pleine définition (captures DevTools en continu, ~15 par seconde),
  // chacune avec son heure ; en pause pendant les passages coupés au montage.
  const cdp = await context.newCDPSession(page);
  let n = 0,
    paused = false,
    running = true;
  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
  const shoot = { format: 'jpeg', quality: 88, clip: { x: 0, y: 0, ...VIEW, scale: 2 } };
  const recorder = (async () => {
    while (running) {
      const start = Date.now();
      if (!paused) {
        try {
          const t = now();
          const { data } = await cdp.send('Page.captureScreenshot', shoot);
          const file = `f${String(n++).padStart(6, '0')}.jpg`;
          fs.writeFileSync(path.join(framesDir, file), Buffer.from(data, 'base64'));
          marks.frames.push({ file, t });
        } catch (e) {
          // page en cours de chargement : image suivante
        }
      }
      await sleep(Math.max(5, 66 - (Date.now() - start)));
    }
  })();

  let current = null;
  const caption = (text) => {
    if (current) current.end = now();
    current = text ? { text, start: now() } : null;
    if (current) marks.captions.push(current);
  };
  let skipStart = null;
  const skip = (on) => {
    paused = on;
    if (on) skipStart = now();
    else if (skipStart !== null) {
      marks.skips.push({ start: skipStart, end: now() });
      skipStart = null;
    }
  };
  const wait = (ms) => page.waitForTimeout(ms);
  const target = (label) =>
    page.locator(`[role][aria-label*="${label}"], flt-semantics[role]:has-text("${label}")`).last();
  // Texte présent à l'écran (respecte les majuscules) : libellés d'accessibilité, champs, textes.
  const present = (text) =>
    page
      .evaluate(
        (t) =>
          [...document.querySelectorAll('flt-semantics, [aria-label], input, textarea')].some(
            (e) =>
              (e.getAttribute('aria-label') || '').includes(t) ||
              (e.value || '').includes(t) ||
              (!e.querySelector('flt-semantics') && (e.textContent || '').includes(t)),
          ),
        text,
      )
      .catch(() => false);
  // Touche un élément ; s'il est hors de l'écran (bas du panneau), fait défiler le panneau d'abord.
  const tap = async (label, timeout = 15000) => {
    const el = target(label);
    await el.waitFor({ state: 'attached', timeout });
    for (let i = 0; i < 8; i++) {
      const b = await el.boundingBox();
      if (!b) break;
      const cy = b.y + b.height / 2;
      if (cy > VIEW.height - 8) await scrollPanel(120, 1);
      else if (cy < 8) await scrollPanel(-120, 1);
      else return page.mouse.click(b.x + b.width / 2, cy);
      await wait(350);
    }
    await el.click({ timeout });
  };
  const semantics = async () => {
    await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
    await wait(800);
  };
  // Attend un texte à l'écran ; « step » : nom de l'étape pour le message d'erreur.
  const waitFor = async (text, maxSec = 30) => {
    for (let i = 0; i < maxSec * 2; i++) {
      if (await present(text)) return true;
      if (i % 20 === 19) await semantics();
      await wait(500);
    }
    return false;
  };
  const expectScreen = async (step, text, maxSec = 30) => {
    if (!(await waitFor(text, maxSec))) {
      await page.screenshot({ path: path.join(out, 'echec.png') }).catch(() => {});
      const labels = await page
        .evaluate(() =>
          [...document.querySelectorAll('flt-semantics')]
            .filter((e) => !e.querySelector('flt-semantics'))
            .map((e) => e.getAttribute('aria-label') || e.textContent)
            .filter(Boolean)
            .slice(0, 80),
        )
        .catch(() => []);
      throw new Error(`étape « ${step} » : « ${text} » n'apparaît pas. Écran : ${JSON.stringify(labels)}`);
    }
  };
  // Touche « label » jusqu'à voir « text » (3 essais), sinon erreur.
  const tapFor = async (step, label, text, maxSec = 10) => {
    for (let i = 0; i < 3; i++) {
      await tap(label).catch(() => {});
      if (await waitFor(text, maxSec / 3)) return;
      await semantics();
    }
    await expectScreen(step, text, 1);
  };
  const typeInto = async (label, text) => {
    const input = page.locator(`input[aria-label*="${label}"], textarea[aria-label*="${label}"]`).first();
    if (await input.count()) await input.click({ timeout: 5000 });
    else await tap(label);
    await wait(300);
    await page.keyboard.type(text, { delay: 80 });
    await wait(300);
  };
  // Démo accélérée : touche « Accélérer » jusqu'à ×4.
  const fast = async () => {
    for (let i = 0; i < 4 && !(await present('Accélérer (démo) ×4')); i++) {
      await tap('Accélérer');
      await wait(300);
    }
    if (!(await present('Accélérer (démo) ×4'))) throw new Error('vitesse ×4 non atteinte');
  };
  const scrollPanel = async (dy, times = 4) => {
    await page.mouse.move(VIEW.width / 2, VIEW.height - 80);
    for (let i = 0; i < times; i++) {
      await page.mouse.wheel(0, dy);
      await wait(250);
    }
  };
  const card = (title, line) =>
    `${url}demo-card.html?title=${encodeURIComponent(title)}&line=${encodeURIComponent(line)}`;
  const app = `${url}?demo=1`;

  // 1. Carte de titre
  await page.goto(card('Taxi Maroc — démo', 'Le taxi marocain, simple et sûr'));
  await wait(3200);

  // Chargement de l'application en démo directe (?demo=1) : coupé au montage.
  skip(true);
  await page.goto(app, { waitUntil: 'load' });
  await wait(5000);
  await semantics();
  await expectScreen('accueil', 'Rechercher une destination', 60);
  await wait(1000);
  skip(false);

  // 2. Accueil et recherche
  caption('Où allez-vous ? Recherche ou voix');
  await wait(1500);
  await tap('Rechercher une destination');
  await wait(1200);
  await page.keyboard.type('mall', { delay: 120 });
  await wait(1000);
  await expectScreen('recherche', 'Morocco Mall');
  await tap('Morocco Mall');

  // 3. Choix du taxi, valises et siège bébé
  await expectScreen('options', 'Commander');
  caption('Prix affiché à l\'avance, sans négociation');
  await wait(2500);
  await tap('Une valise de plus');
  await wait(500);
  await tap('Une valise de plus');
  await wait(500);
  await tap('Siège bébé');
  await wait(1200);
  await tap('Petit taxi seul');
  await wait(1500);
  await tap('Commander');

  // 4. Envoi aux chauffeurs, puis chauffeur trouvé
  caption('La demande part aux taxis les plus proches');
  await wait(4000);
  await expectScreen('chauffeur', 'Accélérer', 40);
  caption('Chauffeur identifié, trajet traçable');
  await wait(4000);

  // 5. Panneau à glisser : la carte
  const handle = target('Afficher ou masquer les détails');
  const box = await handle.boundingBox({ timeout: 10000 });
  if (!box) throw new Error('étape « panneau » : poignée introuvable');
  caption('Glisser le panneau pour voir la carte');
  const x = box.x + box.width / 2,
    y = box.y + box.height / 2;
  await page.mouse.move(x, y);
  await page.mouse.down();
  await page.mouse.move(x, Math.min(VIEW.height - 40, y + 260), { steps: 15 });
  await page.mouse.up();
  await wait(3500);
  await tap('Afficher ou masquer les détails');
  await wait(1500);

  // Démo ×4 jusqu'à l'arrivée du taxi (attente coupée).
  caption('Démo accélérée ×4');
  await fast();
  await wait(1500);
  skip(true);
  await expectScreen('arrivée du taxi', 'Je suis dans le taxi', 300);
  skip(false);
  caption('Le taxi est arrivé');
  await wait(2000);
  await tap('Je suis dans le taxi');
  await wait(1500);

  // 6. À bord : offre et bon avec QR code
  await scrollPanel(300, 4);
  await expectScreen('offre', 'nouvelle collection', 30);
  caption('Offres le long du trajet, avec QR code');
  await wait(1500);
  await tap('nouvelle collection');
  await expectScreen('bon QR', 'TM-', 15);
  await wait(4500);
  await page.keyboard.press('Escape');
  await wait(1000);
  await scrollPanel(-300, 4);
  await fast();

  // Trajet jusqu'au Morocco Mall : coupé au montage.
  caption(null);
  skip(true);
  await expectScreen('arrivée', '5 étoiles sur 5', 1200);
  await wait(1000);
  skip(false);

  // 7. Arrivée : drapeau, note, avis, pourboire
  caption('Noter, commenter, pourboire par carte');
  await wait(2000);
  await tap('5 étoiles sur 5');
  await wait(700);
  await tap('Ponctuel');
  await wait(400);
  await tap('Conduite prudente');
  await wait(400);
  await tap('10 DH');
  await wait(2500);

  // 8. Restaurant : confirmation du nouveau prix
  await scrollPanel(300, 3);
  await expectScreen('restaurant', 'Y aller en taxi', 15);
  await wait(800);
  await tap('Y aller en taxi');
  await expectScreen('confirmation restaurant', 'Annuler', 10);
  caption('Restaurant proche : nouveau prix confirmé avant');
  await wait(4000);
  await tap('Annuler');
  await wait(800);
  caption('Noter, commenter, pourboire par carte');
  await scrollPanel(-300, 4);
  await tap('Envoyer');
  await expectScreen('paiement', 'Payer', 10);
  await wait(1500);
  await tap('Payer');
  await expectScreen('paiement accepté', 'OK', 15);
  await wait(2000);
  await tap('OK');
  await expectScreen('retour accueil', 'Rechercher une destination', 30);
  await wait(1000);

  // 9. Langues
  await tapFor('choix de la langue', 'Langue : Français', 'العربية', 12);
  caption('16 langues');
  await wait(1500);
  await tap('العربية');
  await wait(2500);
  await semantics();
  await expectScreen('arabe', 'اللغة', 20);
  await wait(2000);
  await tapFor('choix de la langue (arabe)', 'اللغة', 'Français', 12);
  await wait(1000);
  await tap('Français');
  await wait(2000);
  await semantics();
  await expectScreen('retour en français', 'Mode senior', 20);

  // 10. Mode senior
  await tapFor('mode senior', 'Mode senior', 'Revenir au mode normal', 15);
  caption('Mode senior simplifié');
  await wait(3500);
  await tap('Revenir au mode normal');
  await expectScreen('sortie du mode senior', 'Rechercher une destination', 15);
  await wait(1000);

  // 11. Mode chauffeur
  caption(null);
  await tapFor('menu', 'Ouvrir le menu de navigation', 'Mode chauffeur', 12);
  await tapFor('mode chauffeur', 'Mode chauffeur', 'Passer en ligne', 15);
  caption('Mode chauffeur : passagers sur le chemin, feux de détresse');
  await wait(2000);
  await tapFor('en ligne', 'Passer en ligne', 'En ligne', 15);
  skip(true);
  await expectScreen('demande de course', 'Accepter', 90);
  skip(false);
  await wait(3000);
  await tap('Accepter');
  await wait(2000);
  // Approche du passager : attente coupée, puis rappel des feux de détresse.
  skip(true);
  let hazard = false;
  for (let i = 0; i < 600 && !hazard; i++) {
    hazard = await present('Allumez vos feux');
    if (!hazard && (await target('Accepter').count())) await tap('Accepter').catch(() => {});
    if (!hazard) await wait(500);
  }
  skip(false);
  await expectScreen('feux de détresse', 'Allumez vos feux', 5);
  await wait(4500);

  // 12. Carte de fin
  caption(null);
  await page.goto(card('Taxi Maroc', END_LINE));
  await wait(3500);
  marks.duration = now();

  running = false;
  await recorder;
  fs.writeFileSync(path.join(out, 'marks.json'), JSON.stringify(marks, null, 2));
  await browser.close();
  console.log('enregistrement :', marks.duration.toFixed(1), 's,', marks.frames.length, 'images');
})().catch((e) => {
  console.error(e.message || e);
  process.exit(1);
});
