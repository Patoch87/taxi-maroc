// Serveur Bab Taxi de démonstration pour filmer la console de commande (/admin).
// Lance le vrai serveur (backend/dist, compilé avec « npm run build ») en mémoire, sans base, puis le remplit
// de données d'exemple FICTIVES : chauffeurs, passagers, courses des 90 derniers jours, plaintes, une alerte SOS
// terminée, et des taxis qui roulent dans Casablanca (positions envoyées toutes les 2 s).
// Usage (depuis backend/) : PORT=3300 BAB_ADMIN_TOKEN=demo node ../.github/demo/console/serveur-demo.js
const path = require('path');
// Modules du serveur (node_modules de backend/).
const req = require('module').createRequire(path.resolve(__dirname, '../../../backend/package.json'));
req('reflect-metadata');
const dist = (p) => req(path.resolve(__dirname, '../../../backend/dist', p));
const { NestFactory } = req('@nestjs/core');
const { AppModule } = dist('app.module');
const { configureApp } = dist('setup');
const { StoreService } = dist('store/store.service');
const { RidesService } = dist('rides/rides.service');
const { alertesSos } = dist('sos/sos.controller');

// Tirage pseudo-aléatoire reproductible.
let graine = 20261103;
const alea = () => ((graine = (graine * 1103515245 + 12345) % 2147483648) / 2147483648);
const choix = (l) => l[Math.floor(alea() * l.length)];
const entre = (a, b) => a + alea() * (b - a);
const uuid = () => require('crypto').randomUUID();
const _uuidAncien = () =>
  'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = Math.floor(alea() * 16);
    return (c === 'x' ? r : (r & 3) | 8).toString(16);
  });
const JOUR = 86400000;
const iso = (t) => new Date(t).toISOString();

const PRENOMS_H = ['Hamid', 'Youssef', 'Mohamed', 'Rachid', 'Abdelilah', 'Said', 'Karim', 'Mustapha', 'Hicham', 'Omar', 'Brahim', 'Aziz', 'Khalid', 'Noureddine', 'Jamal', 'Driss', 'Mehdi', 'Adil', 'Hassan', 'Tarik'];
const PRENOMS_F = ['Salma', 'Fatima Zahra', 'Khadija', 'Imane', 'Nadia', 'Sara', 'Meryem', 'Houda', 'Loubna', 'Asmae', 'Zineb', 'Ghita', 'Hajar', 'Samira', 'Najat'];
const NOMS = ['Benali', 'El Idrissi', 'Bennani', 'Alami', 'Tazi', 'Berrada', 'Chraibi', 'El Fassi', 'Ouazzani', 'Lahlou', 'Amrani', 'Saidi', 'Ziani', 'Kettani', 'Naciri', 'Bouzid', 'Hajji', 'Mernissi', 'Rami', 'Filali'];
// Lieux de Casablanca (nom, lat, lng).
const LIEUX = [
  ['Gare Casa Voyageurs', 33.5897, -7.5906], ['Maârif', 33.5822, -7.6325], ['Morocco Mall', 33.5765, -7.7069],
  ['Twin Center', 33.5867, -7.6328], ['Ain Diab', 33.5945, -7.6875], ['Derb Sultan', 33.5732, -7.6012],
  ['Hay Hassani', 33.5615, -7.6748], ['Sidi Maârouf', 33.5317, -7.6538], ['Mosquée Hassan II', 33.6083, -7.6328],
  ['Gauthier', 33.5928, -7.6262], ['Bourgogne', 33.5986, -7.6404], ['Oasis', 33.5541, -7.6274],
  ['Casa Port', 33.6006, -7.6118], ['Ain Sebaa', 33.6055, -7.5386], ['Hay Mohammadi', 33.5918, -7.5617],
  ['Californie', 33.5432, -7.6267], ['CFC Anfa', 33.5689, -7.6563], ['Place des Nations Unies', 33.5958, -7.6185],
  ['Belvédère', 33.5967, -7.5822], ['Sidi Moumen', 33.5762, -7.5149],
];
const MOTIFS = [
  ['Chauffeur en retard', 'Le chauffeur a mis 15 minutes de plus que prévu.'],
  ['Comportement', 'Le chauffeur téléphonait en conduisant.'],
  ['Prix', 'Le compteur affichait plus que la fourchette annoncée.'],
  ['Objet oublié', "J'ai oublié un sac noir sur la banquette arrière."],
  ['Propreté', 'Le taxi était sale à l’intérieur.'],
  ['Itinéraire', 'Le chauffeur a fait un détour.'],
];

// Pièce du dossier : image SVG « spécimen » (aucune vraie pièce d'identité).
const piece = (titre, nom, couleur) =>
  Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="640" height="400" viewBox="0 0 640 400">
<rect width="640" height="400" rx="24" fill="${couleur}"/><rect x="24" y="24" width="592" height="352" rx="16" fill="#fff" opacity=".92"/>
<rect x="48" y="96" width="150" height="190" rx="10" fill="#d9d2c3"/><circle cx="123" cy="160" r="38" fill="#b9ae98"/>
<path d="M63 280c8-50 112-50 120 0z" fill="#b9ae98"/>
<text x="48" y="70" font-family="Arial" font-size="26" font-weight="700" fill="#14213d">${titre}</text>
<text x="228" y="130" font-family="Arial" font-size="22" fill="#14213d">${nom}</text>
<rect x="228" y="160" width="300" height="14" rx="7" fill="#e5dac2"/><rect x="228" y="190" width="240" height="14" rx="7" fill="#e5dac2"/>
<rect x="228" y="220" width="270" height="14" rx="7" fill="#e5dac2"/>
<text x="320" y="360" font-family="Arial" font-size="40" font-weight="700" fill="#c1272d" opacity=".35" text-anchor="middle" transform="rotate(-12 320 330)">SPÉCIMEN · DÉMO</text>
</svg>`);

(async () => {
  const app = await NestFactory.create(AppModule, { rawBody: true, logger: ['error', 'warn'] });
  configureApp(app);
  await app.init();
  const store = app.get(StoreService);
  const rides = app.get(RidesService);
  const now = Date.now();

  // ---------- Chauffeurs ----------
  const chauffeurs = [];
  const statuts = [...Array(52).fill('valide'), ...Array(5).fill('en_attente'), 'suspendu', 'suspendu', 'refuse'];
  for (let i = 0; i < statuts.length; i++) {
    const id = `ch-${uuid()}`;
    const prenom = i === 0 ? 'Hamid' : choix(PRENOMS_H);
    const nom = i === 0 ? 'Benali' : choix(NOMS);
    const grand = alea() < 0.18;
    const pieces = {};
    for (const [p, t, c] of [
      ['photo', 'Photo du chauffeur', '#e3f0e8'], ['cinRecto', 'Carte nationale (recto)', '#d8e6f3'],
      ['cinVerso', 'Carte nationale (verso)', '#d8e6f3'], ['permis', 'Permis de conduire', '#f3e1d8'],
      ['cartePro', 'Carte professionnelle taxi', '#f2e6c4'], ['casier', 'Extrait de casier judiciaire', '#ece9e2'],
      ['vehicule', 'Photo du taxi', '#fbeaea'],
    ]) {
      const fid = `f-${uuid()}`;
      await store.putFichier(fid, 'image/svg+xml', piece(t, `${prenom} ${nom}`, c));
      pieces[p] = fid;
    }
    const envoye = now - (statuts[i] === 'en_attente' ? entre(0.05, 2) : entre(10, 80)) * JOUR;
    const d = {
      id, prenom, nom,
      telephone: `2126000${String(10000 + Math.floor(alea() * 89999))}`,
      ville: 'Casablanca',
      cin: `${choix(['BE', 'BK', 'BH', 'BJ'])}${100000 + Math.floor(alea() * 899999)}`,
      permis: `${10 + Math.floor(alea() * 80)}/${100000 + Math.floor(alea() * 899999)}`,
      cartePro: `CP-${20000 + Math.floor(alea() * 70000)}`,
      taxiType: grand ? 'grand' : 'petit',
      taxiNumero: String(grand ? 100 + Math.floor(alea() * 800) : 1000 + Math.floor(alea() * 8000)),
      plaque: `${10000 + Math.floor(alea() * 89999)}-${choix(['أ', 'ب', 'د', 'هـ'])}-${choix([1, 6, 41, 53])}`,
      langues: choix([['ar', 'fr'], ['ar', 'fr', 'en'], ['ar', 'fr', 'es'], ['ar', 'zgh', 'fr']]),
      pieces, statut: statuts[i],
      motif: statuts[i] === 'refuse' ? 'Carte professionnelle expirée' : statuts[i] === 'suspendu' ? 'Plaintes répétées, en cours de vérification' : undefined,
      envoyeLe: iso(envoye),
      decideLe: statuts[i] === 'en_attente' ? undefined : iso(envoye + 0.5 * JOUR),
    };
    store.put('chauffeurs', id, d);
    store.put('comptes', id, { id, telephone: d.telephone, prenom, nom, verifie: true, creeLe: d.envoyeLe, majLe: d.envoyeLe });
    chauffeurs.push(d);
  }
  const valides = chauffeurs.filter((c) => c.statut === 'valide');

  // ---------- Passagers ----------
  const passagers = [];
  for (let i = 0; i < 640; i++) {
    const f = alea() < 0.55;
    const id = `p-${uuid()}`;
    const cree = now - Math.pow(alea(), 0.6) * 90 * JOUR;
    const c = {
      id,
      telephone: `2126000${String(10000 + Math.floor(alea() * 89999))}`,
      prenom: i === 0 ? 'Salma' : choix(f ? PRENOMS_F : PRENOMS_H),
      nom: choix(NOMS),
      nationalite: alea() < 0.9 ? 'MA' : choix(['FR', 'ES', 'GB', 'US', 'SN']),
      langue: choix(['fr', 'fr', 'ar', 'ar', 'en']),
      verifie: true,
      bloque: i === 7 ? true : undefined,
      motifBlocage: i === 7 ? 'Courses annulées à répétition' : undefined,
      creeLe: iso(cree), majLe: iso(cree),
    };
    store.put('comptes', id, c);
    passagers.push(c);
  }

  // ---------- Courses des 90 derniers jours (montée progressive) ----------
  const proches = (p, r) => ({ lat: p.lat + entre(-r, r), lng: p.lng + entre(-r, r) });
  const point = (l) => ({ lat: l[1], lng: l[2] });
  let nCourses = 0;
  for (let j = 90; j >= 0; j--) {
    const jour = now - j * JOUR;
    const parJour = Math.round(18 + (90 - j) * 1.9 + entre(-8, 8));
    for (let k = 0; k < parJour; k++) {
      // Heures de pointe : 8-9 h, 12-14 h, 18-20 h.
      const h = choix([7, 8, 8, 9, 10, 11, 12, 13, 13, 14, 15, 16, 17, 18, 18, 19, 19, 20, 21, 22, 23]);
      const debutJour = new Date(new Date(jour).toISOString().slice(0, 10) + 'T00:00:00Z').getTime();
      const t = debutJour + (h - 1) * 3600000 + entre(0, 3600000);
      if (t > now - 20 * 60000) continue;
      const a = choix(LIEUX);
      let b = choix(LIEUX);
      while (b === a) b = choix(LIEUX);
      const mode = alea() < 0.62 ? 'partage' : 'seul';
      const p = choix(passagers.filter((x) => Date.parse(x.creeLe) <= t)) || passagers[0];
      const wa = alea() < (j < 10 ? 0.22 : 0.08);
      const ch = choix(valides);
      const r = alea();
      const statut = r < 0.84 ? 'terminee' : r < 0.93 ? 'annulee' : 'expiree';
      const accepte = t + entre(0.4, 3.5) * 60000;
      const bord = accepte + entre(3, 9) * 60000;
      const prix = Math.round(mode === 'partage' ? entre(12, 28) : entre(28, 62));
      const d = {
        id: uuid(),
        demande: {
          depart: proches(point(a), 0.004), destination: proches(point(b), 0.004), mode, passagers: alea() < 0.8 ? 1 : 2,
          passager: { nom: `${p.prenom} ${p.nom[0]}.`, id: wa ? undefined : p.id, telephone: p.telephone },
          source: wa ? 'whatsapp' : 'app', destinationNom: b[0], prixMad: prix,
        },
        proposeeA: [{ taxiId: ch.id, ecartDepartM: 120, ecartDestinationM: 300, distanceAvantPriseEnChargeM: 900 }],
        statut, creeLe: iso(t), refuseePar: [],
        accepteePar: statut === 'expiree' ? undefined : ch.id,
        accepteeLe: statut === 'expiree' ? undefined : iso(accepte),
        aBordLe: statut === 'terminee' ? iso(bord) : undefined,
        termineeLe: statut === 'terminee' ? iso(bord + entre(9, 32) * 60000) : undefined,
        annuleeLe: statut === 'annulee' ? iso(accepte + 60000) : undefined,
      };
      store.put('courses', d.id, d);
      nCourses++;
    }
  }

  // ---------- Plaintes et SOS ----------
  for (let i = 0; i < 9; i++) {
    const [motif, message] = MOTIFS[i % MOTIFS.length];
    const creeLe = iso(now - entre(0.02, 12) * JOUR);
    store.put('plaintes', `pl-${i}`, {
      id: `pl-${i}`, taxiId: choix(valides).id, motif, message,
      statut: i < 3 ? 'recue' : i < 5 ? 'en_cours' : 'traitee', creeLe,
      reponse: i >= 5 ? 'Chauffeur contacté, passager remboursé de la différence.' : undefined,
      traiteeLe: i >= 5 ? iso(Date.parse(creeLe) + JOUR) : undefined,
    });
  }
  alertesSos.set('sos-demo', {
    id: 'sos-demo', nom: 'Khadija A.', taxiId: valides[3].id, statut: 'terminee',
    creeLe: iso(now - 2 * JOUR), termineeLe: iso(now - 2 * JOUR + 6 * 60000),
    positions: [{ lat: 33.5822, lng: -7.6325, a: iso(now - 2 * JOUR) }], segments: [],
  });

  // ---------- Taxis en ligne et courses en cours ----------
  // Chaque taxi roule en ligne droite d'un lieu à l'autre (10 m/s), puis repart vers un autre lieu.
  const enLigne = valides.slice(0, 38).map((c) => {
    const a = point(choix(LIEUX));
    return { c, pos: proches(a, 0.01), cible: proches(point(choix(LIEUX)), 0.006), passagers: alea() < 0.45 ? 1 + Math.floor(alea() * 2) : 0 };
  });
  const enCours = [];
  for (let i = 0; i < 7; i++) {
    const tx = enLigne[i];
    const p = passagers[i + 1];
    const statut = i < 2 ? 'en_attente' : i < 4 ? 'acceptee' : 'a_bord';
    const b = choix(LIEUX);
    const d = {
      id: uuid(),
      demande: {
        depart: { ...tx.pos }, destination: point(b), mode: i % 3 ? 'partage' : 'seul', passagers: 1,
        passager: { nom: `${p.prenom} ${p.nom[0]}.`, id: i === 5 ? undefined : p.id, telephone: p.telephone },
        source: i === 5 ? 'whatsapp' : 'app', destinationNom: b[0], prixMad: Math.round(entre(15, 45)),
      },
      proposeeA: [{ taxiId: tx.c.id, ecartDepartM: 80, ecartDestinationM: 200, distanceAvantPriseEnChargeM: 700 }],
      statut, creeLe: iso(now - entre(1, 9) * 60000), refuseePar: [],
      accepteePar: statut === 'en_attente' ? undefined : tx.c.id,
      accepteeLe: statut === 'en_attente' ? undefined : iso(now - 60000),
      aBordLe: statut === 'a_bord' ? iso(now - 30000) : undefined,
    };
    store.put('courses', d.id, d);
    enCours.push(d);
  }
  const bouger = () => {
    for (const t of enLigne) {
      const dLat = t.cible.lat - t.pos.lat,
        dLng = t.cible.lng - t.pos.lng;
      const dist = Math.hypot(dLat * 111000, dLng * 93000);
      if (dist < 40) t.cible = proches(point(choix(LIEUX)), 0.006);
      else {
        const pas = Math.min(1, 22 / dist);
        t.pos = { lat: t.pos.lat + dLat * pas, lng: t.pos.lng + dLng * pas };
      }
      rides.updateTaxi({
        id: t.c.id, type: t.c.taxiType, categorie: 'standard', itineraire: [t.pos, t.cible],
        passagersABord: t.passagers, reserveSeul: false, nom: `${t.c.prenom} ${t.c.nom}`,
        plaque: t.c.plaque, langues: t.c.langues, position: t.pos,
      });
    }
  };
  bouger();
  setInterval(bouger, 2000);

  await app.listen(process.env.PORT ?? 3300);
  console.log(`serveur de démonstration prêt : ${chauffeurs.length} chauffeurs, ${passagers.length} passagers, ${nCourses} courses, ${enLigne.length} taxis en ligne`);
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
