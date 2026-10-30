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
  // Arrivé chez le passager : le chauffeur démarre la course quand il est à bord.
  await waitFor('Démarrer la course', 180);
  await shot('8b-chauffeur-demarrer-la-course', 800);
  await tap('Démarrer la course');
  await shot('8-chauffeur-passager-a-bord', 3000);

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
    // Fait défiler le panneau jusqu'au bouton « Commander » (sous les options et les réglages).
    await page.mouse.move(195, 760);
    for (let i = 0; i < 4; i++) {
      await page.mouse.wheel(0, 300);
      await page.waitForTimeout(300);
    }
    await tap('Commander');
    await page.waitForTimeout(9000);
    await fast();
    // Taxi arrivé : c'est le chauffeur qui démarre la course (simulé dans la démo).
    await waitFor('En route vers');
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
    // Taxi arrivé : c'est le chauffeur qui démarre la course (simulé dans la démo).
    await waitFor('En route vers');
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
    // Le bon du reçu est au-dessus de la note : on cherche les étoiles en faisant défiler le panneau.
    // Chaque appui est facultatif, la capture est prise quand même.
    const soft = (fn) => fn().catch((e) => console.error('notation :', e.message));
    await page.mouse.move(195, 760);
    for (const dy of [-2000, 250, 150, 150]) {
      await page.mouse.wheel(0, dy);
      await page.waitForTimeout(600);
      const ok = await target('5 étoiles sur 5')
        .click({ timeout: 3000 })
        .then(() => true)
        .catch(() => false);
      if (ok) break;
    }
    await page.waitForTimeout(600);
    await soft(() => tap('Ponctuel'));
    await soft(() => tap('Conduite prudente'));
    await page.mouse.wheel(0, 150);
    await page.waitForTimeout(600);
    await soft(() => tap('10 DH'));
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

  // Chauffeur en service (ou avec un passager pris dans la rue) : il dit le quartier où il va,
  // ou le touche dans la liste si le micro n'est pas disponible ; seulement les passagers sur la route.
  await step('quartier-vocal', async () => {
    await open();
    await page.mouse.click(32, 34); // menu
    await page.waitForTimeout(1000);
    await tap('Mode chauffeur');
    await page.waitForTimeout(2500);
    await tap('Commencer le service');
    await page.waitForTimeout(800);
    await tap('Dire mon quartier');
    await target('Ou touchez le quartier').waitFor({ timeout: 10000 });
    await shot('32-chauffeur-quartier-vocal', 2000);
    await tap('Maârif');
    await shot('33-chauffeur-quartier-trajet', 2500);
  });

  // Prix « Seul » : seulement le prix total sur l'option (pas de détail).
  await step('prix-seul', async () => {
    await open();
    await tap('Gare Casa Voyageurs');
    await shot('38-prix-seul', 4000);
  });

  // Prix premium : prix « Seul » + 10 MAD, total seulement, avec ce que comprend le premium.
  await step('prix-premium', async () => {
    await open();
    await tap('Gare Casa Voyageurs');
    await page.waitForTimeout(3500);
    await tap('Taxi premium');
    await page.waitForTimeout(800);
    await page.mouse.move(195, 760);
    await page.mouse.wheel(0, 200);
    await shot('39-prix-premium', 1500);
  });

  // Chauffeur : « Devenir chauffeur Premium » (réglages chauffeur) et ses critères.
  await step('criteres-premium', async () => {
    await open();
    await page.mouse.click(32, 34); // menu
    await page.waitForTimeout(1000);
    await tap('Mode chauffeur');
    await page.waitForTimeout(2500);
    await tap('Réglages chauffeur');
    await page.waitForTimeout(1200);
    await tap('Devenir chauffeur Premium');
    await shot('40-criteres-premium', 2000);
  });

  // Chauffeur : « Mes gains », ce que Bab Taxi rapporte en plus par rapport à avant.
  await step('mes-gains', async () => {
    await open();
    await page.mouse.click(32, 34); // menu
    await page.waitForTimeout(1000);
    await tap('Mode chauffeur');
    await shot('48-chauffeur-gains-de-la-semaine', 2500);
    await tap('cette semaine avec Bab Taxi');
    await shot('49-mes-gains-semaine', 2000);
    await page.mouse.move(195, 500);
    await page.mouse.wheel(0, 700);
    await shot('50-mes-gains-historique', 1200);
    await page.mouse.wheel(0, -1400);
    await page.waitForTimeout(600);
    await page.mouse.click(285, 76); // « Mois »
    await shot('51-mes-gains-mois', 1500);
  });

  // Publicités (annonceurs fictifs, « exemple fictif ») : les six emplacements.
  // Bannière d'accueil : logo, titre court et bon de réduction.
  await step('pub-accueil', async () => {
    await open();
    await shot('41-pub-banniere-accueil', 1500);
  });

  // Destination sponsorisée parmi les premières suggestions de la recherche.
  await step('pub-destination', async () => {
    await open();
    await tap('Rechercher une destination');
    await shot('42-pub-destination-sponsorisee', 2000);
  });

  // Écran d'attente : carte pendant la recherche d'un chauffeur.
  await step('pub-attente', async () => {
    await open();
    await tap('Gare Casa Voyageurs');
    await page.waitForTimeout(3500);
    await page.mouse.move(195, 760);
    for (let i = 0; i < 4; i++) {
      await page.mouse.wheel(0, 300);
      await page.waitForTimeout(300);
    }
    await tap('Commander');
    await page.waitForTimeout(600);
    await page.mouse.move(195, 760);
    await page.mouse.wheel(0, 600);
    await shot('43-pub-ecran-attente', 600);
  });

  // Carte en course (logo, offre, QR code), lieu mis en avant parmi les restaurants, bon sur le reçu.
  await step('pub-course-recu', async () => {
    await open();
    await tap('Gare Casa Voyageurs');
    await page.waitForTimeout(3500);
    await tap('Commander');
    await page.waitForTimeout(9000);
    await fast();
    // Taxi arrivé : c'est le chauffeur qui démarre la course (simulé dans la démo).
    await waitFor('En route vers');
    await page.waitForTimeout(1500);
    await page.mouse.move(195, 760);
    for (let i = 0; i < 4; i++) {
      await page.mouse.wheel(0, 300);
      await page.waitForTimeout(300);
    }
    await shot('44-pub-carte-en-course', 1200);
    for (let i = 0; i < 4; i++) {
      await page.mouse.wheel(0, 300);
      await page.waitForTimeout(300);
    }
    await shot('45-pub-lieu-sponsorise', 1200);
    await fast();
    await waitFor('5 étoiles sur 5', 240);
    await page.waitForTimeout(1500);
    await page.mouse.move(195, 760);
    await page.mouse.wheel(0, 250);
    await shot('46-pub-bon-sur-recu', 1500);
    await tap('Bon ajouté');
    await shot('47-pub-bon-qr-code', 2000);
  });

  // Restaurants : « Réserver une table » (date, heure, personnes, nom prérempli), puis « Table réservée ».
  await step('reservation-restaurant', async () => {
    await open();
    await tap('Gare Casa Voyageurs');
    await page.waitForTimeout(3500);
    await tap('Commander');
    await page.waitForTimeout(9000);
    await page.mouse.move(195, 760);
    for (let i = 0; i < 6; i++) {
      await page.mouse.wheel(0, 300);
      await page.waitForTimeout(300);
    }
    await tap('Réserver une table');
    await shot('36-reservation-restaurant', 2000);
    await tap('Confirmer la réservation');
    await shot('37-table-reservee', 2000);
  });

  // Jeux pendant le trajet (passager à bord) : cadeau d'un partenaire fictif enregistré dans « Mes offres ».
  await step('jeux', async () => {
    await open();
    await tap('Gare Casa Voyageurs');
    await page.waitForTimeout(3500);
    await tap('Commander');
    await page.waitForTimeout(9000);
    await fast();
    // Taxi arrivé : c'est le chauffeur qui démarre la course (simulé dans la démo).
    await waitFor('En route vers');
    await page.waitForTimeout(2000);
    await page.mouse.move(195, 760);
    for (let i = 0; i < 3; i++) {
      await page.mouse.wheel(0, 300);
      await page.waitForTimeout(300);
    }
    await tap('Jouer pendant le trajet');
    await shot('34-jeu-pendant-trajet', 2000);
    await tap('Grattez et gagnez');
    await page.waitForTimeout(1500);
    await tap('Tout gratter');
    await shot('35-jeu-gagne-cadeau', 3000);
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

  // Parcours 100 % vocal : chaque question est lue à voix haute ; ici, les réponses sont touchées.
  // Le panneau entier se touche pour parler : « force » clique la réponse elle-même.
  await step('vocal', async () => {
    await open();
    await shot('52-vocal-bouton-accueil', 800);
    await tap('Commander à la voix');
    await shot('53-vocal-ou-allez-vous', 4000);
    const answer = (label) => target(label).click({ timeout: 15000, force: true });
    await answer('Maison');
    await shot('54-vocal-confirmation-destination', 3000);
    await answer('Oui');
    await shot('55-vocal-choix-du-taxi', 5000);
    await answer('Petit taxi seul');
    await page.waitForTimeout(2500);
    await answer('Espèces');
    await shot('56-vocal-resume-commande', 3000);
    await answer('Oui');
    await shot('57-vocal-recherche', 3000);
    await waitFor('Où est mon taxi', 40);
    await shot('58-vocal-taxi-en-approche', 2000);
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
