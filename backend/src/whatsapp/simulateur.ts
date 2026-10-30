/** Simulateur de conversation WhatsApp avec l'agent Bab Taxi (page servie par /whatsapp/demo). */
export const SIMULATEUR = `<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Bab Taxi WhatsApp</title>
<style>
:root { --vert: #006233; --rouge: #C1272D; --fond: #EFE7DD; --bulle: #FFFFFF; --moi: #D9FDD3; --texte: #111B21; --gris: #667781; }
* { box-sizing: border-box; }
body { margin: 0; font: 16px/1.4 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; background: #d1d7db; color: var(--texte); }
.app { max-width: 480px; height: 100dvh; margin: 0 auto; display: flex; flex-direction: column; background: var(--fond); }
header { background: var(--vert); color: #fff; padding: 10px 16px; display: flex; align-items: center; gap: 12px; }
.logo { width: 40px; height: 40px; border-radius: 50%; background: #F3EAD7; display: grid; place-items: center; flex: none; }
header h1 { font-size: 17px; margin: 0; }
header small { opacity: .85; font-size: 12px; }
#fil { flex: 1; overflow-y: auto; padding: 12px 12px 4px; display: flex; flex-direction: column; gap: 6px; }
.b { max-width: 85%; padding: 7px 10px; border-radius: 8px; background: var(--bulle); box-shadow: 0 1px .5px rgba(0,0,0,.13); white-space: pre-wrap; word-wrap: break-word; }
.b.moi { align-self: flex-end; background: var(--moi); }
.b.info { align-self: center; background: #FFF3C4; font-size: 13px; color: #54656f; text-align: center; }
.b audio { display: block; width: 240px; max-width: 100%; margin-bottom: 4px; }
.b .t { font-size: 12px; color: var(--gris); }
[dir=auto] { unicode-bidi: plaintext; }
.outils { display: flex; gap: 8px; padding: 6px 10px 0; overflow-x: auto; }
.outils button { flex: none; border: 0; background: #fff; border-radius: 16px; padding: 6px 12px; font: inherit; font-size: 14px; color: var(--vert); cursor: pointer; }
form { display: flex; gap: 8px; padding: 8px 10px 12px; align-items: center; }
#saisie { flex: 1; min-width: 0; border: 0; border-radius: 22px; padding: 11px 16px; font: inherit; }
.rond { width: 46px; height: 46px; border-radius: 50%; border: 0; background: var(--vert); color: #fff; font-size: 20px; cursor: pointer; flex: none; }
.rond.rec { background: var(--rouge); animation: pulse 1s infinite; }
@keyframes pulse { 50% { transform: scale(1.08); } }
</style>
</head>
<body>
<div class="app">
  <header>
    <div class="logo" aria-hidden="true">
      <svg width="26" height="26" viewBox="0 0 24 24"><path d="M4 22V11a8 8 0 0 1 16 0v11h-4v-9a4 4 0 0 0-8 0v9z" fill="#C1272D"/><path d="M12 3.5l1.6 1.6L12 6.7l-1.6-1.6z" fill="#006233"/></svg>
    </div>
    <div><h1>Bab Taxi</h1><small id="etat">Agent de commande</small></div>
  </header>
  <div id="fil" aria-live="polite"></div>
  <div class="outils">
    <button type="button" id="pos">📍 Envoyer ma position</button>
    <button type="button" id="chauffeur">🚕 Simuler le chauffeur</button>
    <button type="button" id="nouveau">↺ Nouvelle conversation</button>
  </div>
  <form id="f">
    <input id="saisie" autocomplete="off" placeholder="Message" aria-label="Message" dir="auto">
    <button class="rond" id="micro" type="button" aria-label="Enregistrer un vocal">🎤</button>
  </form>
</div>
<script>
const params = new URLSearchParams(location.search);
const cle = params.get('cle') || '';
const q = (extra) => '?cle=' + encodeURIComponent(cle) + (extra || '');
let id;
try { id = localStorage.getItem('bab-wa-id'); } catch (e) {}
if (!id) { id = 'sim' + Math.random().toString(36).slice(2, 10); try { localStorage.setItem('bab-wa-id', id); } catch (e) {} }
const fil = document.getElementById('fil');
const saisie = document.getElementById('saisie');
const micro = document.getElementById('micro');
const heure = () => new Date().toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' });

function bulle(texte, classe, audio) {
  const b = document.createElement('div');
  b.className = 'b ' + (classe || '');
  if (audio) { const a = document.createElement('audio'); a.controls = true; a.src = audio; b.appendChild(a); }
  if (texte) { const t = document.createElement('div'); t.dir = 'auto'; t.textContent = texte; b.appendChild(t); }
  const h = document.createElement('div'); h.className = 't'; h.textContent = heure(); b.appendChild(h);
  fil.appendChild(b); fil.scrollTop = fil.scrollHeight;
  return b;
}
function afficher(reponses) {
  let dernierAudio;
  for (const r of reponses || []) { const b = bulle(r.texte, '', r.audio); if (r.audio) dernierAudio = b.querySelector('audio'); }
  if (dernierAudio) dernierAudio.play().catch(() => {});
}
async function appel(url, options) {
  const r = await fetch(url, options);
  const j = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error(j.message || ('Erreur ' + r.status));
  return j;
}
async function envoyer(corps) {
  const attente = bulle('…', 'info');
  try {
    const j = await appel('/whatsapp/demo/message' + q(), { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(Object.assign({ id, nom: 'Simulateur' }, corps)) });
    attente.remove(); afficher(j.reponses);
  } catch (e) { attente.remove(); bulle(e.message, 'info'); }
}

document.getElementById('f').onsubmit = (e) => {
  e.preventDefault();
  const t = saisie.value.trim(); if (!t) return;
  saisie.value = ''; bulle(t, 'moi'); envoyer({ texte: t });
};

// Vocal : appuyer pour commencer, appuyer encore pour envoyer.
let rec, morceaux = [];
micro.onclick = async () => {
  if (rec && rec.state === 'recording') { rec.stop(); return; }
  try {
    const flux = await navigator.mediaDevices.getUserMedia({ audio: true });
    const type = ['audio/webm;codecs=opus', 'audio/ogg;codecs=opus', 'audio/mp4'].find((t) => window.MediaRecorder && MediaRecorder.isTypeSupported(t)) || '';
    rec = new MediaRecorder(flux, type ? { mimeType: type } : undefined);
    morceaux = [];
    rec.ondataavailable = (e) => morceaux.push(e.data);
    rec.onstop = async () => {
      flux.getTracks().forEach((t) => t.stop());
      micro.classList.remove('rec'); micro.textContent = '🎤';
      const blob = new Blob(morceaux, { type: rec.mimeType || 'audio/webm' });
      const b = bulle('', 'moi', URL.createObjectURL(blob));
      const attente = bulle('…', 'info');
      try {
        const j = await appel('/whatsapp/demo/vocal' + q('&id=' + id + '&nom=Simulateur'), { method: 'POST', headers: { 'content-type': blob.type }, body: blob });
        attente.remove();
        if (j.transcription) { const t = document.createElement('div'); t.dir = 'auto'; t.style.fontStyle = 'italic'; t.textContent = '« ' + j.transcription + ' »'; b.insertBefore(t, b.lastChild); }
        afficher(j.reponses);
      } catch (e) { attente.remove(); bulle(e.message, 'info'); }
    };
    rec.start(); micro.classList.add('rec'); micro.textContent = '■';
  } catch (e) { bulle("Micro indisponible : écrivez votre message.", 'info'); }
};

// Position : celle du téléphone si elle est à Casablanca, sinon un point de démonstration (Maârif).
document.getElementById('pos').onclick = () => {
  const demo = () => { bulle('📍 Position de démonstration : Maârif, Casablanca', 'moi'); envoyer({ position: { lat: 33.5850, lng: -7.6330, nom: 'Maârif' } }); };
  if (!navigator.geolocation) return demo();
  navigator.geolocation.getCurrentPosition((p) => {
    const { latitude: lat, longitude: lng } = p.coords;
    if (Math.abs(lat - 33.57) > 0.4 || Math.abs(lng + 7.6) > 0.4) return demo();
    bulle('📍 Ma position', 'moi'); envoyer({ position: { lat, lng } });
  }, demo, { timeout: 8000 });
};

document.getElementById('chauffeur').onclick = async () => {
  try {
    const j = await appel('/whatsapp/demo/chauffeur' + q(), { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ id }) });
    bulle({ acceptee: 'Chauffeur : course acceptée', a_bord: 'Chauffeur : passager à bord', terminee: 'Chauffeur : passager déposé' }[j.statut] || ('Course : ' + j.statut), 'info');
    setTimeout(relever, 300);
  } catch (e) { bulle(e.message, 'info'); }
};

document.getElementById('nouveau').onclick = () => {
  id = 'sim' + Math.random().toString(36).slice(2, 10);
  try { localStorage.setItem('bab-wa-id', id); } catch (e) {}
  fil.innerHTML = '';
  accueil();
};

async function relever() {
  try { afficher(await appel('/whatsapp/demo/boite' + q('&id=' + id))); } catch (e) {}
}
setInterval(relever, 3000);

function accueil() {
  bulle('Écrivez ou envoyez un vocal comme sur WhatsApp, en français ou en darija. Exemple : « Bghit nmchi l Maarif ».', 'info');
}
appel('/whatsapp/etat').then((e) => {
  document.getElementById('etat').textContent = (e.agent === 'claude' ? 'Agent IA Claude' : 'Agent de démonstration (sans IA)') + (e.voix ? ' · voix active' : ' · sans voix');
}).catch(() => {});
accueil();
</script>
</body>
</html>`;
