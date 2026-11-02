/** Page de Bab Taxi pour vérifier les dossiers des chauffeurs : /admin/chauffeurs?cle=… */
export const PAGE_DOSSIERS = `<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Dossiers chauffeurs · Bab Taxi</title>
<style>
  :root { --sable:#f7f1e3; --vert:#006233; --rouge:#c1272d; --encre:#0f2a1e; --gris:#6b6b6b; }
  * { box-sizing: border-box; }
  body { margin:0; font-family: system-ui, -apple-system, Segoe UI, Roboto, sans-serif; background: var(--sable); color: var(--encre); }
  header { background: var(--encre); color: #fff; padding: 16px; position: sticky; top: 0; z-index: 2; }
  header h1 { margin: 0; font-size: 20px; }
  header p { margin: 4px 0 0; opacity: .8; font-size: 14px; }
  .filtres { display: flex; gap: 8px; padding: 12px 16px 0; flex-wrap: wrap; }
  .filtres button { border: 1.5px solid var(--encre); background: #fff; border-radius: 99px; padding: 6px 14px; font-weight: 600; cursor: pointer; }
  .filtres button.actif { background: var(--encre); color: #fff; }
  main { padding: 16px; display: grid; gap: 16px; max-width: 1100px; margin: 0 auto; }
  .carte { background: #fff; border-radius: 16px; padding: 16px; box-shadow: 0 2px 8px rgba(0,0,0,.06); }
  .tete { display: flex; gap: 14px; align-items: center; }
  .tete img { width: 72px; height: 72px; border-radius: 50%; object-fit: cover; background: #eee; }
  .tete h2 { margin: 0; font-size: 18px; }
  .statut { display: inline-block; padding: 3px 10px; border-radius: 99px; font-size: 13px; font-weight: 700; }
  .en_attente { background: #fff3cd; color: #7a5b00; }
  .valide { background: #d6eadb; color: var(--vert); }
  .refuse { background: #f6d9d3; color: var(--rouge); }
  dl { display: grid; grid-template-columns: max-content 1fr; gap: 4px 12px; margin: 12px 0; font-size: 14px; }
  dt { color: var(--gris); }
  dd { margin: 0; font-weight: 600; }
  .pieces { display: grid; grid-template-columns: repeat(auto-fill, minmax(140px, 1fr)); gap: 10px; }
  .pieces a { display: block; text-decoration: none; color: var(--encre); font-size: 13px; font-weight: 600; }
  .pieces img { width: 100%; height: 110px; object-fit: cover; border-radius: 10px; background: #eee; display: block; margin-bottom: 4px; }
  .actions { display: flex; gap: 10px; margin-top: 14px; flex-wrap: wrap; }
  .actions button { border: 0; border-radius: 12px; padding: 12px 18px; font-weight: 700; font-size: 15px; cursor: pointer; }
  .ok { background: var(--vert); color: #fff; }
  .non { background: #fff; color: var(--rouge); border: 1.5px solid var(--rouge) !important; }
  .motif { color: var(--rouge); font-size: 14px; margin-top: 8px; }
  .vide { text-align: center; color: var(--gris); padding: 40px 0; }
</style>
</head>
<body>
<header>
  <h1>Dossiers chauffeurs</h1>
  <p>Vérifiez chaque pièce (CIN, permis, carte professionnelle, casier judiciaire, taxi) avant de valider. Documents confidentiels (loi 09-08).</p>
</header>
<div class="filtres">
  <button data-f="en_attente" class="actif">À vérifier</button>
  <button data-f="valide">Validés</button>
  <button data-f="refuse">Refusés</button>
  <button data-f="">Tous</button>
</div>
<main id="liste"><p class="vide">Chargement…</p></main>
<script>
const cle = new URLSearchParams(location.search).get('cle') || '';
const NOMS = { photo: 'Photo du chauffeur', cinRecto: 'CIN recto', cinVerso: 'CIN verso', permis: 'Permis de conduire', cartePro: 'Carte professionnelle', casier: 'Casier judiciaire', vehicule: 'Photo du taxi' };
const STATUTS = { en_attente: 'À vérifier', valide: 'Validé', refuse: 'Refusé' };
let filtre = 'en_attente', dossiers = [];
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const fichier = (id) => '/admin/fichiers/' + encodeURIComponent(id) + '?cle=' + encodeURIComponent(cle);

async function charger() {
  const r = await fetch('/admin/chauffeurs.json?cle=' + encodeURIComponent(cle));
  if (!r.ok) { document.getElementById('liste').innerHTML = '<p class="vide">Clé invalide.</p>'; return; }
  dossiers = await r.json();
  afficher();
}

function afficher() {
  const l = dossiers.filter((d) => !filtre || d.statut === filtre);
  const el = document.getElementById('liste');
  if (!l.length) { el.innerHTML = '<p class="vide">Aucun dossier.</p>'; return; }
  el.innerHTML = l.map((d) => {
    const photo = (d.pieces.find((p) => p[0] === 'photo') || [])[1];
    return '<section class="carte">' +
      '<div class="tete">' + (photo ? '<img src="' + fichier(photo) + '" alt="">' : '') +
      '<div><h2>' + esc(d.prenom) + ' ' + esc(d.nom) + '</h2>' +
      '<span class="statut ' + d.statut + '">' + STATUTS[d.statut] + '</span></div></div>' +
      '<dl>' +
      '<dt>Téléphone</dt><dd>+' + esc(d.telephone) + '</dd>' +
      '<dt>Ville</dt><dd>' + esc(d.ville) + '</dd>' +
      '<dt>CIN</dt><dd>' + esc(d.cin) + '</dd>' +
      '<dt>Permis</dt><dd>' + esc(d.permis) + '</dd>' +
      '<dt>Carte pro</dt><dd>' + esc(d.cartePro) + '</dd>' +
      '<dt>Taxi</dt><dd>' + (d.taxiType === 'grand' ? 'Grand' : 'Petit') + ' taxi n° ' + esc(d.taxiNumero) + ' · ' + esc(d.plaque) + '</dd>' +
      '<dt>Langues</dt><dd>' + esc((d.langues || []).join(', ') || '–') + '</dd>' +
      '<dt>Envoyé le</dt><dd>' + new Date(d.envoyeLe).toLocaleString('fr-FR') + '</dd>' +
      '</dl>' +
      '<div class="pieces">' + d.pieces.filter((p) => p[1]).map((p) =>
        '<a href="' + fichier(p[1]) + '" target="_blank" rel="noopener"><img loading="lazy" src="' + fichier(p[1]) + '" alt="">' + NOMS[p[0]] + '</a>').join('') + '</div>' +
      (d.motif ? '<p class="motif">Motif du refus : ' + esc(d.motif) + '</p>' : '') +
      '<div class="actions">' +
      (d.statut !== 'valide' ? '<button class="ok" data-id="' + esc(d.id) + '" data-d="valide">Valider le chauffeur</button>' : '') +
      (d.statut !== 'refuse' ? '<button class="non" data-id="' + esc(d.id) + '" data-d="refuse">Refuser</button>' : '') +
      '</div></section>';
  }).join('');
}

document.addEventListener('click', async (e) => {
  const f = e.target.closest('.filtres button');
  if (f) {
    filtre = f.dataset.f;
    document.querySelectorAll('.filtres button').forEach((b) => b.classList.toggle('actif', b === f));
    return afficher();
  }
  const b = e.target.closest('.actions button');
  if (!b) return;
  let motif = '';
  if (b.dataset.d === 'refuse') {
    motif = prompt('Motif du refus (montré au chauffeur) :', 'Photo du casier judiciaire illisible');
    if (!motif) return;
  } else if (!confirm('Valider ce chauffeur ? Il pourra recevoir des courses.')) return;
  b.disabled = true;
  const r = await fetch('/admin/chauffeurs/' + encodeURIComponent(b.dataset.id) + '/decision?cle=' + encodeURIComponent(cle), {
    method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ decision: b.dataset.d, motif }),
  });
  if (!r.ok) alert('Erreur : ' + (await r.text()));
  charger();
});

charger();
setInterval(charger, 30000);
</script>
</body>
</html>`;
