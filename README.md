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
- **Course seule ou partagée** : la course seule ne va qu'à un taxi vide, ajoute un supplément et bloque les autres passagers.
- **Prix affiché à l'avance** (`backend/src/domain/fare.ts`) : compteur estimé, minimum, majoration de nuit +50 %, supplément seul, coefficient premium ; grand taxi au prix fixe par place.
- **Plaintes** : refus, prix abusif, conduite dangereuse, comportement, objet oublié.
- **Taxis premium** : filtre par catégorie.
- **Application mobile** : accueil en français, arabe et anglais ; écran passager ; écran chauffeur à gros boutons ; écran de plainte ; **commande vocale** pour les aveugles (dire sa destination, réponse à voix haute).

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

## Prochaines étapes

1. Base de données PostgreSQL + PostGIS et positions en direct (WebSockets) à la place du stockage en mémoire.
2. Carte (Google Maps) côté passager et côté chauffeur, avec le passager affiché sur le GPS du chauffeur.
3. Inscription par SMS et recensement des chauffeurs (documents, photo, numéro du taxi).
4. Réservation de places en grand taxi, bouton SOS, reçu numérique.
5. Espace admin et tableau de bord pour les ministères.
