// Enregistrement image par image d'une page Playwright (captures DevTools ~15 par seconde, horodatées),
// avec légendes et passages coupés. Partagé par record_fonctions.js (application) et console.js (console).
// Résultat : <dossier>/frames/*.jpg et <dossier>/marks.json, monté par compose_fonction.py.
const fs = require('fs');
const path = require('path');

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// Points de toucher (comme « Afficher les appuis » d'Android) ou curseur de souris (console).
function pointeur(curseur) {
  return `(() => {
    let dot = null;
    const CURSEUR = ${curseur ? 'true' : 'false'};
    const show = (e, down) => {
      if (!dot) {
        dot = document.createElement('div');
        dot.style.cssText = CURSEUR
          ? 'position:fixed;width:26px;height:26px;margin:-3px 0 0 -5px;pointer-events:none;z-index:2147483647;transition:transform .12s;' +
            'background:url("data:image/svg+xml,' + encodeURIComponent('<svg xmlns=\\'http://www.w3.org/2000/svg\\' viewBox=\\'0 0 24 24\\'><path d=\\'M3 2l7 19 2.6-7.6L20 11z\\' fill=\\'%23111\\' stroke=\\'white\\' stroke-width=\\'1.6\\'/></svg>') + '") no-repeat'
          : 'position:fixed;width:40px;height:40px;margin:-20px 0 0 -20px;border-radius:50%;pointer-events:none;' +
            'z-index:2147483647;background:rgba(255,255,255,.6);border:1.5px solid rgba(0,0,0,.28);transition:opacity .15s';
        document.documentElement.appendChild(dot);
      }
      dot.style.opacity = '1';
      dot.style.left = e.clientX + 'px';
      dot.style.top = e.clientY + 'px';
      if (CURSEUR) dot.style.transform = down ? 'scale(.82)' : 'none';
    };
    addEventListener('pointerdown', (e) => show(e, true), true);
    addEventListener('pointermove', (e) => (CURSEUR || e.buttons) && show(e, e.buttons), true);
    addEventListener('pointerup', (e) => { if (!dot) return; if (CURSEUR) show(e, false); else setTimeout(() => (dot.style.opacity = '0'), 120); }, true);
  })();`;
}

async function demarrer(context, page, out, { view, dpr, curseur = false }) {
  const framesDir = path.join(out, 'frames');
  fs.mkdirSync(framesDir, { recursive: true });
  // Captures Playwright (et non DevTools avec « clip » + « scale », qui remet la page en densité 1 :
  // l'application Flutter se redessine alors en gros plan).
  let cible = page;
  const t0 = Date.now() / 1000;
  const now = () => Date.now() / 1000 - t0;
  const marks = { frames: [], captions: [], skips: [] };
  let n = 0,
    paused = false,
    running = true;
  const recorder = (async () => {
    while (running) {
      const start = Date.now();
      if (!paused) {
        try {
          const t = now();
          const data = await Promise.race([
            cible.screenshot({ type: 'jpeg', quality: 86, timeout: 2000 }),
            sleep(2000).then(() => Promise.reject(new Error('capture : délai dépassé'))),
          ]);
          const file = `f${String(n++).padStart(6, '0')}.jpg`;
          fs.writeFileSync(path.join(framesDir, file), data);
          marks.frames.push({ file, t });
        } catch (_) {
          // page en cours de chargement : image suivante
        }
      }
      await sleep(Math.max(5, 50 - (Date.now() - start)));
    }
  })();
  let current = null;
  let skipStart = null;
  return {
    now,
    marks,
    // Filme désormais une autre page (même contexte), par exemple l'application après WhatsApp.
    async changerPage(p) {
      cible = p;
    },
    caption(text) {
      if (current) current.end = now();
      current = text ? { text, start: now() } : null;
      if (current) marks.captions.push(current);
    },
    skip(on) {
      paused = on;
      if (on) skipStart ??= now();
      else if (skipStart !== null) {
        marks.skips.push({ start: skipStart, end: now() });
        skipStart = null;
      }
    },
    cutSince(from) {
      if (current) current.end = now();
      current = null;
      marks.skips.push({ start: from, end: now() });
    },
    async fin(meta = {}) {
      if (current) current.end = now();
      current = null;
      if (skipStart !== null) this.skip(false);
      marks.duration = now();
      running = false;
      await recorder;
      Object.assign(marks, meta);
      fs.writeFileSync(path.join(out, 'marks.json'), JSON.stringify(marks, null, 2));
      return marks;
    },
  };
}

module.exports = { demarrer, pointeur, sleep };
