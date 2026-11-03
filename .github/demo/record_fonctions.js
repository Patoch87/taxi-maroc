// Vidéos « une fonctionnalité = une vidéo » de l'application Bab Taxi (version web, écran de Samsung 412 x 820).
// Usage : node record_fonctions.js <application web> <dossier de sortie> [scénario ...]
//   Variables : APP_CHAUFFEUR = adresse de la version « Bab Taxi Chauffeur » (inscription du chauffeur).
// Chaque scénario écrit <sortie>/<scénario>/frames + marks.json (titre, légendes, passages coupés) pour
// compose_fonction.py. Chaque étape vérifie que l'écran attendu est affiché, sinon le scénario échoue
// (capture echec-<scénario>.png) et les autres continuent.
const { chromium } = require('playwright');
const path = require('path');
const { demarrer, pointeur } = require('./enregistreur');

const [url, out, ...seuls] = process.argv.slice(2);
const APP_CHAUFFEUR = process.env.APP_CHAUFFEUR || '';
const VIEW = { width: 412, height: 820 };
// Densité 2 (824 x 1640) : l'écran est affiché sur 736 points de large au montage, et les captures sont plus rapides.
const DPR = 2;
// Caméra simulée pour le SOS (vidéo de l'intérieur du taxi, .y4m) : FAUSSE_CAMERA.
const CAMERA = process.env.FAUSSE_CAMERA;

// Outils communs (repris de record.js) liés à une page et à un enregistrement.
function outils(page, r, out, nom) {
  const wait = (ms) => page.waitForTimeout(ms);
  const target = (label) =>
    page
      .locator(
        `[role][aria-label*="${label}"], input[aria-label*="${label}"], textarea[aria-label*="${label}"], ` +
          `flt-semantics[role]:has-text("${label}")`,
      )
      .last();
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
  const scrollPanel = async (dy, times = 4) => {
    await page.mouse.move(VIEW.width / 2, VIEW.height - 80);
    for (let i = 0; i < times; i++) {
      await page.mouse.wheel(0, dy);
      await wait(250);
    }
  };
  const tap = async (label, timeout = 15000) => {
    const el = target(label);
    await el.waitFor({ state: 'attached', timeout });
    for (let i = 0; i < 8; i++) {
      const b = await el.boundingBox();
      if (!b) break;
      const cy = b.y + b.height / 2;
      if (cy > VIEW.height - 8) await scrollPanel(120, 1);
      else if (cy < 8) await scrollPanel(-120, 1);
      else {
        await page.mouse.move(b.x + b.width / 2, cy);
        await page.mouse.down();
        await wait(90);
        return page.mouse.up();
      }
      await wait(350);
    }
    await el.click({ timeout, force: true });
  };
  const semantics = async () => {
    await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
    await wait(800);
  };
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
      await page.screenshot({ path: path.join(out, `echec-${nom}.png`) }).catch(() => {});
      const labels = await page
        .evaluate(() =>
          [...document.querySelectorAll('flt-semantics')]
            .filter((e) => !e.querySelector('flt-semantics'))
            .map((e) => e.getAttribute('aria-label') || e.textContent)
            .filter(Boolean)
            .slice(0, 60),
        )
        .catch(() => []);
      throw new Error(`${nom}, étape « ${step} » : « ${text} » n'apparaît pas. Écran : ${JSON.stringify(labels)}`);
    }
  };
  const tapFor = async (step, label, text, maxSec = 10) => {
    for (let i = 0; i < 3; i++) {
      await tap(label).catch(() => {});
      if (await waitFor(text, maxSec / 3)) return;
      await semantics();
    }
    await expectScreen(step, text, 1);
  };
  const fill = async (label, text, delay = 80) => {
    await tap(label);
    await wait(400);
    await page.keyboard.type(text, { delay });
    await wait(400);
  };
  // Réponse du parcours vocal (cases à cocher, sans micro dans le navigateur).
  const answer = (label) => target(label).click({ timeout: 15000, force: true });
  // Commande rapide (coupée au montage) jusqu'au chauffeur trouvé.
  const commanderVite = async (recherche = 'mall', lieu = 'Morocco Mall') => {
    r.skip(true);
    await tap('Rechercher une destination');
    await wait(1000);
    await page.keyboard.type(recherche, { delay: 60 });
    await expectScreen('recherche', lieu);
    await tap(lieu);
    await expectScreen('offres', 'Commander');
    await wait(600);
    await tap('Commander');
    await expectScreen('chauffeur trouvé', 'Votre taxi arrive', 60);
    await wait(2000);
    r.skip(false);
  };
  return { wait, target, present, tap, tapFor, semantics, waitFor, expectScreen, fill, scrollPanel, answer, commanderVite };
}

// ------------------------------------------------------------------ scénarios
// Chaque scénario : { titre, sousTitre, fin, adresse (paramètres de l'application), joue(o, r, page) }.
const SCENARIOS = {
  // ---------------- Passagers
  'p1-commander': {
    titre: 'Commander un taxi',
    sousTitre: 'Prix affiché avant de monter, chauffeur identifié',
    fin: 'Le prix officiel, sans négociation',
    async joue(o, r) {
      r.caption('Où allez-vous ? On cherche sa destination');
      await o.wait(1200);
      await o.tap('Rechercher une destination');
      await o.wait(1000);
      await o.page.keyboard.type('mall', { delay: 120 });
      await o.expectScreen('recherche', 'Morocco Mall');
      await o.wait(600);
      await o.tap('Morocco Mall');
      await o.expectScreen('offres', 'Commander');
      r.caption('Trois offres, avec le prix affiché avant de commander');
      await o.wait(3500);
      r.caption('Partagé : avec des passagers sur votre route, le moins cher');
      await o.wait(3000);
      r.caption('Seul ou Premium : le taxi rien que pour vous');
      await o.wait(3000);
      r.caption('Valises, siège bébé, nombre de personnes : tout se règle ici');
      await o.tap('Une valise de plus');
      await o.wait(700);
      await o.tap('Siège bébé');
      await o.wait(1600);
      await o.tap('Commander');
      r.caption('La demande part aux taxis sur votre route : le premier qui accepte l’emporte');
      await o.expectScreen('chauffeur trouvé', 'Votre taxi arrive', 60);
      await o.wait(2500);
      r.caption('Votre chauffeur : photo, note, langues parlées, plaque et numéro du taxi');
      await o.wait(5000);
      r.caption('Le compte à rebours de son arrivée, en direct');
      await o.wait(3500);
      r.caption(null);
      r.skip(true);
      await o.expectScreen('arrivée du taxi', 'Montez à bord', 300);
      r.skip(false);
      r.caption('Le taxi est là : vous montez, le chauffeur démarre la course');
      await o.wait(4000);
      r.skip(true);
      await o.expectScreen('course démarrée', 'Arrivée vers', 60);
      await o.wait(1200);
      r.skip(false);
      r.caption('La course est suivie en direct jusqu’à votre arrivée');
      await o.wait(4500);
    },
  },

  'p2-vocal': {
    titre: 'Commander à la voix',
    sousTitre: 'Sans rien taper : pour tous, et pour les malvoyants',
    fin: 'Bab Taxi vous parle, vous répondez',
    async joue(o, r) {
      r.caption('Un bouton : « Commander à la voix »');
      await o.wait(1500);
      await o.tap('Commander à la voix');
      await o.expectScreen('vocal : destination', 'Où voulez-vous aller', 20);
      r.caption('Bab Taxi demande où vous allez. Vous le dites, ou vous touchez une réponse');
      await o.wait(4000);
      await o.answer('Maison');
      await o.expectScreen('vocal : offres', 'Petit taxi seul', 20);
      r.caption('Il annonce la distance, la durée et le prix de chaque taxi');
      await o.wait(5000);
      await o.answer('Petit taxi ·');
      await o.expectScreen('vocal : paiement', 'Espèces', 15);
      r.caption('Espèces ou carte');
      await o.wait(3000);
      await o.answer('Espèces');
      await o.expectScreen('vocal : résumé', 'Je résume', 15);
      r.caption('Il résume la commande, vous confirmez d’un « oui »');
      await o.wait(4500);
      await o.answer('Oui');
      r.caption(null);
      r.skip(true);
      await o.expectScreen('vocal : taxi trouvé', 'Où est mon taxi', 60);
      await o.wait(1500);
      r.skip(false);
      r.caption('Le taxi arrive. À tout moment : « où est mon taxi ? », appeler, partager, SOS');
      await o.wait(6000);
    },
  },

  'p3-destination': {
    titre: 'Changer de destination',
    sousTitre: 'Pendant la course, en deux touches',
    fin: 'Le chauffeur est prévenu aussitôt',
    async joue(o, r) {
      await o.commanderVite();
      r.caption('Votre taxi arrive vers le Morocco Mall… mais vos plans changent');
      await o.wait(3500);
      r.caption('« Changer de destination »');
      await o.tap('Changer de destination');
      await o.expectScreen('nouvelle destination', 'Twin Center', 15);
      await o.wait(1500);
      await o.tap('Twin Center, Maârif');
      await o.expectScreen('confirmation', 'Nouveau prix', 15);
      r.caption('Nouveau prix et nouvelle heure d’arrivée, avant de confirmer');
      await o.wait(5000);
      await o.tap('Confirmer');
      r.caption('C’est envoyé : le chauffeur reçoit la nouvelle destination');
      await o.wait(4500);
      r.caption('Le trajet et le prix sont mis à jour');
      await o.wait(3500);
    },
  },

  'p4-securite': {
    titre: 'Sécurité et SOS',
    sousTitre: 'Partage du trajet, numéros d’urgence, SOS filmé',
    fin: 'Chaque course est suivie',
    async joue(o, r) {
      await o.commanderVite();
      r.caption('Le bouclier : tout ce qui protège le passager');
      await o.wait(2000);
      await o.tap('Sécurité');
      await o.expectScreen('sécurité', 'Numéros d', 10);
      r.caption('Contacts de confiance et partage de la course en direct');
      await o.wait(4000);
      r.caption('Police, gendarmerie, protection civile : un appui');
      await o.wait(3500);
      r.caption('En danger ? SOS');
      await o.wait(1500);
      await o.tap('SOS SOS urgence');
      await o.expectScreen('SOS', 'EN DIRECT', 15);
      r.caption('La caméra filme et envoie en direct la vidéo, le son et la position');
      await o.wait(5000);
      r.caption('Le centre de sécurité Bab Taxi reçoit l’alerte et peut prévenir la police');
      await o.wait(4500);
      r.caption('Un geste aussi pour prévenir ses proches');
      await o.wait(3000);
      await o.tap('Je suis en sécurité');
      await o.wait(1500);
    },
  },

  'p5-fin-de-course': {
    titre: 'Fin de course',
    sousTitre: 'Noter le chauffeur, laisser un pourboire',
    fin: 'Les meilleurs chauffeurs sont récompensés',
    async joue(o, r) {
      await o.commanderVite();
      r.skip(true);
      await o.expectScreen('arrivée', '5 étoiles sur 5', 900);
      await o.wait(1000);
      r.skip(false);
      r.caption('Arrivé à destination : on note le chauffeur');
      await o.wait(2000);
      await o.tap('5 étoiles sur 5');
      await o.wait(800);
      await o.tap('Ponctuel').catch(() => {});
      await o.wait(500);
      await o.tap('Conduite prudente').catch(() => {});
      r.caption('Ce qui vous a plu, en un geste');
      await o.wait(2000);
      r.caption('Un commentaire, et un pourboire si vous le souhaitez');
      await o.fill('Un commentaire', 'Très bon chauffeur, merci !', 60);
      await o.wait(500);
      await o.tap('10 DH');
      await o.wait(2000);
      await o.tapFor('envoi', 'Envoyer', 'Payer', 10).catch(async () => {
        await o.expectScreen('merci', 'Merci', 10);
      });
      if (await o.present('Payer')) {
        await o.wait(1200);
        await o.tapFor('paiement', 'Payer', 'Merci', 15);
      }
      r.caption('Le pourboire va entièrement au chauffeur. Merci !');
      await o.wait(3500);
    },
  },

  'p6-proche-plus-tard': {
    titre: 'Pour un proche, ou pour plus tard',
    sousTitre: 'Commander pour quelqu’un d’autre, réserver à l’avance',
    fin: 'Le taxi qui vous arrange',
    async joue(o, r) {
      r.skip(true);
      await o.tap('Rechercher une destination');
      await o.wait(1000);
      await o.page.keyboard.type('mall', { delay: 60 });
      await o.expectScreen('recherche', 'Morocco Mall');
      await o.tap('Morocco Mall');
      await o.expectScreen('offres', 'Commander');
      await o.wait(1000);
      r.skip(false);
      r.caption('Le taxi est pour quelqu’un d’autre ? Votre mère, un ami…');
      await o.wait(2000);
      await o.tap('Qui prend le taxi');
      await o.expectScreen('qui', "Pour quelqu'un d'autre", 10);
      await o.wait(800);
      await o.tap("Pour quelqu'un d'autre");
      await o.wait(1000);
      r.caption('Son nom et son téléphone : le chauffeur l’appellera, elle');
      await o.fill('Nom du passager', 'Fatima', 90);
      await o.fill('Téléphone', '600112233', 90);
      await o.wait(1000);
      await o.tap('Valider');
      await o.wait(1500);
      r.caption('Et pour plus tard ? Le jour…');
      await o.tap('Maintenant, Plus tard').catch(() => o.tap('Plus tard'));
      await o.expectScreen('date', 'Mois suivant', 10);
      await o.wait(1200);
      const demain = new Date(Date.now() + 86400000);
      const jour = demain.toLocaleDateString('fr-FR', { weekday: 'long' });
      await o.tap(`${demain.getDate()}, ${jour}`);
      await o.wait(1200);
      await o.tap('OK');
      r.caption('… et l’heure');
      await o.wait(2500);
      await o.tap('OK');
      await o.expectScreen('prévu', 'Prévu', 10);
      r.caption('Taxi réservé pour demain, pour Fatima : tout est clair avant de commander');
      await o.scrollPanel(120, 2);
      await o.wait(5000);
    },
  },

  'p7-compte': {
    titre: 'Créer son compte',
    sousTitre: 'Un numéro vérifié, et c’est prêt',
    fin: 'Un compte, sur tous vos téléphones',
    adresse: '?video=1',
    async joue(o, r) {
      await o.expectScreen('création', 'Créer un compte', 30);
      r.caption('Prénom et nom');
      await o.fill('Prénom', 'Salma', 90);
      await o.fill('Nom', 'Bennani', 90);
      r.caption('Le numéro de téléphone, vérifié par un code SMS');
      await o.fill('Numéro de téléphone', '600112233', 90);
      await o.wait(500);
      await o.tap('Recevoir le code par SMS');
      await o.expectScreen('code', 'Code reçu par SMS', 15);
      await o.wait(1200);
      await o.fill('Code reçu par SMS', '1234', 150);
      await o.expectScreen('vérifié', 'Numéro vérifié', 15);
      await o.wait(1200);
      r.caption('La nationalité choisit la langue, jamais la publicité (loi 09-08)');
      await o.tap('Nationalité');
      await o.wait(1500);
      if (await o.present('Maroc')) await o.tap('Maroc').catch(() => {});
      await o.wait(1500);
      r.caption('Un téléphone neuf ? « J’ai déjà un compte » : le numéro, le code, et c’est tout');
      await o.wait(1500);
      await o.tap("J'ai déjà un compte");
      await o.expectScreen('connexion', 'Se connecter', 10);
      await o.wait(4000);
      await o.tap('Créer un nouveau compte').catch(() => {});
      await o.wait(1200);
      r.caption(null);
      r.skip(true);
      // Retour au formulaire (déjà rempli) : on revérifie le numéro si besoin.
      if (!(await o.present('Numéro vérifié'))) {
        await o.tap('Recevoir le code par SMS');
        await o.wait(800);
        await o.fill('Code reçu par SMS', '1234', 0);
        await o.expectScreen('vérifié', 'Numéro vérifié', 15);
      }
      r.skip(false);
      r.caption('Compte créé : on peut commander');
      await o.tap('Créer un compte');
      await o.expectScreen('accueil', 'Rechercher une destination', 30);
      await o.wait(3500);
    },
  },

  // ---------------- Chauffeurs
  'c1-inscription': {
    titre: 'S’inscrire comme chauffeur',
    sousTitre: 'Le dossier complet, depuis le téléphone',
    fin: 'Des chauffeurs vérifiés, des passagers rassurés',
    application: 'chauffeur',
    adresse: '?demo=1&video=1',
    async joue(o, r) {
      const MEDIA = path.join(__dirname, 'media');
      // Pièce ajoutée « depuis la galerie » : image de démonstration (spécimen).
      const piece = async (label, fichier) => {
        await o.tap(label);
        await o.expectScreen('galerie', 'Choisir dans la galerie', 10);
        await o.wait(500);
        const [chooser] = await Promise.all([
          o.page.waitForEvent('filechooser', { timeout: 10000 }),
          o.tap('Choisir dans la galerie'),
        ]);
        await chooser.setFiles(path.join(MEDIA, fichier));
        await o.wait(1300);
      };
      await o.expectScreen('dossier', 'Remplissez votre dossier', 30);
      r.caption('L’application Bab Taxi Chauffeur : le dossier se remplit une seule fois');
      await o.wait(3000);
      r.caption('Sa photo, montrée aux passagers, et les langues qu’il parle');
      await piece('Votre photo', 'chauffeur.jpg');
      await o.tap('English').catch(() => {});
      await o.wait(1200);
      r.caption('Carte nationale, permis de conduire');
      await o.fill('Numéro de CIN', 'BE123456', 70);
      await piece('CIN : recto', 'cin-recto.jpg');
      await piece('CIN : verso', 'cin-verso.jpg');
      await o.fill('Numéro du permis', '12/345678', 70);
      await piece('Permis de conduire', 'permis.jpg');
      r.caption('Carte professionnelle et extrait de casier judiciaire');
      await o.fill('Numéro de la carte professionnelle', 'CP-48213', 70);
      await piece('Carte professionnelle', 'carte-pro.jpg');
      await piece('Casier judiciaire', 'casier.jpg');
      r.caption('Son taxi : type, numéro sur la portière, plaque et photo');
      await o.fill('Numéro du taxi', '2417', 90);
      await o.fill("Plaque d'immatriculation", '12345-A-6', 70);
      await piece('Photo du taxi', 'taxi.jpg');
      await o.wait(1000);
      r.caption('Dossier envoyé : Bab Taxi vérifie chaque pièce avant la première course');
      await o.tap('Envoyer mon dossier');
      await o.wait(5000);
    },
  },

  'c2-course': {
    modeChauffeur: true,
    titre: 'Une course, côté chauffeur',
    sousTitre: 'De la demande à la dépose du passager',
    fin: 'Plus de courses sur votre route',
    async joue(o, r) {
      r.caption('Le chauffeur choisit quand il travaille');
      await o.wait(3000);
      await o.tapFor('en ligne', 'Commencer le service', 'Disponible', 15);
      r.caption('Disponible : les demandes arrivent sur son chemin');
      await o.wait(2500);
      const hold = async (ms, still) => {
        const t = r.now();
        while (r.now() - t < ms / 1000 && (await still())) await o.wait(150);
        return r.now() - t;
      };
      let accepted = false;
      for (let attempt = 0; attempt < 6 && !accepted; attempt++) {
        r.skip(true);
        await o.expectScreen('demande de course', 'Accepter', 90);
        r.skip(false);
        const from = r.now();
        r.caption('Nouvelle demande : la destination, les places et le prix estimé. Il accepte ou refuse');
        await hold(4500, () => o.present('Accepter'));
        if (await o.present('Accepter')) {
          await o.tap('Accepter');
          accepted = true;
        } else r.cutSince(from);
      }
      if (!accepted) throw new Error('aucune demande acceptée');
      await o.expectScreen('prochains arrêts', 'Prochains arrêts', 10);
      r.caption('Le premier qui accepte a la course : le trajet vers le passager s’affiche');
      await hold(4000, async () => !(await o.present('Accepter')));
      r.caption(null);
      let hazardShown = false;
      for (let attempt = 0; attempt < 8 && !hazardShown; attempt++) {
        r.skip(true);
        let hazard = false;
        for (let i = 0; i < 600 && !hazard; i++) {
          hazard = (await o.present('Allumez vos feux')) && !(await o.present('Accepter'));
          if (!hazard && (await o.present('Refuser'))) await o.tap('Refuser').catch(() => {});
          if (!hazard) await o.wait(300);
        }
        if (!hazard) break;
        r.skip(false);
        const from = r.now();
        r.caption('À 50 m du passager : rappel des feux de détresse');
        const shown = await hold(4000, async () => (await o.present('Allumez vos feux')) && !(await o.present('Accepter')));
        if (shown >= 2.5) hazardShown = true;
        else r.cutSince(from);
      }
      r.skip(true);
      if (await o.present('Allumez vos feux')) await o.tap('OK').catch(() => {});
      r.caption(null);
      for (let i = 0; i < 600 && !(await o.present('Démarrer la course')); i++) {
        if (await o.present('Refuser')) await o.tap('Refuser').catch(() => {});
        await o.wait(300);
      }
      r.skip(false);
      await o.expectScreen('démarrer la course', 'Démarrer la course', 2);
      r.caption('Le passager est à bord : c’est le chauffeur qui démarre la course');
      await o.wait(3500);
      await o.tap('Démarrer la course');
      await o.wait(1500);
      r.skip(true);
      r.caption(null);
      let dropped = false;
      for (let i = 0; i < 600 && !dropped; i++) {
        dropped = await o.present('Passager déposé');
        if (!dropped && (await o.present('Démarrer la course'))) await o.tap('Démarrer la course').catch(() => {});
        if (!dropped && (await o.present('Refuser'))) await o.tap('Refuser').catch(() => {});
        if (!dropped) await o.wait(250);
      }
      r.skip(false);
      await o.expectScreen('dépose', 'Passager déposé', 2);
      r.caption('Arrivée : le passager est déposé, la course est enregistrée');
      await o.wait(5000);
    },
  },

  'c3-ma-destination': {
    modeChauffeur: true,
    titre: '« Je rentre chez moi »',
    sousTitre: 'Seulement les passagers sur sa route',
    fin: 'Le trajet du retour devient payant',
    async joue(o, r) {
      r.caption('Fin de journée : le chauffeur rentre chez lui');
      await o.wait(3000);
      r.caption('« Ma destination » : chez moi, ou une autre adresse');
      await o.wait(2500);
      await o.tap('Je rentre chez moi');
      await o.expectScreen('vers maison', 'Vers Maison', 10);
      r.caption('Il ne reçoit que les passagers qui vont dans sa direction');
      await o.wait(4500);
      await o.tapFor('en ligne', 'Commencer le service', 'Disponible', 15);
      r.caption('Son trajet du retour s’affiche sur la carte');
      await o.wait(4000);
      r.skip(true);
      await o.expectScreen('demande de course', 'Accepter', 120);
      r.skip(false);
      r.caption('Un passager sur sa route : une course de plus, sans détour');
      await o.wait(4500);
    },
  },

  'c4-gains': {
    modeChauffeur: true,
    titre: 'Mes gains',
    sousTitre: 'Ce que Bab Taxi rapporte en plus, chaque semaine',
    fin: 'Bab Taxi travaille pour vous',
    async joue(o, r) {
      r.caption('Toujours sous les yeux : ce que Bab Taxi lui a rapporté cette semaine');
      await o.wait(3500);
      await o.tapFor('mes gains', 'cette semaine avec Bab Taxi', 'de plus grâce à Bab Taxi', 15);
      await o.wait(800);
      r.caption('Mes gains : la semaine, comparée à avant Bab Taxi');
      await o.wait(5000);
      r.caption('D’où viennent les gains en plus');
      await o.page.mouse.move(VIEW.width / 2, VIEW.height / 2);
      for (let i = 0; i < 4; i++) {
        await o.page.mouse.wheel(0, 90);
        await o.wait(250);
      }
      await o.waitFor('Courses en plus sur votre route', 5);
      await o.wait(4000);
      r.caption('Semaine après semaine, les gains en plus montent');
      for (let i = 0; i < 4; i++) {
        await o.page.mouse.wheel(0, 110);
        await o.wait(250);
      }
      await o.wait(4000);
      r.caption(null);
      r.skip(true);
      for (let i = 0; i < 10; i++) {
        await o.page.mouse.wheel(0, -200);
        await o.wait(120);
      }
      await o.tapFor('mois', 'Mois', 'Ce mois-ci', 10);
      await o.wait(800);
      r.skip(false);
      r.caption('Le bilan du mois, et la prime qualité : meilleure est sa note, plus elle monte');
      await o.wait(5000);
      for (let i = 0; i < 4; i++) {
        await o.page.mouse.wheel(0, 120);
        await o.wait(250);
      }
      await o.wait(3500);
    },
  },
};

(async () => {
  const args = ['--use-fake-ui-for-media-stream', '--use-fake-device-for-media-stream'];
  if (CAMERA) args.push(`--use-file-for-fake-video-capture=${CAMERA}`);
  const browser = await chromium.launch({ args });
  const liste = seuls.length ? seuls : Object.keys(SCENARIOS);
  let echecs = 0;
  for (const nom of liste) {
    const sc = SCENARIOS[nom];
    if (!sc) {
      console.log(`scénario inconnu : ${nom}`);
      continue;
    }
    const base = sc.application === 'chauffeur' ? APP_CHAUFFEUR : url;
    if (!base) {
      console.log(`${nom} : pas d'application chauffeur (APP_CHAUFFEUR), scénario sauté`);
      continue;
    }
    const dossier = path.join(out, nom);
    const context = await browser.newContext({
      viewport: VIEW,
      deviceScaleFactor: DPR,
      locale: 'fr-FR',
      permissions: ['camera', 'microphone', 'geolocation'],
      geolocation: { latitude: 33.5897, longitude: -7.5906 },
    });
    await context.addInitScript(pointeur(false));
    const page = await context.newPage();
    // Chargement : hors vidéo.
    await page.goto(`${base}${sc.adresse || '?demo=1&video=1'}`, { waitUntil: 'load' });
    await page.waitForTimeout(5000);
    await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
    await page.waitForTimeout(800);
    // Vidéos chauffeur : passage en mode chauffeur avant l'enregistrement.
    if (sc.modeChauffeur) {
      const p0 = outils(page, { skip() {}, caption() {} }, out, nom);
      await p0.expectScreen('accueil', 'Rechercher une destination', 60);
      await p0.tapFor('menu', 'Ouvrir le menu de navigation', 'Mode chauffeur', 12);
      await p0.tapFor('mode chauffeur', 'Mode chauffeur', 'Commencer le service', 15);
      await page.waitForTimeout(1500);
    }
    const r = await demarrer(context, page, dossier, { view: VIEW, dpr: DPR });
    const o = { ...outils(page, r, out, nom), page };
    const t0 = Date.now();
    try {
      if (!sc.adresse && !sc.modeChauffeur) await o.expectScreen('accueil', 'Rechercher une destination', 60);
      await o.wait(800);
      await sc.joue(o, r);
      r.caption(null);
      await o.wait(800);
      await r.fin({ titre: sc.titre, sousTitre: sc.sousTitre, fin: sc.fin });
      console.log(`${nom} : ${r.marks.duration.toFixed(1)} s enregistrées en ${Math.round((Date.now() - t0) / 1000)} s, ${r.marks.frames.length} images`);
    } catch (e) {
      echecs++;
      console.log(`::error title=Démo ${nom}::${String(e.message || e).split('\n')[0].slice(0, 1500)}`);
      await page.screenshot({ path: path.join(out, `echec-${nom}.png`) }).catch(() => {});
      await r.fin().catch(() => {});
    }
    await context.close();
  }
  await browser.close();
  process.exit(echecs ? 1 : 0);
})();
