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

// Page en cours, pour la capture d'écran en cas d'échec.
let failPage = null;
const [url, out] = process.argv.slice(2);

(async () => {
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
  failPage = page;
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
    if (on) skipStart ??= now();
    else if (skipStart !== null) {
      marks.skips.push({ start: skipStart, end: now() });
      skipStart = null;
    }
  };
  const wait = (ms) => page.waitForTimeout(ms);
  const target = (label) =>
    page
      .locator(
        `[role][aria-label*="${label}"], input[aria-label*="${label}"], textarea[aria-label*="${label}"], ` +
          `flt-semantics[role]:has-text("${label}")`,
      )
      .last();
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
    for (let i = 0; i < 4 && !(await present('Accélérer ×4')); i++) {
      await tap('Accélérer');
      await wait(300);
    }
    if (!(await present('Accélérer ×4'))) throw new Error('vitesse ×4 non atteinte');
  };
  const scrollPanel = async (dy, times = 4) => {
    await page.mouse.move(VIEW.width / 2, VIEW.height - 80);
    for (let i = 0; i < times; i++) {
      await page.mouse.wheel(0, dy);
      await wait(250);
    }
  };
  const card = (q) => `${url}demo-card.html?${new URLSearchParams(q)}`;
  // Carte de chapitre posée par-dessus l'application (l'état de l'application est conservé).
  const chapterCard = async (chapter, title, line, ms = 4000) => {
    caption(null);
    skip(true);
    await page.evaluate((src) => {
      const f = document.createElement('iframe');
      f.id = 'demo-chapter';
      f.src = src;
      f.style.cssText = 'position:fixed;inset:0;width:100%;height:100%;border:0;z-index:2147483647;background:#FFF8E7';
      document.body.appendChild(f);
      return new Promise((r) => (f.onload = r));
    }, card({ chapter, title, line }));
    await wait(500);
    skip(false);
    await wait(ms);
    skip(true);
    await page.evaluate(() => document.getElementById('demo-chapter')?.remove());
    await wait(600);
    skip(false);
  };
  // Saisie dans un champ de texte Flutter : touche le champ puis tape au clavier.
  const fill = async (label, text, delay = 90) => {
    await tap(label);
    await wait(400);
    await page.keyboard.type(text, { delay });
    await wait(400);
    if (!(await present(text))) throw new Error(`saisie « ${text} » dans « ${label} » non prise en compte`);
  };
  const ONLY = process.env.DEMO_ONLY; // tests : « signup », « client » ou « driver » seulement

  // Carte de titre
  await page.goto(card({ title: 'Bab Taxi — démo', line: 'Le taxi marocain, simple et sûr' }));
  await wait(3500);

  // Chargement de l'application (premier lancement, écran d'inscription) : coupé au montage.
  skip(true);
  // « video=1 » : sans suggestions de restaurants ; « demo=1 » : sans inscription (tests d'un seul chapitre).
  await page.goto(ONLY && ONLY !== 'signup' ? `${url}?demo=1&video=1` : `${url}?video=1`, { waitUntil: 'load' });
  await wait(5000);
  await semantics();

  // ---------------------------------------------------------------- Chapitre 1 : inscription
  if (!ONLY || ONLY === 'signup') {
    await expectScreen('inscription', 'Prénom', 60);
    await wait(800);
    skip(false);
    await chapterCard('1/3', 'Inscription', 'Créer son compte : nom, téléphone vérifié par SMS, nationalité');

    caption('Prénom et nom');
    await wait(800);
    await fill('Prénom', 'Claire');
    await fill('Nom', 'Martin');
    await wait(600);

    caption('Indicatif du pays, avec son drapeau');
    await tapFor('liste des indicatifs', 'Indicatif', 'Rechercher un pays ou un indicatif', 12);
    await wait(1200);
    await fill('Rechercher un pays ou un indicatif', 'maroc', 120);
    await expectScreen('indicatif Maroc', '+212', 10);
    await wait(1000);
    await tapFor("choix de l'indicatif", 'Maroc', 'Numéro de téléphone', 12);
    await expectScreen('indicatif choisi', 'Indicatif : Maroc +212', 5);
    await wait(800);

    caption('Téléphone vérifié par code SMS');
    await fill('Numéro de téléphone', '612345678');
    await tapFor('envoi du code', 'Recevoir le code par SMS', 'Code reçu par SMS', 10);
    await wait(1200);
    await fill('Code reçu par SMS', '1234', 220);
    await expectScreen('numéro vérifié', 'Numéro vérifié', 10);
    await wait(1500);

    caption('Nationalité choisie dans la liste');
    await tapFor('liste des nationalités', 'Nationalité', 'Rechercher un pays', 12);
    await wait(1000);
    await fill('Rechercher un pays', 'fran', 140);
    await expectScreen('nationalité France', 'France', 10);
    await wait(900);
    await tapFor('choix de la nationalité', 'France', 'Nationalité : France', 12);
    await wait(1800);

    caption('Compte créé en quelques secondes');
    await tapFor('création du compte', 'Créer un compte', 'Rechercher une destination', 15);
    await wait(2500);
  } else {
    await expectScreen('accueil', 'Rechercher une destination', 60);
    skip(false);
  }

  // ---------------------------------------------------------------- Chapitre 2 : expérience client
  if (!ONLY || ONLY === 'client') {
    await chapterCard('2/3', 'Expérience client', 'Le passager commande, voit son chauffeur et paie le prix affiché');

    caption('Où allez-vous ? Recherche ou voix');
    await wait(1200);
    await tap('Rechercher une destination');
    await wait(1200);
    await page.keyboard.type('mall', { delay: 120 });
    await expectScreen('recherche', 'Morocco Mall');
    await wait(800);
    await tap('Morocco Mall');

    await expectScreen('options', 'Commander');
    caption("Prix affiché à l'avance, sans négociation");
    await wait(3000);
    caption('Valises et siège bébé en option');
    await tap('Une valise de plus');
    await wait(600);
    await tap('Une valise de plus');
    await wait(600);
    await tap('Siège bébé');
    await wait(1200);
    await tap('Petit taxi seul');
    await wait(1500);
    await tap('Commander');

    caption("Envoyée aux taxis proches : le premier qui accepte l'emporte");
    await expectScreen('envoi aux chauffeurs', 'Demande envoyée', 15);
    await expectScreen('chauffeur trouvé', 'a accepté en premier', 30);
    await wait(2500);
    await expectScreen('chauffeur', 'Accélérer', 40);
    caption('Chauffeur identifié : photo, plaque, langues');
    await wait(4500);

    const handle = target('Afficher ou masquer les détails');
    const box = await handle.boundingBox({ timeout: 10000 });
    if (!box) throw new Error('étape « panneau » : poignée introuvable');
    caption('Panneau glissé : la carte, le partage et le SOS');
    const x = box.x + box.width / 2,
      y = box.y + box.height / 2;
    await page.mouse.move(x, y);
    await page.mouse.down();
    await page.mouse.move(x, Math.min(VIEW.height - 40, y + 300), { steps: 15 });
    await page.mouse.up();
    await expectScreen('carte', 'SOS', 10);
    await wait(3500);
    await tap('Afficher ou masquer les détails');
    await wait(1200);

    // Attente du taxi en ×4 : coupée au montage.
    await fast();
    skip(true);
    await expectScreen('arrivée du taxi', 'Je suis dans le taxi', 300);
    skip(false);
    caption('Le taxi est arrivé');
    await wait(2500);
    // Montée à bord : l'offre affichée pendant la course est fermée hors caméra.
    skip(true);
    await tap('Je suis dans le taxi');
    for (let i = 0; i < 20 && !(await present('Masquer la publicité')); i++) await wait(500);
    if (await present('Masquer la publicité')) await tap('Masquer la publicité');
    await wait(800);
    if (await present('Masquer la publicité')) throw new Error('étape « à bord » : offre toujours affichée');
    await fast();
    // Panneau replié : la carte et le trajet.
    await tap('Afficher ou masquer les détails');
    await wait(1500);
    if (await present('Masquer la publicité')) throw new Error('étape « à bord » : offre affichée sur la carte');
    skip(false);
    caption('À bord, démo accélérée ×4');
    await wait(4000);

    // Trajet jusqu'au Morocco Mall : coupé au montage.
    caption(null);
    skip(true);
    await tap('Afficher ou masquer les détails');
    await expectScreen('arrivée', '5 étoiles sur 5', 1200);
    await wait(1000);
    skip(false);

    caption('Arrivé : on note le chauffeur');
    await wait(1500);
    await tap('5 étoiles sur 5');
    await wait(700);
    await tap('Ponctuel');
    await wait(400);
    await tap('Conduite prudente');
    await wait(800);
    caption('Un commentaire, et le pourboire par carte');
    await fill('Un commentaire', 'Très bon chauffeur, merci !', 60);
    await wait(500);
    await tap('10 DH');
    await wait(1500);
    await tapFor('paiement', 'Envoyer', 'Payer', 10);
    await wait(1500);
    await tapFor('paiement accepté', 'Payer', 'Merci', 15);
    caption('Avis envoyé, merci !');
    await wait(2500);
    await tap('OK');
    await expectScreen('retour accueil', 'Rechercher une destination', 30);
    await wait(800);
  }

  // ---------------------------------------------------------------- Chapitre 3 : expérience chauffeur
  if (!ONLY || ONLY === 'driver') {
    caption(null);
    skip(true);
    await tapFor('menu', 'Ouvrir le menu de navigation', 'Mode chauffeur', 12);
    await tapFor('mode chauffeur', 'Mode chauffeur', 'Commencer le service', 15);
    await wait(1500);
    skip(false);
    await chapterCard(
      '3/3',
      'Expérience chauffeur',
      'Le chauffeur reçoit les courses sur son chemin, en toute sécurité',
    );

    caption('Indisponible : le chauffeur choisit quand il travaille');
    await expectScreen('indisponible', 'Indisponible', 5);
    await wait(3000);
    await tapFor('en ligne', 'Commencer le service', 'Disponible', 15);
    caption('En ligne : les courses arrivent sur son chemin');
    await wait(2500);
    // Montre un écran tant que « still » reste vrai (au plus « ms ») ; renvoie la durée montrée (s).
    const hold = async (ms, still) => {
      const t = now();
      while (now() - t < ms / 1000 && (await still())) await wait(150);
      return now() - t;
    };
    // Coupe après coup le passage montré depuis « from » (écran disparu trop tôt) : on recommence.
    const cutSince = (from) => {
      caption(null);
      marks.skips.push({ start: from, end: now() });
    };

    // Demande de course : montrée 3 s puis acceptée ; si elle disparaît avant (prise par un autre
    // chauffeur, expirée), le passage est coupé et on attend la suivante.
    let accepted = false;
    for (let attempt = 0; attempt < 6 && !accepted; attempt++) {
      skip(true);
      await expectScreen('demande de course', 'Accepter', 90);
      skip(false);
      const from = now();
      caption('Nouvelle demande : son doux, annonce en arabe (option)');
      await hold(3000, () => present('Accepter'));
      if (await present('Accepter')) {
        await tap('Accepter');
        accepted = true;
      } else cutSince(from);
    }
    if (!accepted) throw new Error('étape « demande de course » : aucune demande acceptée');
    await expectScreen('prochains arrêts', 'Prochains arrêts', 10);
    await wait(800);
    caption('Passagers à bord et prochains arrêts');
    await hold(3000, async () => !(await present('Accepter')));
    caption(null);

    // Approche du passager : attente coupée ; les autres demandes sont acceptées. Le rappel des feux
    // de détresse est montré au moins 2,5 s sans demande par-dessus, sinon on attend le suivant.
    let hazardShown = false;
    for (let attempt = 0; attempt < 8 && !hazardShown; attempt++) {
      skip(true);
      let hazard = false;
      for (let i = 0; i < 600 && !hazard; i++) {
        hazard = (await present('Allumez vos feux')) && !(await present('Accepter'));
        if (!hazard && (await present('Accepter'))) await tap('Accepter').catch(() => {});
        if (!hazard) await wait(300);
      }
      if (!hazard) break;
      skip(false);
      const from = now();
      caption('À 50 m du passager : feux de détresse');
      const shown = await hold(4000, async () => (await present('Allumez vos feux')) && !(await present('Accepter')));
      if (shown >= 2.5) hazardShown = true;
      else cutSince(from);
    }
    if (!hazardShown) throw new Error('étape « feux de détresse » : rappel non montré');
    skip(true);
    if (await present('Allumez vos feux')) await tap('OK').catch(() => {});
    // Trajet jusqu'à la dépose : coupé.
    caption(null);
    let dropped = false;
    for (let i = 0; i < 600 && !dropped; i++) {
      dropped = await present('Passager déposé');
      if (!dropped && (await present('Accepter'))) await tap('Accepter').catch(() => {});
      if (!dropped) await wait(250);
    }
    skip(false);
    await expectScreen('dépose', 'Passager déposé', 2);
    caption('Course terminée : gains et pourboires du jour');
    await wait(4500);
  }

  // Carte de fin
  caption(null);
  await page.goto(card({ title: 'Bab Taxi', line: END_LINE }));
  await wait(3500);
  marks.duration = now();

  running = false;
  await recorder;
  fs.writeFileSync(path.join(out, 'marks.json'), JSON.stringify(marks, null, 2));
  await browser.close();
  console.log('enregistrement :', marks.duration.toFixed(1), 's,', marks.frames.length, 'images');
})().catch(async (e) => {
  const msg = String(e.message || e)
    .split('\n')[0]
    .slice(0, 1500);
  // Annotation GitHub Actions (lisible sans les journaux) + capture de l'écran fautif.
  console.log(`::error title=Vidéo de démo::${msg}`);
  try {
    if (failPage && !fs.existsSync(path.join(out, 'echec.png')))
      await failPage.screenshot({ path: path.join(out, 'echec.png'), timeout: 5000 });
  } catch (_) {
    // pas de capture possible
  }
  process.exit(1);
});
