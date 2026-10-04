// Captures d'écran de l'application (version web) avec la vraie carte.
// Usage : node capture.js <url> <dossier de sortie>
const { chromium } = require('playwright');

(async () => {
  const [url, out] = process.argv.slice(2);
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, locale: 'fr-FR' });
  if (process.env.FAKE_TILES) {
    const fs = require('fs');
    await page.route(/cartocdn|openstreetmap/, (r) => r.fulfill({ body: fs.readFileSync(process.env.FAKE_TILES), contentType: 'image/png' }));
    await page.route(/project-osrm/, (r) => r.abort());
  }
  const shot = async (name, wait = 2500) => {
    await page.waitForTimeout(wait);
    await page.screenshot({ path: `${out}/${name}.png` });
    console.log('capture', name);
  };
  // Élément cliquable de Flutter (bouton, puce...) dont le libellé contient [label].
  const target = (label) =>
    page.locator(`[role][aria-label*="${label}"], flt-semantics[role]:has-text("${label}")`).last();
  const tap = async (label) => {
    await target(label).click({ timeout: 15000 });
  };
  const open = async () => {
    await page.goto(url, { waitUntil: 'load' });
    await page.waitForTimeout(6000);
    // Active l'arbre d'accessibilité de Flutter pour cliquer sur les boutons par leur nom.
    await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
    await page.waitForTimeout(1500);
  };

  // Passager
  await open();
  await shot('1-passager-accueil');
  await tap('Gare Casa Voyageurs');
  await shot('2-passager-choix-du-taxi', 4000);
  await tap('Commander');
  await shot('3-passager-envoi-aux-chauffeurs', 2000);
  await shot('4-passager-taxi-en-approche', 9000);
  await tap('Partager'); // ne fait rien de visible dans le navigateur de test
  await page.goto(url, { waitUntil: 'load' });

  // Recherche vocale (écran de recherche)
  await open();
  await tap('Rechercher une destination');
  await shot('5-recherche-destination', 2000);

  // Chauffeur
  await open();
  await page.mouse.click(32, 34); // menu
  await page.waitForTimeout(1000);
  await tap('Mode chauffeur');
  await shot('6-chauffeur-hors-ligne', 3000);
  await tap('Passer en ligne');
  await target('Accepter').waitFor({ timeout: 40000 });
  await shot('7-chauffeur-demande', 1500);
  await tap('Accepter');
  await shot('8-chauffeur-passager-a-bord', 12000);

  // Nouveautés : chaque partie est indépendante, un échec n'empêche pas les autres captures.
  const step = async (name, fn) => {
    try {
      await fn();
    } catch (e) {
      console.error('capture ratée :', name, e.message);
    }
  };
  // Saisie dans un champ de texte Flutter repéré par son libellé.
  const typeInto = async (label, text) => {
    const input = page.locator(`input[aria-label*="${label}"], textarea[aria-label*="${label}"]`).first();
    if (await input.count()) {
      await input.click({ timeout: 5000 });
    } else {
      await tap(label);
    }
    await page.waitForTimeout(400);
    await page.keyboard.type(text, { delay: 40 });
    await page.waitForTimeout(400);
  };

  // Commander pour quelqu'un d'autre
  await step('pour-un-proche', async () => {
    await open();
    await tap('Gare Casa Voyageurs');
    await page.waitForTimeout(3000);
    await tap('Qui prend le taxi');
    await page.waitForTimeout(1200);
    await tap("Pour quelqu'un d'autre");
    await page.waitForTimeout(800);
    await typeInto('Nom du passager', 'Fatima');
    await typeInto('Téléphone', '0611223344');
    await shot('9-commande-pour-un-proche-saisie', 800);
    await tap('Valider');
    await shot('10-commande-pour-un-proche', 1500);
  });

  // Réserver pour plus tard : date (demain si possible) puis heure
  await step('plus-tard', async () => {
    await open();
    await tap('Gare Casa Voyageurs');
    await page.waitForTimeout(3000);
    await tap('Maintenant');
    await page.waitForTimeout(1500);
    const tomorrow = new Date(Date.now() + 86400000).toLocaleDateString('fr-FR', {
      weekday: 'long',
      day: 'numeric',
      month: 'long',
    });
    try {
      await target(tomorrow).click({ timeout: 3000 });
    } catch (_) {}
    await shot('11-reservation-date', 800);
    await tap('OK');
    await page.waitForTimeout(1500);
    await tap('OK');
    await shot('12-reservation-plus-tard', 1500);
  });

  // Contacts de confiance
  await step('contacts', async () => {
    await open();
    await page.mouse.click(32, 34); // menu
    await page.waitForTimeout(1000);
    await tap('Contacts de confiance');
    await page.waitForTimeout(1500);
    await typeInto('Nom', 'Fatima');
    await typeInto('Téléphone', '0611223344');
    await tap('Ajouter');
    await page.waitForTimeout(800);
    await typeInto('Nom', 'Youssef');
    await typeInto('Téléphone', '0622334455');
    await tap('Ajouter');
    await shot('13-contacts-de-confiance', 1200);
  });

  // Offre contextuelle (exemple de démo) et taxi électrique
  await step('offre', async () => {
    await open();
    await tap('Rechercher une destination');
    await page.waitForTimeout(1500);
    await page.keyboard.type('mall', { delay: 60 });
    await page.waitForTimeout(800);
    await tap('Morocco Mall');
    await page.waitForTimeout(3500);
    await tap('Petit taxi seul');
    await shot('16-offre-exemple-publicitaire', 1200);
    await tap('Électrique');
    await shot('17-option-electrique', 1200);
  });

  // Chauffeur de taxi électrique : batterie et bornes de recharge
  await step('bornes', async () => {
    await open();
    await page.mouse.click(32, 34); // menu
    await page.waitForTimeout(1000);
    await tap('Mode chauffeur');
    await page.waitForTimeout(2500);
    await tap('Électrique');
    await page.waitForTimeout(500);
    await tap('Passer en ligne');
    await page.waitForTimeout(3000);
    await tap('Bornes de recharge');
    await shot('18-chauffeur-bornes-de-recharge', 1500);
    await tap('Y aller');
    await shot('19-chauffeur-vers-la-borne', 5000);
  });

  // Vue carte plein écran avec bandeau publicitaire
  await step('vue-carte', async () => {
    await open();
    await tap('Morocco Mall');
    await page.waitForTimeout(3500);
    await tap('Petit taxi seul');
    await page.waitForTimeout(500);
    await tap('Commander');
    await page.waitForTimeout(9000);
    await tap('Carte plein écran');
    await shot('20-vue-carte-pub', 3000);
  });

  // Choix de la langue (une seule option, grille de drapeaux), puis restaurants avec note TripAdvisor (démo)
  await step('langues', async () => {
    await open();
    await tap('Langue');
    await shot('21-choix-langue', 1500);
    await tap('English');
    await page.waitForTimeout(2500);
    await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
    await page.waitForTimeout(1000);
    await tap('Gare Casa Voyageurs');
    await page.waitForTimeout(3500);
    await tap('Request');
    await page.waitForTimeout(9000);
    // Fait défiler le panneau jusqu'aux restaurants.
    await page.mouse.move(195, 760);
    for (let i = 0; i < 6; i++) {
      await page.mouse.wheel(0, 300);
      await page.waitForTimeout(300);
    }
    await shot('22-restaurants-tripadvisor', 1500);
  });

  // Mode senior
  await step('senior', async () => {
    await open();
    await tap('Mode senior');
    await shot('14-mode-senior', 1500);
    await tap('Rentrer à la maison');
    await shot('15-mode-senior-course', 12000);
  });

  await browser.close();
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
