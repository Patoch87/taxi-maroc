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
    // Premier lancement : création du compte proposée ; les captures continuent en démo.
    if (!keepSignUp && (await target('Plus tard').count())) {
      await tap('Plus tard');
      await page.waitForTimeout(1500);
    }
  };
  let keepSignUp = false;
  // Accélère la démo jusqu'à ×4 (×1 → ×2 → ×3 → ×4).
  const fast = async () => {
    for (let i = 0; i < 3; i++) {
      await tap('Accélérer');
      await page.waitForTimeout(300);
    }
  };
  // Attend qu'un élément apparaisse (jusqu'à [max] secondes).
  const waitFor = async (label, max = 120) => {
    for (let i = 0; i < max; i += 2) {
      if (await target(label).count()) return;
      await page.waitForTimeout(2000);
    }
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
  await tap('Commencer le service');
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

  // Options : valises par taxi, siège bébé ; puis offre seulement passager à bord, bon avec QR code,
  // panneau replié (vue carte avec bandeau), et fin de course (note et pourboire).
  await step('offre', async () => {
    await open();
    // Panneau replié par la poignée : il ne reste que la recherche, la carte est visible.
    await tap('Afficher ou masquer les détails');
    await shot('23-panneau-replie', 1500);
    await tap('Afficher ou masquer les détails');
    await page.waitForTimeout(800);
    await tap('Rechercher une destination');
    await page.waitForTimeout(1500);
    await page.keyboard.type('mall', { delay: 60 });
    await page.waitForTimeout(800);
    await tap('Morocco Mall');
    await page.waitForTimeout(3500);
    await tap('Une valise de plus');
    await page.waitForTimeout(300);
    await tap('Une valise de plus');
    await page.waitForTimeout(300);
    await tap('Une valise de plus');
    await page.waitForTimeout(300);
    await tap('Siège bébé');
    await shot('24-options-valises-siege-bebe', 1500);
    await tap('Commander');
    await page.waitForTimeout(9000);
    await fast();
    await waitFor('Je suis dans le taxi');
    await tap('Je suis dans le taxi');
    await page.waitForTimeout(2000);
    // Passager à bord : l'offre apparaît en bas du panneau.
    await page.mouse.move(195, 760);
    for (let i = 0; i < 6; i++) {
      await page.mouse.wheel(0, 300);
      await page.waitForTimeout(300);
    }
    await shot('16-offre-exemple-publicitaire', 1200);
    await tap('nouvelle collection');
    await shot('25-offre-qr-code', 2000);
    await page.keyboard.press('Escape');
    await page.waitForTimeout(1200);
    await tap('Afficher ou masquer les détails');
    await shot('20-vue-carte-pub', 3000);
  });

  // Fin de course : note, avis rapides et pourboire (trajet court vers la gare, accéléré).
  await step('notation', async () => {
    await open();
    await tap('Gare Casa Voyageurs');
    await page.waitForTimeout(3500);
    await tap('Commander');
    await page.waitForTimeout(9000);
    await fast();
    await waitFor('Je suis dans le taxi');
    await tap('Je suis dans le taxi');
    await page.waitForTimeout(1500);
    await fast();
    await shot('28-acceleration-x4', 1500);
    // Restaurant : confirmation avec le nouveau prix avant de changer de destination.
    await page.mouse.move(195, 760);
    for (let i = 0; i < 6; i++) {
      await page.mouse.wheel(0, 300);
      await page.waitForTimeout(300);
    }
    await tap('Y aller en taxi');
    await shot('29-restaurant-confirmation-prix', 2500);
    await tap('Annuler');
    await waitFor('5 étoiles sur 5', 240);
    await page.waitForTimeout(1500);
    await tap('5 étoiles sur 5');
    await page.waitForTimeout(600);
    await tap('Ponctuel');
    await tap('Conduite prudente');
    await tap('10 DH');
    await shot('26-notation-pourboire', 1500);
  });

  // Création du compte au premier lancement : nationalité avec drapeaux et recherche.
  await step('compte', async () => {
    keepSignUp = true;
    await open();
    keepSignUp = false;
    // Chaque saisie est facultative : la capture est prise même si l'une d'elles échoue.
    const soft = async (fn) => {
      try {
        await fn();
      } catch (e) {
        console.error('compte :', e.message);
      }
    };
    await soft(() => typeInto('Prénom', 'Lucía'));
    await soft(() => typeInto('Nom', 'García'));
    await page.keyboard.press('Tab');
    await page.waitForTimeout(500);
    // Indicatif : liste complète avec drapeaux et recherche, Maroc +212 en premier.
    await soft(async () => {
      if (await target('Indicatif').count()) await tap('Indicatif');
      else await tap('+212');
    });
    await page.waitForTimeout(1500);
    await shot('27-creation-compte', 1500);
  });

  // Chauffeur : rappel des feux de détresse à 50 m du passager.
  await step('feux', async () => {
    await open();
    await page.mouse.click(32, 34); // menu
    await page.waitForTimeout(1000);
    await tap('Mode chauffeur');
    await page.waitForTimeout(2500);
    await tap('Commencer le service');
    await target('Accepter').waitFor({ timeout: 40000 });
    // Accepte les demandes jusqu'à approcher d'un passager (moins de 50 m) : le rappel s'affiche.
    for (let i = 0; i < 240; i++) {
      if (await target('Allumez vos feux').count()) break;
      if (await target('Accepter').count()) await tap('Accepter').catch(() => {});
      await page.waitForTimeout(500);
    }
    await shot('30-chauffeur-feux-detresse', 300);
  });

  // Chauffeur : « Naviguer vers » le prochain passager, rester dans l'application ou ouvrir Waze.
  await step('naviguer', async () => {
    await open();
    await page.mouse.click(32, 34); // menu
    await page.waitForTimeout(1000);
    await tap('Mode chauffeur');
    await page.waitForTimeout(2500);
    await tap('Commencer le service');
    await target('Accepter').waitFor({ timeout: 40000 });
    await tap('Accepter');
    await page.waitForTimeout(1500);
    await tap('Naviguer vers');
    await target('Ouvrir dans Waze').waitFor({ timeout: 10000 });
    await shot('31-chauffeur-naviguer-waze-google', 800);
  });

  // Chauffeur qui rentre chez lui : seulement les passagers sur son trajet
  await step('ma-destination', async () => {
    await open();
    await page.mouse.click(32, 34); // menu
    await page.waitForTimeout(1000);
    await tap('Mode chauffeur');
    await page.waitForTimeout(2500);
    await tap('Je rentre chez moi');
    await shot('18-chauffeur-ma-destination', 800);
    await tap('Commencer le service');
    await shot('19-chauffeur-trajet-maison', 5000);
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
