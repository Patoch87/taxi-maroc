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

  await browser.close();
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
