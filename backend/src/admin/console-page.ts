/** Console d'administration Bab Taxi (une seule page) : https://bab-taxi-eu.onrender.com/admin */
export const CONSOLE = String.raw`<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Bab Taxi · Console</title>
<link rel="stylesheet" href="/admin/vendor/leaflet.css">
<script src="/admin/vendor/leaflet.js"></script>
<script src="/admin/vendor/chart.js"></script>
<style>
:root{--sable:#f7f1e3;--sable2:#efe5cf;--vert:#006233;--vert2:#e3f0e8;--rouge:#c1272d;--rouge2:#fbeaea;--or:#b8892b;--encre:#14213d;--gris:#575e6e;--ligne:#e5dac2;--blanc:#fff}
*{box-sizing:border-box}
html,body{margin:0;height:100%;font-family:system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;background:var(--sable);color:var(--encre)}
button,input,select,textarea{font:inherit}
a{color:var(--vert)}
#connexion{min-height:100%;display:flex;align-items:center;justify-content:center;padding:16px}
.boite{background:#fff;border-radius:20px;padding:28px;width:100%;max-width:380px;box-shadow:0 6px 30px rgba(0,0,0,.08)}
.logo{display:flex;align-items:center;gap:10px;font-weight:800;font-size:20px;color:var(--vert)}
.logo svg{flex:none}
.boite h1{font-size:18px;margin:18px 0 6px}
.boite p{color:var(--gris);font-size:14px;margin:0 0 16px}
input[type=password],input[type=search],textarea,select{width:100%;padding:11px 12px;border:1.5px solid var(--ligne);border-radius:12px;background:#fff}
.btn{border:0;border-radius:12px;padding:10px 16px;font-weight:700;cursor:pointer;background:var(--vert);color:#fff}
.btn.sec{background:#fff;color:var(--encre);border:1.5px solid var(--ligne)}
.btn.rouge{background:#fff;color:var(--rouge);border:1.5px solid var(--rouge)}
.btn.or{background:var(--or)}
.btn:disabled{opacity:.5;cursor:default}
.erreur{color:var(--rouge);font-size:14px;min-height:20px;margin-top:8px}
#app{display:none;height:100%}
.cadre{display:grid;grid-template-columns:232px 1fr;height:100%}
nav{background:var(--encre);color:#fff;display:flex;flex-direction:column;padding:16px 10px;gap:2px}
nav .logo{color:#fff;padding:4px 10px 18px}
nav a{color:#cfd6e4;text-decoration:none;padding:10px 12px;border-radius:10px;display:flex;align-items:center;gap:10px;font-weight:600;font-size:15px}
nav a.actif,nav a:hover{background:rgba(255,255,255,.1);color:#fff}
nav .pastille{margin-left:auto;background:var(--rouge);color:#fff;border-radius:99px;font-size:12px;padding:1px 8px}
nav .bas{margin-top:auto;font-size:12px;color:#97a1b5;padding:10px 12px}
main{overflow:auto;padding:22px 24px 40px}
h2{margin:0 0 4px;font-size:24px}
.sous{color:var(--gris);margin:0 0 18px;font-size:14px}
.tuiles{display:grid;grid-template-columns:repeat(auto-fill,minmax(180px,1fr));gap:12px;margin-bottom:18px}
.tuile{background:#fff;border-radius:16px;padding:14px 16px}
.tuile .v{font-size:28px;font-weight:800;line-height:1.1}
.tuile .l{color:var(--gris);font-size:13px;margin-top:4px}
.tuile.alerte{background:var(--rouge2)} .tuile.alerte .v{color:var(--rouge)}
.tuile.ok .v{color:var(--vert)}
.carte{background:#fff;border-radius:16px;padding:16px;margin-bottom:16px}
.carte h3{margin:0 0 12px;font-size:16px}
.grille2{display:grid;grid-template-columns:1fr 1fr;gap:16px}
table{width:100%;border-collapse:collapse;font-size:14px}
th{text-align:left;color:var(--gris);font-weight:600;font-size:12px;text-transform:uppercase;letter-spacing:.03em;padding:8px;border-bottom:1.5px solid var(--ligne);white-space:nowrap}
td{padding:9px 8px;border-bottom:1px solid #f0e9d8;vertical-align:middle}
tr.cliquable{cursor:pointer} tr.cliquable:hover td{background:#fbf8f1}
.tag{display:inline-block;padding:2px 9px;border-radius:99px;font-size:12px;font-weight:700;white-space:nowrap}
.t-en_attente,.t-recue,.t-vers_client{background:#fff3cd;color:#7a5b00}
.t-valide,.t-terminee,.t-libre,.t-traitee{background:var(--vert2);color:var(--vert)}
.t-refuse,.t-annulee,.t-suspendu,.t-bloque,.t-en_course{background:var(--rouge2);color:var(--rouge)}
.t-expiree,.t-en_cours{background:#e8ecf5;color:#33415c}
.t-acceptee,.t-a_bord{background:#e3ecff;color:#1d4ed8}
.outils{display:flex;gap:8px;flex-wrap:wrap;align-items:center;margin-bottom:12px}
.outils input[type=search]{max-width:280px}
.filtres button{border:1.5px solid var(--ligne);background:#fff;border-radius:99px;padding:6px 12px;font-weight:600;cursor:pointer;font-size:13px}
.filtres button.actif{background:var(--encre);color:#fff;border-color:var(--encre)}
#carteTR{height:calc(100vh - 210px);min-height:420px;border-radius:16px}
.enteteTR{display:flex;justify-content:space-between;align-items:flex-start;gap:12px;flex-wrap:wrap}
.enteteTR .outils{margin:0}
.trGrille{display:grid;grid-template-columns:1fr 300px;gap:16px}
.liste{max-height:calc(100vh - 210px);overflow:auto}
.ligneTaxi{padding:10px;border-bottom:1px solid #f0e9d8;cursor:pointer;font-size:14px}
.ligneTaxi:hover{background:#fbf8f1}
.legende{display:flex;gap:14px;flex-wrap:wrap;font-size:13px;color:var(--gris);margin-bottom:10px}
.point{display:inline-block;width:12px;height:12px;border-radius:50%;margin-right:5px;vertical-align:-1px}
.mk{width:22px;height:22px;border-radius:50%;border:3px solid #fff;box-shadow:0 1px 4px rgba(0,0,0,.4)}
.mk.grand{border-radius:6px}
.mk.demande{background:#2563eb;animation:pouls 1.6s infinite}
.mk.sos{width:28px;height:28px;background:var(--rouge);animation:pouls 1s infinite}
@keyframes pouls{0%{box-shadow:0 0 0 0 rgba(193,39,45,.5)}100%{box-shadow:0 0 0 14px rgba(193,39,45,0)}}
#tiroir{position:fixed;inset:0 0 0 auto;width:min(560px,100%);background:#fff;transform:translateX(100%);visibility:hidden;transition:transform .2s,visibility .2s;z-index:2000;overflow:auto;padding:20px}
#tiroir.ouvert{transform:none;visibility:visible;box-shadow:-10px 0 30px rgba(0,0,0,.15)}
#voile{position:fixed;inset:0;background:rgba(0,0,0,.25);display:none;z-index:1999}
#voile.ouvert{display:block}
.pieces{display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:10px}
.pieces a{text-decoration:none;color:var(--encre);font-size:13px;font-weight:600}
.pieces img{width:100%;height:110px;object-fit:cover;border-radius:10px;background:#eee;display:block;margin-bottom:4px}
dl{display:grid;grid-template-columns:max-content 1fr;gap:6px 14px;font-size:14px;margin:14px 0}
dt{color:var(--gris)} dd{margin:0;font-weight:600}
.actions{display:flex;gap:8px;flex-wrap:wrap;margin-top:14px}
.vide{color:var(--gris);text-align:center;padding:30px 0}
.note{font-size:12px;color:var(--gris)}
.mobileNav{display:none}
@media (max-width:860px){
 .cadre{grid-template-columns:1fr}
 nav{display:none}
 .mobileNav{display:flex;gap:6px;overflow:auto;padding:10px 12px;background:var(--encre);position:sticky;top:0;z-index:1000}
 .mobileNav a{color:#cfd6e4;text-decoration:none;padding:7px 12px;border-radius:99px;font-weight:600;font-size:14px;white-space:nowrap}
 .mobileNav a.actif{background:rgba(255,255,255,.15);color:#fff}
 main{padding:16px}
 .grille2,.trGrille{grid-template-columns:1fr}
 #carteTR{height:60vh}
 .liste{max-height:none}
 .tableau{overflow-x:auto}
}
@media print{nav,.mobileNav,.outils,.actions,#tiroir,#voile{display:none!important}.cadre{display:block}main{overflow:visible}body{background:#fff}.carte,.tuile{break-inside:avoid;border:1px solid #ddd}}
</style>
</head>
<body>
<div id="connexion">
  <form class="boite" id="formConnexion">
    <div class="logo"><svg width="34" height="34" viewBox="0 0 40 40"><path d="M8 36V18a12 12 0 0 1 24 0v18" fill="none" stroke="#c1272d" stroke-width="5"/><path d="M20 8l3 4-3 4-3-4z" fill="#006233"/></svg>Bab Taxi</div>
    <h1>Console d'administration</h1>
    <p>Chauffeurs, passagers, courses, reporting et suivi des taxis en temps réel.</p>
    <input type="password" id="cle" placeholder="Clé d'accès" autocomplete="current-password" required>
    <div class="erreur" id="erreurConnexion"></div>
    <button class="btn" style="width:100%;margin-top:6px" type="submit">Se connecter</button>
    <p class="note" style="margin-top:14px">La clé est la valeur BAB_ADMIN_TOKEN (Render → bab-taxi-eu → Environment). Elle reste enregistrée sur cet appareil.</p>
  </form>
</div>

<div id="app">
 <div class="mobileNav" id="navMobile"></div>
 <div class="cadre">
  <nav id="nav">
    <div class="logo"><svg width="30" height="30" viewBox="0 0 40 40"><path d="M8 36V18a12 12 0 0 1 24 0v18" fill="none" stroke="#c1272d" stroke-width="5"/><path d="M20 8l3 4-3 4-3-4z" fill="#3fbf7f"/></svg>Bab Taxi</div>
  </nav>
  <main id="contenu"></main>
 </div>
</div>
<div id="voile"></div>
<aside id="tiroir"></aside>

<script>
const MODULES = [
  ['tableau', 'Tableau de bord', '📊'],
  ['temps-reel', 'Temps réel', '🗺️'],
  ['chauffeurs', 'Chauffeurs', '🚕'],
  ['passagers', 'Passagers', '👤'],
  ['courses', 'Courses', '🧾'],
  ['reporting', 'Reporting', '📈'],
  ['plaintes', 'Plaintes & SOS', '🛡️'],
];
const STATUTS = { en_attente: 'En attente', acceptee: 'Acceptée', a_bord: 'À bord', terminee: 'Terminée', annulee: 'Annulée', expiree: 'Sans taxi',
  valide: 'Validé', refuse: 'Refusé', suspendu: 'Suspendu', recue: 'Reçue', en_cours: 'En cours', traitee: 'Traitée',
  libre: 'Libre', vers_client: 'Vers le client', en_course: 'En course' };
const PIECES = { photo: 'Photo du chauffeur', cinRecto: 'CIN recto', cinVerso: 'CIN verso', permis: 'Permis', cartePro: 'Carte professionnelle', casier: 'Casier judiciaire', vehicule: 'Photo du taxi' };
const MOTIFS = { refus: 'Refus de course', prix_abusif: 'Prix abusif', conduite_dangereuse: 'Conduite dangereuse', comportement: 'Comportement', objet_oublie: 'Objet oublié', autre: 'Autre' };
const MODES = { partage: 'Partagé', seul: 'Seul', premium: 'Premium' };
let CLE = '';
try { CLE = localStorage.getItem('babCleAdmin') || ''; } catch (e) {}
let sos = null, minuteur = null, carteTR = null, premiereVue = true, graphiques = [];

const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const tag = (s) => '<span class="tag t-' + esc(s) + '">' + esc(STATUTS[s] || s) + '</span>';
const dh = (v) => v === null || v === undefined ? '–' : (Math.round(v * 100) / 100).toLocaleString('fr-FR') + ' DH';
const date = (iso) => iso ? new Date(iso).toLocaleString('fr-FR', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' }) : '–';
const nb = (v) => v === null || v === undefined ? '–' : v.toLocaleString('fr-FR');
const fichier = (id) => '/admin/fichiers/' + encodeURIComponent(id) + '?cle=' + encodeURIComponent(CLE);

async function api(chemin, options) {
  const r = await fetch('/admin/api/' + chemin, { ...(options || {}), headers: { 'x-cle-admin': CLE, 'content-type': 'application/json' } });
  if (r.status === 403) { deconnexion(); throw new Error('Clé invalide'); }
  if (!r.ok) throw new Error(await r.text());
  return r.json();
}
const poster = (chemin, corps) => api(chemin, { method: 'POST', body: JSON.stringify(corps) });

document.getElementById('formConnexion').addEventListener('submit', async (e) => {
  e.preventDefault();
  CLE = document.getElementById('cle').value.trim();
  try { await demarrer(); } catch (err) { document.getElementById('erreurConnexion').textContent = 'Clé invalide.'; }
});

function deconnexion() {
  CLE = '';
  try { localStorage.removeItem('babCleAdmin'); } catch (e) {}
  document.getElementById('app').style.display = 'none';
  document.getElementById('connexion').style.display = 'flex';
}

async function demarrer() {
  const s = await api('session');
  sos = s.sosCentre;
  cleCarte = s.cleCarte || '';
  try { localStorage.setItem('babCleAdmin', CLE); } catch (e) {}
  document.getElementById('connexion').style.display = 'none';
  document.getElementById('app').style.display = 'block';
  const liens = MODULES.map(([id, nom, ic]) => '<a href="#' + id + '" data-m="' + id + '"><span>' + ic + '</span>' + nom + '<span class="pastille" id="pa-' + id + '" hidden></span></a>').join('');
  document.getElementById('nav').innerHTML = document.getElementById('nav').querySelector('.logo').outerHTML + liens +
    '<div class="bas"><a href="#" id="sortie" style="padding:0;color:#97a1b5">Se déconnecter</a></div>';
  document.getElementById('navMobile').innerHTML = MODULES.map(([id, nom]) => '<a href="#' + id + '" data-m="' + id + '">' + nom + '</a>').join('');
  document.getElementById('sortie').onclick = (e) => { e.preventDefault(); deconnexion(); };
  window.onhashchange = route;
  route();
}

function route() {
  const m = (location.hash || '#tableau').slice(1);
  document.querySelectorAll('[data-m]').forEach((a) => a.classList.toggle('actif', a.dataset.m === m));
  clearInterval(minuteur);
  graphiques.forEach((g) => g.destroy()); graphiques = [];
  if (carteTR) { carteTR.retirer(); carteTR = null; premiereVue = true; }
  fermerTiroir();
  const f = { tableau, 'temps-reel': tempsReel, chauffeurs, passagers, courses, reporting, plaintes }[m] || tableau;
  f().catch((e) => { document.getElementById('contenu').innerHTML = '<p class="vide">Erreur : ' + esc(e.message) + '</p>'; });
}

const C = () => document.getElementById('contenu');
const tuile = (v, l, cls) => '<div class="tuile ' + (cls || '') + '"><div class="v">' + v + '</div><div class="l">' + l + '</div></div>';

// ---------------- Tableau de bord ----------------
async function tableau() {
  const charger = async () => {
    const r = await api('resume');
    const p = document.getElementById('pa-chauffeurs'); if (p) { p.hidden = !r.chauffeurs.aVerifier; p.textContent = r.chauffeurs.aVerifier; }
    const q = document.getElementById('pa-plaintes'); if (q) { q.hidden = !(r.plaintesOuvertes + r.sosEnDirect); q.textContent = r.plaintesOuvertes + r.sosEnDirect; }
    C().innerHTML = '<h2>Tableau de bord</h2><p class="sous">Mis à jour ' + date(r.heure) + ' · actualisation toutes les 15 s</p>' +
      (r.sosEnDirect ? '<div class="carte" style="background:var(--rouge2)"><b style="color:var(--rouge)">🚨 ' + r.sosEnDirect + ' alerte(s) SOS en direct.</b> ' + (sos ? '<a href="' + sos + '" target="_blank">Ouvrir le centre de sécurité</a>' : '') + '</div>' : '') +
      '<h3>Maintenant</h3><div class="tuiles">' +
      tuile(r.taxis.enLigne, 'taxis en ligne', 'ok') + tuile(r.taxis.libres, 'taxis libres') + tuile(r.taxis.occupes, 'taxis avec passagers') +
      tuile(r.courses.enCours, 'courses en cours') + tuile(r.sosEnDirect, 'SOS en direct', r.sosEnDirect ? 'alerte' : '') + '</div>' +
      '<h3>Aujourd\'hui</h3><div class="tuiles">' +
      tuile(r.courses.aujourdhui, 'demandes de course') + tuile(r.courses.termineesAujourdhui, 'courses terminées', 'ok') +
      tuile(r.courses.annuleesAujourdhui, 'annulées par le passager') + tuile(r.courses.sansTaxiAujourdhui, 'sans taxi disponible', r.courses.sansTaxiAujourdhui ? 'alerte' : '') +
      tuile(dh(r.montants.aujourdhui), 'montant estimé des courses') + '</div>' +
      '<h3>30 derniers jours</h3><div class="tuiles">' +
      tuile(r.courses.tauxAcceptation30j === null ? '–' : r.courses.tauxAcceptation30j + ' %', 'demandes acceptées par un chauffeur') +
      tuile(r.courses.delaiAcceptationMin === null ? '–' : r.courses.delaiAcceptationMin + ' min', 'délai moyen d\'acceptation') +
      tuile(r.courses.dureeCourseMin === null ? '–' : r.courses.dureeCourseMin + ' min', 'durée moyenne d\'une course') +
      tuile(r.courses.whatsapp30j, 'commandes par WhatsApp') + tuile(dh(r.montants.trente), 'montant estimé (30 j)') + '</div>' +
      '<h3>Communauté</h3><div class="tuiles">' +
      tuile(r.chauffeurs.valides, 'chauffeurs validés', 'ok') + tuile(r.chauffeurs.aVerifier, 'dossiers à vérifier', r.chauffeurs.aVerifier ? 'alerte' : '') +
      tuile(r.chauffeurs.suspendus, 'chauffeurs suspendus') + tuile(r.passagers.total, 'passagers inscrits') + tuile(r.passagers.nouveaux7j, 'nouveaux passagers (7 j)') +
      tuile(r.plaintesOuvertes, 'plaintes à traiter', r.plaintesOuvertes ? 'alerte' : '') + '</div>' +
      '<p class="note">' + esc(r.montants.note) + '</p>';
  };
  await charger();
  minuteur = setInterval(() => charger().catch(() => {}), 15000);
}

// ---------------- Temps réel ----------------
// Carte Google Maps aux couleurs de Bab Taxi quand le serveur a une clé (GOOGLE_MAPS_API_KEY ou MAPS_API_KEY),
// sinon OpenStreetMap. Même interface pour les deux : marqueur HTML, ligne, cadrage.
const STYLE_BAB = [
  {elementType:'geometry',stylers:[{color:'#f7f1e3'}]},
  {elementType:'labels.icon',stylers:[{saturation:-60},{lightness:15}]},
  {elementType:'labels.text.fill',stylers:[{color:'#575e6e'}]},
  {elementType:'labels.text.stroke',stylers:[{color:'#fffaf0'},{weight:3}]},
  {featureType:'administrative.land_parcel',stylers:[{visibility:'off'}]},
  {featureType:'administrative.neighborhood',elementType:'labels.text.fill',stylers:[{color:'#006233'}]},
  {featureType:'administrative.locality',elementType:'labels.text.fill',stylers:[{color:'#0f2a1e'}]},
  {featureType:'poi',elementType:'geometry',stylers:[{color:'#efe5cf'}]},
  {featureType:'poi.business',stylers:[{visibility:'off'}]},
  {featureType:'poi.park',elementType:'geometry',stylers:[{color:'#d6eadb'}]},
  {featureType:'road',elementType:'geometry.fill',stylers:[{color:'#ffffff'}]},
  {featureType:'road',elementType:'geometry.stroke',stylers:[{color:'#e5dac2'}]},
  {featureType:'road',elementType:'labels.icon',stylers:[{visibility:'off'}]},
  {featureType:'road.highway',elementType:'geometry.fill',stylers:[{color:'#f6d9d3'}]},
  {featureType:'road.highway',elementType:'geometry.stroke',stylers:[{color:'#e9b9b0'}]},
  {featureType:'road.local',elementType:'labels.text.fill',stylers:[{color:'#8a8576'}]},
  {featureType:'transit.line',stylers:[{visibility:'simplified'},{color:'#e2d6bd'}]},
  {featureType:'water',elementType:'geometry',stylers:[{color:'#cfe4e4'}]},
  {featureType:'water',elementType:'labels.text.fill',stylers:[{color:'#5d8f8f'}]},
];
let cleCarte = '', googleCharge = null, carteRefusee = false;
function chargerGoogle() {
  if (!cleCarte) return Promise.reject(new Error('pas de clé'));
  if (!googleCharge) googleCharge = new Promise((ok, ko) => {
    window.__babGoogle = () => ok(window.google);
    // Clé refusée par Google (API non activée, domaine non autorisé…) : on repasse sur OpenStreetMap.
    window.gm_authFailure = () => { ko(new Error('Clé Google Maps refusée')); cleCarte = ''; carteRefusee = true; if (carteTR && carteTR.nom === 'Google Maps') route(); };
    const sc = document.createElement('script');
    sc.src = 'https://maps.googleapis.com/maps/api/js?key=' + encodeURIComponent(cleCarte) + '&callback=__babGoogle&language=fr&region=MA';
    sc.async = true; sc.onerror = () => ko(new Error('Google Maps injoignable'));
    document.head.appendChild(sc);
    setTimeout(() => ko(new Error('Google Maps trop lent')), 10000);
  });
  return googleCharge;
}

function carteGoogle(el, g) {
  const map = new g.maps.Map(el, { center: { lat: 33.5731, lng: -7.5898 }, zoom: 12, styles: STYLE_BAB,
    mapTypeControl: false, streetViewControl: false, fullscreenControl: true, clickableIcons: false });
  const info = new g.maps.InfoWindow();
  let objets = [];
  class Html extends g.maps.OverlayView {
    constructor(pos, html, taille, z, popup) { super(); this.pos = pos; this.html = html; this.taille = taille; this.z = z; this.popup = popup; }
    onAdd() {
      const d = document.createElement('div');
      d.style.cssText = 'position:absolute;cursor:pointer;z-index:' + this.z;
      d.innerHTML = this.html; this.div = d;
      d.onclick = (e) => { e.stopPropagation(); info.setContent(this.popup); info.setPosition(this.pos); info.open({ map }); };
      this.getPanes().overlayMouseTarget.appendChild(d);
    }
    draw() {
      const p = this.getProjection().fromLatLngToDivPixel(new g.maps.LatLng(this.pos));
      if (p && this.div) { this.div.style.left = (p.x - this.taille / 2) + 'px'; this.div.style.top = (p.y - this.taille / 2) + 'px'; }
    }
    onRemove() { this.div && this.div.remove(); this.div = null; }
  }
  return {
    nom: 'Google Maps',
    vider() { objets.forEach((o) => o.setMap(null)); objets = []; },
    marqueur(ll, html, taille, popup, z) { const m = new Html({ lat: ll[0], lng: ll[1] }, html, taille, z || 1, popup); m.setMap(map); objets.push(m); },
    ligne(pts, couleur) { objets.push(new g.maps.Polyline({ map, path: pts.map((p) => ({ lat: p[0], lng: p[1] })), strokeColor: couleur, strokeOpacity: .7, strokeWeight: 4 })); },
    cadrer(pts) {
      if (pts.length === 1) { map.setCenter({ lat: pts[0][0], lng: pts[0][1] }); map.setZoom(15); return; }
      const b = new g.maps.LatLngBounds(); pts.forEach((p) => b.extend({ lat: p[0], lng: p[1] })); map.fitBounds(b, 60);
      g.maps.event.addListenerOnce(map, 'idle', () => { if (map.getZoom() > 15) map.setZoom(15); });
    },
    centrer(ll, z) { map.setCenter({ lat: ll[0], lng: ll[1] }); map.setZoom(z); },
    retirer() { this.vider(); el.innerHTML = ''; },
  };
}

function carteOsm(el) {
  const map = L.map(el, { zoomControl: true }).setView([33.5731, -7.5898], 12);
  L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', { maxZoom: 19, attribution: '&copy; OpenStreetMap' }).addTo(map);
  const couche = L.layerGroup().addTo(map);
  return {
    nom: 'OpenStreetMap',
    vider() { couche.clearLayers(); },
    marqueur(ll, html, taille, popup, z) { L.marker(ll, { icon: L.divIcon({ className: '', html, iconSize: [taille, taille], iconAnchor: [taille / 2, taille / 2] }), zIndexOffset: (z || 0) * 100 }).bindPopup(popup).addTo(couche); },
    ligne(pts, couleur) { L.polyline(pts, { color: couleur, weight: 3, opacity: .6 }).addTo(couche); },
    cadrer(pts) { map.fitBounds(pts, { maxZoom: 15, padding: [40, 40] }); },
    centrer(ll, z) { map.setView(ll, z); },
    retirer() { map.remove(); },
  };
}

let dernierTR = null;
async function tempsReel() {
  C().innerHTML = '<div class="enteteTR"><div><h2>Suivi des taxis en temps réel</h2><p class="sous" id="trInfo">Chargement…</p></div>' +
    '<div class="outils"><button class="btn" id="trMaj">↻ Rafraîchir</button><button class="btn sec" id="trCadrer">Recentrer</button></div></div>' +
    '<div class="legende"><span><i class="point" style="background:#006233"></i>Libre</span><span><i class="point" style="background:#b8892b"></i>Vers le client</span>' +
    '<span><i class="point" style="background:#c1272d"></i>En course</span><span><i class="point" style="background:#2563eb"></i>Demande sans taxi</span>' +
    '<span><i class="point" style="background:#9aa0ab"></i>Dossier non validé</span><span>■ Grand taxi</span><span>🚨 SOS</span></div>' +
    '<div class="trGrille"><div id="carteTR"></div><div class="carte liste" style="padding:0" id="trListe"></div></div>';
  const el = document.getElementById('carteTR');
  try { carteTR = carteGoogle(el, await chargerGoogle()); }
  catch (e) { el.innerHTML = ''; carteTR = carteOsm(el); }
  const couleur = { libre: '#006233', vers_client: '#b8892b', en_course: '#c1272d' };
  const pastille = (fond, grand, cls) => '<div class="mk ' + (grand ? 'grand ' : '') + (cls || '') + '" style="background:' + fond + '"></div>';
  let points = [];
  const charger = async () => {
    const bouton = document.getElementById('trMaj');
    if (bouton) { bouton.disabled = true; bouton.textContent = '↻ Actualisation…'; }
    try {
      const r = await api('temps-reel');
      dernierTR = r;
      const carte = carteTR; if (!carte) return;
      carte.vider();
      points = [];
      for (const t of r.taxis) {
        const ll = [t.position.lat, t.position.lng]; points.push(ll);
        if (t.itineraire.length > 1 && t.etat !== 'libre') carte.ligne(t.itineraire.map((p) => [p.lat, p.lng]), couleur[t.etat]);
        carte.marqueur(ll, pastille(couleur[t.etat], t.type === 'grand'), 22,
          '<b>' + esc(t.nom) + '</b><br>' + (t.type === 'grand' ? 'Grand' : 'Petit') + ' taxi ' + esc(t.numero) + ' · ' + esc(t.plaque) + '<br>' + tag(t.etat) + ' · ' + t.passagers + ' passager(s)' +
          (t.courses.length ? '<br>→ ' + t.courses.map((c) => esc(c.destination || '')).join(', ') : '') + '<br><span class="note">position il y a ' + t.vuIlYaS + ' s</span>', 2);
      }
      for (const t of (r.nonValides || [])) {
        const ll = [t.position.lat, t.position.lng]; points.push(ll);
        carte.marqueur(ll, pastille('#9aa0ab', t.type === 'grand'), 22,
          '<b>' + esc(t.nom) + '</b><br>' + (t.statut === 'sans_dossier' ? 'Aucun dossier chauffeur envoyé' : 'Dossier ' + esc(STATUTS[t.statut] || t.statut)) +
          '<br>Ne reçoit pas de course tant que le dossier n\'est pas validé (module Chauffeurs).<br><span class="note">position il y a ' + t.vuIlYaS + ' s</span>', 1);
      }
      for (const d of r.demandes) {
        points.push([d.depart.lat, d.depart.lng]);
        carte.marqueur([d.depart.lat, d.depart.lng], '<div class="mk demande"></div>', 22,
          '<b>Demande en attente</b><br>→ ' + esc(d.destinationNom || '') + '<br>' + (d.source === 'whatsapp' ? 'WhatsApp' : 'Application') + ' · depuis ' + Math.round(d.depuisS / 60) + ' min<br>' + d.taxisPrevenus + ' taxi(s) prévenu(s)', 3);
      }
      for (const a of r.sos) if (a.position) {
        points.push([a.position.lat, a.position.lng]);
        carte.marqueur([a.position.lat, a.position.lng], '<div class="mk sos"></div>', 28,
          '<b style="color:#c1272d">SOS en direct</b><br>' + esc(a.nom || '') + (sos ? '<br><a href="' + sos + '" target="_blank">Centre de sécurité</a>' : ''), 9);
      }
      if (premiereVue && points.length) { carte.cadrer(points); premiereVue = false; }
      const n = (e) => r.taxis.filter((t) => t.etat === e).length;
      const nv = (r.nonValides || []).length;
      document.getElementById('trInfo').textContent = r.taxis.length + ' taxis en ligne (' + n('libre') + ' libres, ' + n('vers_client') + ' vers un client, ' + n('en_course') + ' en course)' +
        (nv ? ' · ' + nv + ' non validé(s)' : '') + ' · ' + r.demandes.length + ' demande(s) en attente · actualisé ' + new Date(r.heure).toLocaleTimeString('fr-FR') + ' · ' + carte.nom + (carteRefusee ? ' (clé Google Maps refusée)' : '');
      const lignes = r.taxis.map((t, i) =>
        '<div class="ligneTaxi" data-k="t' + i + '"><b>' + esc(t.nom) + '</b> ' + tag(t.etat) + '<br><span class="note">' + (t.type === 'grand' ? 'Grand' : 'Petit') + ' taxi ' + esc(t.numero) + ' · ' + esc(t.plaque) + ' · ' + t.passagers + ' passager(s)</span></div>')
        .concat((r.nonValides || []).map((t, i) =>
        '<div class="ligneTaxi" data-k="n' + i + '"><b>' + esc(t.nom) + '</b> <span class="tag">Non validé</span><br><span class="note">En ligne dans l\'application, mais le dossier n\'est pas validé</span></div>'));
      document.getElementById('trListe').innerHTML = lignes.length ? lignes.join('')
        : '<div class="vide" style="text-align:left;padding:18px"><b>Aucun taxi en ligne.</b><br><br>Un taxi apparaît ici quand un chauffeur ouvre l\'application <b>Bab Taxi Chauffeur</b> et appuie sur <b>Commencer le service</b>, avec la localisation activée.<br><br>Son dossier doit être validé dans le module Chauffeurs pour recevoir des courses. La position se met à jour toutes les 5 secondes.</div>';
      document.querySelectorAll('.ligneTaxi').forEach((el2) => el2.onclick = () => {
        const k = el2.dataset.k; const t = k[0] === 't' ? r.taxis[+k.slice(1)] : r.nonValides[+k.slice(1)];
        carte.centrer([t.position.lat, t.position.lng], 16);
      });
    } finally {
      const b2 = document.getElementById('trMaj');
      if (b2) { b2.disabled = false; b2.textContent = '↻ Rafraîchir'; }
    }
  };
  document.getElementById('trMaj').onclick = () => charger().catch((e) => { document.getElementById('trInfo').textContent = 'Erreur : ' + e.message; });
  document.getElementById('trCadrer').onclick = () => { if (points.length) carteTR.cadrer(points); else carteTR.centrer([33.5731, -7.5898], 12); };
  await charger();
  minuteur = setInterval(() => charger().catch(() => {}), 5000);
}

// ---------------- Chauffeurs ----------------
let filtreCh = 'tous';
async function chauffeurs() {
  const liste = await api('chauffeurs');
  const rendre = () => {
    const q = (document.getElementById('rch')?.value || '').toLowerCase();
    const l = liste.filter((d) => (filtreCh === 'tous' || (filtreCh === 'en_ligne' ? d.enLigne : d.statut === filtreCh)) &&
      (!q || [d.prenom, d.nom, d.telephone, d.plaque, d.taxiNumero, d.cin].join(' ').toLowerCase().includes(q)));
    document.getElementById('tCh').innerHTML = l.length ? '<table><tr><th>Chauffeur</th><th>Statut</th><th>Taxi</th><th>Téléphone</th><th>Courses</th><th>Refus</th><th>Montant</th><th>Plaintes</th><th>En ligne</th></tr>' +
      l.map((d) => '<tr class="cliquable" data-id="' + esc(d.id) + '"><td><b>' + esc(d.prenom + ' ' + d.nom) + '</b><br><span class="note">' + esc(d.ville) + '</span></td><td>' + tag(d.statut) + '</td><td>' + (d.taxiType === 'grand' ? 'Grand' : 'Petit') + ' n° ' + esc(d.taxiNumero) + '<br><span class="note">' + esc(d.plaque) + '</span></td><td>+' + esc(d.telephone) + '</td><td>' + d.courses + '</td><td>' + d.refus + '</td><td>' + dh(d.montant) + '</td><td>' + (d.plaintes || '') + '</td><td>' + (d.enLigne ? '🟢' : '') + '</td></tr>').join('') + '</table>'
      : '<p class="vide">Aucun chauffeur.</p>';
    document.querySelectorAll('#tCh tr[data-id]').forEach((tr) => tr.onclick = () => ficheChauffeur(liste.find((d) => d.id === tr.dataset.id)));
  };
  const comptes = (s) => liste.filter((d) => d.statut === s).length;
  C().innerHTML = '<h2>Chauffeurs</h2><p class="sous">' + liste.length + ' dossiers · ' + comptes('valide') + ' validés · ' + comptes('en_attente') + ' à vérifier</p>' +
    '<div class="outils"><input type="search" id="rch" placeholder="Nom, téléphone, plaque, CIN…"><div class="filtres">' +
    [['tous', 'Tous'], ['en_attente', 'À vérifier (' + comptes('en_attente') + ')'], ['valide', 'Validés'], ['en_ligne', 'En ligne'], ['suspendu', 'Suspendus'], ['refuse', 'Refusés']]
      .map(([k, n]) => '<button data-f="' + k + '" class="' + (k === filtreCh ? 'actif' : '') + '">' + n + '</button>').join('') + '</div></div>' +
    '<div class="carte tableau" id="tCh"></div>';
  document.getElementById('rch').oninput = rendre;
  document.querySelectorAll('.filtres button').forEach((b) => b.onclick = () => { filtreCh = b.dataset.f; chauffeurs(); });
  rendre();
}

function ficheChauffeur(d) {
  const photo = (d.pieces.find((p) => p[0] === 'photo') || [])[1];
  ouvrirTiroir('<div style="display:flex;gap:14px;align-items:center">' + (photo ? '<img src="' + fichier(photo) + '" style="width:76px;height:76px;border-radius:50%;object-fit:cover">' : '') +
    '<div><h2 style="font-size:20px">' + esc(d.prenom + ' ' + d.nom) + '</h2>' + tag(d.statut) + (d.enLigne ? ' <span class="tag t-libre">En ligne</span>' : '') + '</div></div>' +
    (d.motif ? '<p style="color:var(--rouge)">Motif : ' + esc(d.motif) + '</p>' : '') +
    '<dl><dt>Téléphone</dt><dd>+' + esc(d.telephone) + '</dd><dt>Ville</dt><dd>' + esc(d.ville) + '</dd><dt>CIN</dt><dd>' + esc(d.cin) + '</dd><dt>Permis</dt><dd>' + esc(d.permis) + '</dd>' +
    '<dt>Carte professionnelle</dt><dd>' + esc(d.cartePro) + '</dd><dt>Taxi</dt><dd>' + (d.taxiType === 'grand' ? 'Grand' : 'Petit') + ' taxi n° ' + esc(d.taxiNumero) + ' · ' + esc(d.plaque) + '</dd>' +
    '<dt>Langues</dt><dd>' + esc((d.langues || []).join(', ') || '–') + '</dd><dt>Dossier envoyé</dt><dd>' + date(d.envoyeLe) + '</dd><dt>Décision</dt><dd>' + date(d.decideLe) + '</dd>' +
    '<dt>Courses terminées</dt><dd>' + d.courses + ' (' + dh(d.montant) + ')</dd><dt>Refus</dt><dd>' + d.refus + '</dd><dt>Plaintes</dt><dd>' + d.plaintes + '</dd></dl>' +
    '<h3>Pièces du dossier</h3><div class="pieces">' + d.pieces.map((p) => '<a href="' + fichier(p[1]) + '" target="_blank" rel="noopener"><img loading="lazy" src="' + fichier(p[1]) + '">' + (PIECES[p[0]] || p[0]) + '</a>').join('') + '</div>' +
    '<div class="actions">' +
    (d.statut !== 'valide' ? '<button class="btn" data-d="valide">' + (d.statut === 'suspendu' ? 'Réactiver' : 'Valider le chauffeur') + '</button>' : '') +
    (d.statut === 'en_attente' ? '<button class="btn rouge" data-d="refuse">Refuser</button>' : '') +
    (d.statut === 'valide' ? '<button class="btn rouge" data-d="suspendu">Suspendre</button>' : '') + '</div>');
  document.querySelectorAll('#tiroir [data-d]').forEach((b) => b.onclick = async () => {
    let motif = '';
    if (b.dataset.d !== 'valide') { motif = prompt(b.dataset.d === 'refuse' ? 'Motif du refus (montré au chauffeur) :' : 'Motif de la suspension :'); if (!motif) return; }
    else if (!confirm('Confirmer ? Le chauffeur pourra recevoir des courses.')) return;
    b.disabled = true;
    try { await poster('chauffeurs/' + encodeURIComponent(d.id) + '/decision', { decision: b.dataset.d, motif }); fermerTiroir(); chauffeurs(); }
    catch (e) { alert('Erreur : ' + e.message); b.disabled = false; }
  });
}

// ---------------- Passagers ----------------
async function passagers() {
  const liste = await api('passagers');
  const rendre = () => {
    const q = (document.getElementById('rpa').value || '').toLowerCase();
    const l = liste.filter((p) => !q || [p.prenom, p.nom, p.telephone, p.email].join(' ').toLowerCase().includes(q));
    document.getElementById('tPa').innerHTML = l.length ? '<table><tr><th>Passager</th><th>Téléphone</th><th>Inscrit le</th><th>Courses</th><th>Terminées</th><th>Annulées</th><th>WhatsApp</th><th>Dernière course</th><th>État</th></tr>' +
      l.map((p) => '<tr class="cliquable" data-id="' + esc(p.id) + '"><td><b>' + esc(p.prenom + ' ' + p.nom) + '</b><br><span class="note">' + esc(p.nationalite || '') + ' · ' + esc(p.langue || '') + '</span></td><td>+' + esc(p.telephone) + (p.verifie ? ' ✓' : '') + '</td><td>' + date(p.creeLe) + '</td><td>' + p.courses + '</td><td>' + p.terminees + '</td><td>' + p.annulees + '</td><td>' + p.whatsapp + '</td><td>' + date(p.derniereCourse) + '</td><td>' + (p.bloque ? tag('bloque').replace('bloque', 'Bloqué') : '') + '</td></tr>').join('') + '</table>'
      : '<p class="vide">Aucun passager.</p>';
    document.querySelectorAll('#tPa tr[data-id]').forEach((tr) => tr.onclick = () => fichePassager(liste.find((p) => p.id === tr.dataset.id)));
  };
  C().innerHTML = '<h2>Passagers</h2><p class="sous">' + liste.length + ' comptes · ' + liste.filter((p) => p.courses).length + ' ont déjà commandé</p>' +
    '<div class="outils"><input type="search" id="rpa" placeholder="Nom, téléphone, e-mail…"></div><div class="carte tableau" id="tPa"></div>';
  document.getElementById('rpa').oninput = rendre;
  rendre();
}

function fichePassager(p) {
  ouvrirTiroir('<h2 style="font-size:20px">' + esc(p.prenom + ' ' + p.nom) + '</h2>' + (p.bloque ? '<span class="tag t-bloque">Bloqué</span>' : '') +
    (p.motifBlocage ? '<p style="color:var(--rouge)">Motif : ' + esc(p.motifBlocage) + '</p>' : '') +
    '<dl><dt>Téléphone</dt><dd>+' + esc(p.telephone) + (p.verifie ? ' (vérifié)' : '') + '</dd><dt>E-mail</dt><dd>' + esc(p.email || '–') + '</dd><dt>Nationalité</dt><dd>' + esc(p.nationalite || '–') + '</dd>' +
    '<dt>Langue</dt><dd>' + esc(p.langue || '–') + '</dd><dt>Inscrit le</dt><dd>' + date(p.creeLe) + '</dd><dt>Courses</dt><dd>' + p.courses + ' (' + p.terminees + ' terminées, ' + p.annulees + ' annulées, ' + p.whatsapp + ' par WhatsApp)</dd>' +
    '<dt>Dernière course</dt><dd>' + date(p.derniereCourse) + '</dd></dl><div class="actions">' +
    (p.bloque ? '<button class="btn" id="bq">Débloquer</button>' : '<button class="btn rouge" id="bq">Bloquer ce passager</button>') + '</div>');
  document.getElementById('bq').onclick = async () => {
    let motif = '';
    if (!p.bloque) { motif = prompt('Motif du blocage :'); if (!motif) return; }
    try { await poster('passagers/' + encodeURIComponent(p.id) + '/blocage', { bloque: !p.bloque, motif }); fermerTiroir(); passagers(); } catch (e) { alert('Erreur : ' + e.message); }
  };
}

// ---------------- Courses ----------------
let filtreCo = 'toutes';
async function courses() {
  const liste = await api('courses');
  const n = (f) => liste.filter(f).length;
  const filtres = { toutes: () => true, en_cours: (c) => ['en_attente', 'acceptee', 'a_bord'].includes(c.statut), terminee: (c) => c.statut === 'terminee', annulee: (c) => c.statut === 'annulee', expiree: (c) => c.statut === 'expiree', whatsapp: (c) => c.source === 'whatsapp' };
  const l = liste.filter(filtres[filtreCo]);
  C().innerHTML = '<h2>Courses</h2><p class="sous">' + liste.length + ' dernières courses · prix = estimation annoncée (le compteur fait foi)</p>' +
    '<div class="outils"><div class="filtres">' + [['toutes', 'Toutes'], ['en_cours', 'En cours (' + n(filtres.en_cours) + ')'], ['terminee', 'Terminées'], ['annulee', 'Annulées'], ['expiree', 'Sans taxi'], ['whatsapp', 'WhatsApp']]
      .map(([k, t]) => '<button data-f="' + k + '" class="' + (k === filtreCo ? 'actif' : '') + '">' + t + '</button>').join('') + '</div>' +
    '<a class="btn sec" style="margin-left:auto;text-decoration:none" href="/admin/api/courses.csv?cle=' + encodeURIComponent(CLE) + '">⬇ Export Excel (CSV)</a></div>' +
    '<div class="carte tableau">' + (l.length ? '<table><tr><th>Date</th><th>Statut</th><th>Passager</th><th>Destination</th><th>Offre</th><th>Prix estimé</th><th>Chauffeur</th><th>Taxis prévenus</th><th>Acceptée en</th><th>Durée</th></tr>' +
      l.map((c) => '<tr><td>' + date(c.creeLe) + '</td><td>' + tag(c.statut) + '</td><td>' + esc(c.passager) + (c.source === 'whatsapp' ? ' <span class="note">WA</span>' : '') + '</td><td>' + esc(c.destination) + '<br><span class="note">' + c.distanceKm + ' km</span></td><td>' + (MODES[c.mode] || c.mode) + ' · ' + c.personnes + ' pers.</td><td>' + dh(c.prixMad) + '</td><td>' + esc(c.chauffeur) + '<br><span class="note">' + esc(c.plaque) + '</span></td><td>' + c.taxisPrevenus + '</td><td>' + (c.delaiAcceptationMin === undefined || c.delaiAcceptationMin === null ? '–' : c.delaiAcceptationMin.toFixed(1) + ' min') + '</td><td>' + (c.dureeMin === undefined || c.dureeMin === null ? '–' : Math.round(c.dureeMin) + ' min') + '</td></tr>').join('') + '</table>' : '<p class="vide">Aucune course.</p>') + '</div>';
  document.querySelectorAll('.filtres button').forEach((b) => b.onclick = () => { filtreCo = b.dataset.f; courses(); });
}

// ---------------- Reporting ----------------
let periode = 30;
async function reporting() {
  const r = await api('reporting?jours=' + periode);
  const somme = (k) => r.parJour.reduce((s, j) => s + j[k], 0);
  C().innerHTML = '<h2>Reporting</h2><p class="sous">Données agrégées et anonymes (loi 09-08), utilisables pour les rapports aux institutions.</p>' +
    '<div class="outils"><div class="filtres">' + [7, 30, 90, 365].map((j) => '<button data-j="' + j + '" class="' + (j === periode ? 'actif' : '') + '">' + (j === 365 ? '1 an' : j + ' jours') + '</button>').join('') + '</div>' +
    '<button class="btn sec" style="margin-left:auto" onclick="window.print()">🖨 Imprimer / PDF</button>' +
    '<a class="btn sec" style="text-decoration:none" href="/admin/api/courses.csv?cle=' + encodeURIComponent(CLE) + '">⬇ Courses (CSV)</a></div>' +
    '<div class="tuiles">' + tuile(nb(somme('demandes')), 'demandes') + tuile(nb(somme('terminees')), 'courses terminées', 'ok') + tuile(nb(somme('annulees')), 'annulées') +
    tuile(nb(somme('sansTaxi')), 'sans taxi disponible', somme('sansTaxi') ? 'alerte' : '') + tuile(dh(somme('montant')), 'montant estimé') + tuile(nb(r.plaintes.total), 'plaintes') + '</div>' +
    '<div class="carte"><h3>Courses par jour</h3><canvas id="gJours" height="90"></canvas></div>' +
    '<div class="grille2"><div class="carte"><h3>Demandes par heure de la journée</h3><canvas id="gHeures" height="160"></canvas></div>' +
    '<div class="carte"><h3>Montant estimé par jour (DH)</h3><canvas id="gMontant" height="160"></canvas></div></div>' +
    '<div class="grille2"><div class="carte"><h3>Offres choisies</h3><canvas id="gModes" height="160"></canvas></div>' +
    '<div class="carte"><h3>Canal de commande</h3><canvas id="gSources" height="160"></canvas></div></div>' +
    '<div class="grille2"><div class="carte"><h3>Destinations les plus demandées</h3>' + (r.topDestinations.length ? '<table>' + r.topDestinations.map((d) => '<tr><td>' + esc(d.nom) + '</td><td style="text-align:right"><b>' + d.n + '</b></td></tr>').join('') + '</table>' : '<p class="vide">Pas encore de données.</p>') + '</div>' +
    '<div class="carte"><h3>Plaintes par motif</h3>' + (r.plaintes.total ? '<table>' + Object.entries(r.plaintes.motifs).map(([m, n]) => '<tr><td>' + esc(MOTIFS[m] || m) + '</td><td style="text-align:right"><b>' + n + '</b></td></tr>').join('') + '</table>' : '<p class="vide">Aucune plainte.</p>') + '</div></div>' +
    '<div class="carte tableau"><h3>Publicités (annonceurs fictifs pendant le test)</h3><table><tr><th>Annonceur</th><th>Emplacement</th><th>Vues</th><th>Clics</th><th>Taux de clic</th><th>Bons</th></tr>' +
    r.publicites.map((p) => '<tr><td><b>' + esc(p.annonceur) + '</b><br><span class="note">' + esc(p.titre) + '</span></td><td>' + esc(p.emplacement) + '</td><td>' + nb(p.vue) + '</td><td>' + nb(p.clic) + '</td><td>' + p.ctr + ' %</td><td>' + nb(p.bon) + '</td></tr>').join('') + '</table></div>';
  document.querySelectorAll('.filtres button').forEach((b) => b.onclick = () => { periode = +b.dataset.j; route(); });
  const jours = r.parJour.map((j) => j.jour.slice(5).split('-').reverse().join('/'));
  Chart.defaults.font.family = 'system-ui, sans-serif';
  graphiques.push(new Chart(document.getElementById('gJours'), { type: 'bar', data: { labels: jours, datasets: [
    { label: 'Terminées', data: r.parJour.map((j) => j.terminees), backgroundColor: '#006233', stack: 'a' },
    { label: 'Annulées', data: r.parJour.map((j) => j.annulees), backgroundColor: '#b8892b', stack: 'a' },
    { label: 'Sans taxi', data: r.parJour.map((j) => j.sansTaxi), backgroundColor: '#c1272d', stack: 'a' }] },
    options: { responsive: true, scales: { x: { stacked: true }, y: { stacked: true, beginAtZero: true, ticks: { precision: 0 } } } } }));
  graphiques.push(new Chart(document.getElementById('gHeures'), { type: 'bar', data: { labels: r.parHeure.map((h) => h.heure + 'h'), datasets: [{ label: 'Demandes', data: r.parHeure.map((h) => h.demandes), backgroundColor: '#14213d' }] }, options: { plugins: { legend: { display: false } }, scales: { y: { beginAtZero: true, ticks: { precision: 0 } } } } }));
  graphiques.push(new Chart(document.getElementById('gMontant'), { type: 'line', data: { labels: jours, datasets: [{ label: 'DH', data: r.parJour.map((j) => j.montant), borderColor: '#006233', backgroundColor: 'rgba(0,98,51,.1)', fill: true, tension: .3 }] }, options: { plugins: { legend: { display: false } }, scales: { y: { beginAtZero: true } } } }));
  graphiques.push(new Chart(document.getElementById('gModes'), { type: 'doughnut', data: { labels: Object.keys(r.modes).map((k) => MODES[k] || k), datasets: [{ data: Object.values(r.modes), backgroundColor: ['#006233', '#c1272d', '#14213d'] }] } }));
  graphiques.push(new Chart(document.getElementById('gSources'), { type: 'doughnut', data: { labels: ['Application', 'WhatsApp'], datasets: [{ data: [r.sources.app, r.sources.whatsapp], backgroundColor: ['#b8892b', '#128c7e'] }] } }));
}

// ---------------- Plaintes & SOS ----------------
async function plaintes() {
  const liste = await api('plaintes');
  C().innerHTML = '<h2>Plaintes & SOS</h2><p class="sous">' + liste.filter((p) => p.statut !== 'traitee').length + ' plainte(s) à traiter' +
    (sos ? ' · <a href="' + sos + '" target="_blank">Ouvrir le centre de sécurité SOS (vidéos en direct)</a>' : '') + '</p>' +
    '<div class="carte tableau">' + (liste.length ? '<table><tr><th>Date</th><th>Motif</th><th>Message</th><th>Taxi</th><th>Statut</th><th></th></tr>' +
      liste.map((p) => '<tr><td>' + date(p.creeLe) + '</td><td>' + esc(MOTIFS[p.motif] || p.motif) + '</td><td>' + esc(p.message || '') + (p.reponse ? '<br><span class="note">Réponse : ' + esc(p.reponse) + '</span>' : '') + '</td><td>' + esc(p.taxiId || '') + '</td><td>' + tag(p.statut) + '</td><td>' +
        '<select data-id="' + esc(p.id) + '" style="width:auto"><option value="">Changer…</option><option value="en_cours">En cours</option><option value="traitee">Traitée</option><option value="recue">Reçue</option></select></td></tr>').join('') + '</table>' : '<p class="vide">Aucune plainte.</p>') + '</div>';
  document.querySelectorAll('select[data-id]').forEach((s) => s.onchange = async () => {
    if (!s.value) return;
    const reponse = s.value === 'traitee' ? (prompt('Réponse ou suite donnée (facultatif) :') || undefined) : undefined;
    try { await poster('plaintes/' + encodeURIComponent(s.dataset.id), { statut: s.value, reponse }); plaintes(); } catch (e) { alert('Erreur : ' + e.message); }
  });
}

function ouvrirTiroir(html) {
  const t = document.getElementById('tiroir');
  t.innerHTML = '<button class="btn sec" style="float:right" id="fermer">Fermer</button>' + html;
  t.classList.add('ouvert'); document.getElementById('voile').classList.add('ouvert');
  document.getElementById('fermer').onclick = fermerTiroir;
}
function fermerTiroir() { document.getElementById('tiroir').classList.remove('ouvert'); document.getElementById('voile').classList.remove('ouvert'); }
document.getElementById('voile').onclick = fermerTiroir;

if (CLE) demarrer().catch(() => deconnexion());
</script>
</body>
</html>`;
