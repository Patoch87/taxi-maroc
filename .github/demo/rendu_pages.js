// Rendu de pages HTML en PNG transparents (titres, légendes, cartes) pour compose_fonction.py.
// Usage : node rendu_pages.js pages.json   ({ largeur, hauteur, dossier, pages: [{ fichier, html }] })
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

(async () => {
  const cfg = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: cfg.largeur, height: cfg.hauteur } });
  for (const p of cfg.pages) {
    const f = path.join(cfg.dossier, p.fichier.replace('.png', '.html'));
    fs.writeFileSync(f, p.html);
    await page.goto('file://' + f);
    await page.evaluate(() => document.fonts.ready);
    await page.screenshot({ path: path.join(cfg.dossier, p.fichier), omitBackground: true });
  }
  await browser.close();
})();
