# Taxi Maroc

Application pour les **petits et grands taxis** du Maroc, pour les passagers et les chauffeurs, sur Android et iPhone. Lancement prévu à **Casablanca**.

Le plan produit complet est dans le dossier du projet : `plan/plan-application-taxi.md`.

## Contenu

| Dossier | Rôle |
|---|---|
| `backend/` | Serveur Node.js (NestJS, TypeScript) : prix, prise en charge sur la route, plaintes |
| `mobile/` | Application Flutter (Android et iPhone) : passager, chauffeur, commande vocale |

## Ce qui fonctionne déjà

- **Prise en charge sur la route** (`backend/src/domain/matching.ts`) : le passager donne sa destination finale ; seuls les taxis dont l'itinéraire passe près de lui (300 m) **et** va vers sa destination (800 m) le voient, dans le bon sens, avec des places libres.
- **Course seule ou partagée** : la course seule ne va qu'à un taxi vide et bloque les autres passagers. Prix « Seul » (application) = compteur + compensation chauffeur (places libres bloquées × 50 % du compteur, au moins 10 MAD ; 2 places pour 1 passager, 1 pour un groupe de 2, 0 pour 3) + 3 MAD de frais Bab. Les touristes paient exactement comme tout le monde.
- **Prix affiché à l'avance** (`backend/src/domain/fare.ts`) : compteur estimé, minimum, majoration de nuit +50 %, supplément seul, coefficient premium ; grand taxi au prix fixe par place.
- **Plaintes** : refus, prix abusif, conduite dangereuse, comportement, objet oublié.
- **Taxis premium** : filtre par catégorie.
- **Application mobile façon Uber** : carte plein écran de Casablanca (OpenStreetMap / CARTO), recherche de destination, choix du taxi avec prix affiché (petit taxi partagé, seul, premium, grand taxi par place ou entier), suivi du taxi qui arrive, fiche chauffeur (nom, plaque, numéro de taxi, note), SOS, plainte, reçu et note de fin de course.
- **Mode chauffeur** : carte avec sa route, passagers sur sa route proposés devant lui, accepter ou refuser en un geste, gains du jour et places occupées.
- **Premier chauffeur qui accepte** : la demande part à tous les taxis sur la route du passager ; le premier qui accepte la prend, les autres sont bloqués (serveur : `POST /rides/requests`, `POST /rides/requests/:id/accept`, réponse 409 pour les suivants).
- Compte à rebours en temps réel, partage de la course et de la position, sécurité (SOS, 19 / 177 / 15, réclamation) depuis l'écran de commande, photo du chauffeur avec les drapeaux des langues qu'il parle, messages rapides traduits en darija, adresses Maison et Travail, réservation à l'avance, espèces ou carte, pourboire, historique.
- **16 langues** : français, arabe, **darija**, anglais et les langues des pays de la Coupe du monde 2022 (espagnol, portugais, allemand, italien, néerlandais, polonais, croate, serbe en alphabet latin, danois, japonais, coréen, persan). Choix par une seule option « Langue » avec une grille de drapeaux ; arabe, darija et persan s'affichent de droite à gauche. Les textes des langues ajoutées sont dans `mobile/lib/l10n/lang/` (un fichier par langue) et **doivent être relus par des locuteurs natifs avant le lancement**.
- Français, arabe, **darija** et anglais relus ; **commande vocale** dans la recherche de destination (la destination est répétée à voix haute avant la recherche).
- Captures d'écran automatiques avec la vraie carte : branche `captures` (workflow *Captures*).
- La carte utilise des services gratuits réservés aux tests (tuiles OpenStreetMap, itinéraires OSRM) : à remplacer par un fournisseur sous contrat (Google Maps, Mapbox, MapTiler) avant le lancement.

Les tarifs dans `backend/src/domain/tariffs.ts` sont **indicatifs** et doivent être confirmés avec le tarif officiel de la wilaya de Casablanca.

## Lancer le serveur

```bash
cd backend
npm install
npm test        # 14 tests
npm run dev     # http://localhost:3000
```

Principales routes : `POST /fares/petit-taxi`, `POST /fares/grand-taxi`, `PUT /taxis/:id/route`, `POST /rides/match`, `POST /complaints`.

## Lancer l'application mobile

```bash
cd mobile
flutter pub get
flutter test
flutter run                                              # mode démo, sans serveur
flutter run --dart-define=API_URL=http://10.0.2.2:3000   # avec le serveur (émulateur Android)
```

Sans `API_URL`, l'application tourne en **mode démo** : prix calculés sur le téléphone et taxis fictifs.

## Tester sur un téléphone Android (Samsung)

À chaque envoi sur `main`, GitHub Actions fabrique le fichier **taxi-maroc.apk** et le publie ici : https://github.com/Patoch87/taxi-maroc/releases/latest/download/taxi-maroc.apk. Ouvrir ce lien sur le téléphone, ouvrir le fichier téléchargé et autoriser l'installation d'applications inconnues.

**iPhone** : le workflow « iPhone » compile l'application sur un Mac de GitHub et publie une version non signée : https://github.com/Patoch87/taxi-maroc/releases/download/ios/bab-taxi-ios-non-signe.ipa. Pour l'installer sur un iPhone, il faut la signer : avec un compte Apple Developer, ajouter les secrets `IOS_CERTIFICATE_P12` (certificat de distribution en base64), `IOS_CERTIFICATE_PASSWORD`, `IOS_PROVISIONING_PROFILE` (profil App Store en base64), `APPSTORE_KEY_ID`, `APPSTORE_ISSUER_ID`, `APPSTORE_PRIVATE_KEY` (clé API App Store Connect) et la variable `IOS_TEAM_ID` : l'application signée est alors envoyée sur TestFlight à chaque version. La carte Google sur iPhone demande d'activer « Maps SDK for iOS » pour la clé `MAPS_API_KEY`.

## Commander par WhatsApp (agent vocal)

Le serveur contient un agent qui prend les commandes sur WhatsApp, par messages vocaux ou écrits, en français et en darija (`backend/src/whatsapp`). Il répète la destination et attend le « oui » du passager, donne seulement les prix totaux, puis crée la course comme l'application et prévient le passager quand un chauffeur accepte, démarre et termine la course.

- Compréhension et dialogue : Claude (`ANTHROPIC_API_KEY`, modèle réglable avec `BAB_AGENT_MODELE`). Sans clé, un agent de démonstration par mots-clés prend le relais.
- Voix : ElevenLabs pour écouter les vocaux et répondre en vocal (`ELEVENLABS_API_KEY`, voix `ELEVENLABS_VOIX`, voix darija `ELEVENLABS_VOIX_DARIJA`).
- WhatsApp : API WhatsApp Business Cloud de Meta (`WHATSAPP_TOKEN`, `WHATSAPP_PHONE_NUMBER_ID`, `WHATSAPP_APP_SECRET`, `WHATSAPP_VERIFY_TOKEN`). Adresse du webhook : `https://bab-taxi.onrender.com/whatsapp/webhook`, champ `messages`.
- Simulateur sans numéro WhatsApp : `https://bab-taxi.onrender.com/whatsapp/demo?cle=<WHATSAPP_DEMO_CLE>` (bouton « Simuler le chauffeur » pour voir les alertes). État : `/whatsapp/etat`.

## Prochaines étapes

1. Base de données PostgreSQL + PostGIS et positions en direct (WebSockets) à la place du stockage en mémoire.
2. Carte (Google Maps) côté passager et côté chauffeur, avec le passager affiché sur le GPS du chauffeur.
3. Inscription par SMS et recensement des chauffeurs (documents, photo, numéro du taxi).
4. Réservation de places en grand taxi, bouton SOS, reçu numérique.
5. Espace admin et tableau de bord pour les ministères.
