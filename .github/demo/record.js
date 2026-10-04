// Vidéo de démo : enregistre la version web de l'application (vraie carte) avec Playwright.
// Usage : node record.js <url> <dossier de sortie>
// Écrit <sortie>/raw.webm et <sortie>/marks.json (légendes et passages à couper, en secondes).
const { chromium } = require('playwright');
const fs = require('fs');

// Texte de la carte de fin (modifiable ici).
const END_LINE = 'Casablanca 2026 → Mondial 2030';

(async () => {
  const [url, out] = process.argv.slice(2);
  fs.mkdirSync(out, { recursive: true });
  const browser = await chromium.launch();
  // Écran de téléphone : l'image est mise à l'échelle 720 x 1170, la légende est ajoutée en dessous par ffmpeg.
  const context = await browser.newContext({
    viewport: { width: 400, height: 650 },
    deviceScaleFactor: 2,
    locale: 'fr-FR',
    recordVideo: { dir: out, size: { width: 720, height: 1170 } },
  });
  const page = await context.newPage();
  const t0 = Date.now();
  const now = () => (Date.now() - t0) / 1000;
  const marks = { captions: [], skips: [] };
  let current = null;
  const caption = (text) => {
    if (current) current.end = now();
    current = text ? { text, start: now() } : null;
    if (current) marks.captions.push(current);
  };
  let skipStart = null;
  const skip = (on) => {
    if (on) skipStart = now();
    else if (skipStart !== null) {
      marks.skips.push({ start: skipStart, end: now() });
      skipStart = null;
    }
  };
  const wait = (ms) => page.waitForTimeout(ms);
  const target = (label) =>
    page.locator(`[role][aria-label*="${label}"], flt-semantics[role]:has-text("${label}")`).last();
  const tap = async (label, timeout = 15000) => {
    await target(label).click({ timeout });
  };
  const soft = async (name, fn) => {
    try {
      await fn();
    } catch (e) {
      console.error('étape ratée :', name, e.message);
    }
  };
  const waitFor = async (label, maxSec = 120) => {
    for (let i = 0; i < maxSec * 2; i++) {
      if (await target(label).count()) return true;
      await wait(500);
    }
    return false;
  };
  const semantics = async () => {
    await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
    await wait(800);
  };
  const typeInto = async (label, text) => {
    const input = page.locator(`input[aria-label*="${label}"], textarea[aria-label*="${label}"]`).first();
    if (await input.count()) await input.click({ timeout: 5000 });
    else await tap(label);
    await wait(300);
    await page.keyboard.type(text, { delay: 70 });
    await wait(300);
  };
  const fast = async () => {
    for (let i = 0; i < 3; i++) {
      await soft('accélérer', () => tap('Accélérer'));
      await wait(250);
    }
  };
  const scrollPanel = async (dy, times = 4) => {
    await page.mouse.move(200, 560);
    for (let i = 0; i < times; i++) {
      await page.mouse.wheel(0, dy);
      await wait(250);
    }
  };
  const card = (title, line) =>
    `${url}demo-card.html?title=${encodeURIComponent(title)}&line=${encodeURIComponent(line)}`;

  // 1. Carte de titre
  await page.goto(card('Taxi Maroc — démo', 'Le taxi marocain, simple et sûr'));
  await wait(3200);

  // Chargement de l'application : coupé au montage.
  skip(true);
  await page.goto(url, { waitUntil: 'load' });
  await wait(6000);
  await semantics();
  skip(false);

  // 2. Création du compte
  caption('Créer un compte en 30 secondes');
  await soft('compte', async () => {
    await typeInto('Prénom', 'Lucía');
    await typeInto('Nom', 'García');
    await tap('Nationalité');
    await wait(1200);
    await page.keyboard.type('espa', { delay: 90 });
    await wait(900);
    await tap('Espagne');
    await wait(1500);
  });
  await soft('démo', () => tap('Continuer en démo'));
  await wait(1500);

  // 3. Accueil et recherche
  caption('Où allez-vous ? Recherche ou voix');
  await soft('recherche', async () => {
    await tap('Rechercher une destination');
    await wait(1200);
    await page.keyboard.type('mall', { delay: 110 });
    await wait(900);
    await tap('Morocco Mall');
  });
  await wait(3000);

  // 4. Choix du taxi
  caption('Prix affiché à l\'avance, sans négociation');
  await wait(2500);
  await soft('valises', async () => {
    await tap('Une valise de plus');
    await wait(500);
    await tap('Une valise de plus');
    await wait(500);
    await tap('Siège bébé');
  });
  await wait(2500);
  await soft('commander', () => tap('Commander'));

  // 5. Envoi aux chauffeurs, puis chauffeur trouvé
  caption('La demande part aux taxis les plus proches');
  await wait(5500);
  caption('Chauffeur identifié, trajet traçable');
  await waitFor('Accélérer', 20);
  await wait(3500);
  await scrollPanel(150, 2);
  await wait(1500);
  await scrollPanel(-150, 2);

  // 6. Panneau à glisser : la carte
  caption('Glisser le panneau pour voir la carte');
  await soft('poignée', async () => {
    const box = await target('Afficher ou masquer les détails').boundingBox();
    if (box) {
      const x = box.x + box.width / 2, y = box.y + box.height / 2;
      await page.mouse.move(x, y);
      await page.mouse.down();
      await page.mouse.move(x, y + 220, { steps: 15 });
      await page.mouse.up();
      await wait(3500);
      await tap('Afficher ou masquer les détails');
    }
  });
  await wait(1500);

  // Démo ×4 jusqu'à l'arrivée du taxi (attente coupée).
  caption('Démo accélérée ×4');
  await fast();
  await wait(1500);
  skip(true);
  await waitFor('Je suis dans le taxi', 60);
  skip(false);
  caption('Le taxi est arrivé');
  await wait(1500);
  await soft('à bord', () => tap('Je suis dans le taxi'));
  await wait(1500);

  // 7. À bord : offre et bon avec QR code
  caption('Offres le long du trajet, avec QR code');
  await scrollPanel(300, 4);
  await wait(1500);
  await soft('offre', () => tap('nouvelle collection'));
  await wait(4500);
  await page.keyboard.press('Escape');
  await wait(1000);
  await scrollPanel(-300, 4);
  await fast();

  // Trajet jusqu'au Morocco Mall : coupé au montage.
  caption(null);
  skip(true);
  await waitFor('5 étoiles sur 5', 900);
  skip(false);

  // 8. Arrivée : note, avis, pourboire
  caption('Noter, commenter, pourboire par carte');
  await wait(1500);
  await soft('note', async () => {
    await tap('5 étoiles sur 5');
    await wait(700);
    await tap('Ponctuel');
    await wait(400);
    await tap('Conduite prudente');
    await wait(400);
    await tap('10 DH');
  });
  await wait(2500);

  // 9. Restaurant : confirmation du nouveau prix
  caption('Restaurant proche : nouveau prix confirmé avant');
  await soft('restaurant', async () => {
    await scrollPanel(300, 2);
    await tap('Y aller en taxi');
    await wait(3500);
    await tap('Annuler');
  });
  await wait(800);
  caption('Noter, commenter, pourboire par carte');
  await soft('envoyer', async () => {
    await scrollPanel(-300, 4);
    await tap('Envoyer');
    await wait(2000);
    await tap('Payer');
    await wait(2500);
    await tap('OK');
  });
  await wait(1500);

  // 10. Langues
  caption('16 langues');
  await soft('langue', async () => {
    await tap('Langue');
    await wait(1800);
    await tap('العربية');
    await wait(3000);
    await semantics();
    await tap('اللغة');
    await wait(1500);
    await tap('Français');
  });
  await wait(2000);
  await semantics();

  // 11. Mode senior
  caption('Mode senior simplifié');
  await soft('senior', async () => {
    await tap('Mode senior');
    await wait(3500);
    await tap('Revenir au mode normal');
  });
  await wait(1500);

  // 12. Mode chauffeur
  caption('Mode chauffeur : passagers sur le chemin, feux de détresse');
  await soft('chauffeur', async () => {
    await page.mouse.click(32, 34); // menu
    await wait(1200);
    await tap('Mode chauffeur');
    await wait(2500);
    await tap('Passer en ligne');
    skip(true);
    await waitFor('Accepter', 60);
    skip(false);
    await wait(2500);
    await tap('Accepter');
    await wait(2000);
    // Approche du passager : attente coupée, puis rappel des feux de détresse.
    skip(true);
    for (let i = 0; i < 240; i++) {
      if (await target('Allumez vos feux').count()) break;
      if (await target('Accepter').count()) await tap('Accepter').catch(() => {});
      await wait(500);
    }
    skip(false);
    await wait(4000);
  });

  // 13. Carte de fin
  caption(null);
  await page.goto(card('Taxi Maroc', END_LINE));
  await wait(3500);
  caption(null);
  marks.duration = now();

  await context.close();
  const video = await page.video().path();
  fs.renameSync(video, `${out}/raw.webm`);
  fs.writeFileSync(`${out}/marks.json`, JSON.stringify(marks, null, 2));
  await browser.close();
  console.log('vidéo brute :', marks.duration.toFixed(1), 's');
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
