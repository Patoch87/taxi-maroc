"""Montage d'une vidéo « fonctionnalité » Bab Taxi à partir d'un enregistrement (record_fonctions.js ou console.js).

Format « telephone » : 1080 x 1920 (portrait, WhatsApp / réseaux), titre en haut, écran du téléphone Samsung
(barres d'état et de navigation) au centre, légende en bas.
Format « bureau » : 1920 x 1080 (paysage), titre en haut, fenêtre de navigateur, légende en bas.

Chaque légende peut avoir une voix (voix/<clé>.mp3, clé = empreinte du texte, produite par voix_fonctions.py) :
l'image se fige le temps que la phrase se termine. Sans voix : légendes seules.

Usage : python3 compose_fonction.py <dossier> <sortie.mp4> [--voix <dossier des voix>] [--format telephone|bureau]
Le dossier contient frames/, marks.json (images, légendes, passages coupés, « titre », « sousTitre »).
"""
import argparse
import hashlib
import html
import json
import os
import subprocess
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ap = argparse.ArgumentParser()
ap.add_argument('dossier')
ap.add_argument('sortie')
ap.add_argument('--voix')
ap.add_argument('--format', default='telephone')
A = ap.parse_args()
TEL = A.format == 'telephone'
W, H = (1080, 1920) if TEL else (1920, 1080)

marks = json.load(open(os.path.join(A.dossier, 'marks.json')))
titre = marks.get('titre', 'Bab Taxi')
sous_titre = marks.get('sousTitre', '')


def cle_voix(texte):
    # Même clé que voix_fonctions.py (« v2 » : voix refaites phrase par phrase).
    return hashlib.sha1(('v2|' + texte.strip()).encode()).hexdigest()[:16]


def duree(p):
    r = subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', p],
                       capture_output=True, text=True)
    return float(r.stdout.strip() or 0)


# ---------------------------------------------------------------- chronologie
duration = marks['duration']
skips = sorted((s['start'], s['end']) for s in marks['skips'] if s['end'] - s['start'] > 0.05)


def coupe(t):
    return any(s <= t < e for s, e in skips)


def garde_avant(t):
    return t - sum(max(0.0, min(e, t) - s) for s, e in skips if s < t)


frames = [f for f in sorted(marks['frames'], key=lambda f: f['t']) if not coupe(f['t'])]
if not frames:
    raise SystemExit('aucune image')
# Durée de chaque image dans la vidéo.
durs = []
for i, f in enumerate(frames):
    fin = frames[i + 1]['t'] if i + 1 < len(frames) else duration
    durs.append(max(0.0, garde_avant(min(fin, duration)) - garde_avant(f['t'])))

# Légendes : intervalle en images ; voix éventuelle ; l'image se fige si la voix est plus longue.
caps = []
for c in marks['captions']:
    if not c.get('text'):
        continue
    a, b = c['start'], c.get('end', duration)
    idx = [i for i, f in enumerate(frames) if a <= f['t'] < b]
    if not idx:
        continue
    voix = None
    # Pas de narration sur une légende pendant laquelle un vocal (WhatsApp) est joué : les deux voix se couvriraient.
    son_dedans = any(a <= so['t'] < b for so in marks.get('sons', []))
    if A.voix and not marks.get('sansNarration') and not son_dedans:
        p = os.path.join(A.voix, cle_voix(c['text']) + '.mp3')
        if os.path.exists(p):
            voix = p
    caps.append(dict(texte=c['text'], i0=idx[0], i1=idx[-1], voix=voix, dv=duree(voix) if voix else 0))

debut = lambda i: sum(durs[:i])  # noqa: E731
for c in caps:
    besoin = c['dv'] + 0.8 if c['voix'] else 2.2  # temps de lecture minimal d'une légende
    dispo = debut(c['i1'] + 1) - debut(c['i0'])
    if besoin > dispo:
        durs[c['i1']] += besoin - dispo
for c in caps:
    c['t0'], c['t1'] = debut(c['i0']), debut(c['i1'] + 1)
INTRO, OUTRO = 2.6, 2.4
total_app = sum(durs)

# ---------------------------------------------------------------- images fixes (HTML -> PNG)
tmp = tempfile.mkdtemp(prefix='fonction-')
FONTS = os.path.join(HERE, 'fonts')
LOGO = ('<svg viewBox="0 0 100 100" width="{s}" height="{s}"><path d="M22 94 V52 C22 22 36 10 50 10 C64 10 78 22 78 52 V94 Z" fill="#C1272D"/>'
        '<path d="M31 94 V54 C31 31 40 21 50 21 C60 21 69 31 69 54 V94 Z" fill="#F3EAD7"/><path d="M44 94 L48.5 40 H51.5 L56 94 Z" fill="#0F2A1E"/>'
        '<rect x="44" y="2" width="12" height="12" fill="#006233" transform="rotate(45 50 8)"/></svg>')
CSS = f'''@font-face{{font-family:Cairo;font-weight:600;src:url(file://{FONTS}/cairo-latin-600-normal.woff2)}}
@font-face{{font-family:Cairo;font-weight:700;src:url(file://{FONTS}/cairo-latin-700-normal.woff2)}}
@font-face{{font-family:Cairo;font-weight:800;src:url(file://{FONTS}/cairo-latin-800-normal.woff2)}}
*{{margin:0;padding:0;box-sizing:border-box}}body{{width:{W}px;height:{H}px;font-family:Cairo,sans-serif;overflow:hidden;background:transparent}}'''
# Zone de l'écran filmé dans l'image finale.
if TEL:
    SX, SY, SW, SH = 172, 230, 736, 1590   # écran du téléphone (barre d'état + application + navigation)
else:
    SX, SY, SW, SH = 150, 132, 1620, 830   # contenu de la fenêtre du navigateur
ZELLIGE = ("background-color:#F7F1E3;background-image:radial-gradient(circle at 25% 25%,rgba(0,98,51,.07) 2px,transparent 3px),"
           "radial-gradient(circle at 75% 75%,rgba(193,39,45,.06) 2px,transparent 3px);background-size:44px 44px")
if TEL:
    fond = f'''<div style="position:absolute;inset:0;{ZELLIGE}"></div>
<div style="position:absolute;left:0;right:0;top:0;height:200px;display:flex;align-items:center;gap:22px;padding:0 60px">
{LOGO.format(s=86)}<div><div style="font-size:30px;font-weight:700;color:#006233;letter-spacing:.06em">BAB TAXI · DÉMO</div>
<div style="font-size:{56 if len(titre) < 26 else 46}px;font-weight:800;color:#14213d;line-height:1.1">{html.escape(titre)}</div></div></div>
<div style="position:absolute;left:{SX - 18}px;top:{SY - 18}px;width:{SW + 36}px;height:{SH + 36}px;border-radius:64px;background:#111;
box-shadow:0 30px 60px rgba(20,33,61,.35)"></div>'''
else:
    fond = f'''<div style="position:absolute;inset:0;{ZELLIGE}"></div>
<div style="position:absolute;left:150px;top:22px;display:flex;align-items:center;gap:16px">{LOGO.format(s=58)}
<div style="font-size:24px;font-weight:700;color:#006233;letter-spacing:.06em">BAB TAXI · CONSOLE</div>
<div style="font-size:40px;font-weight:800;color:#14213d;margin-left:14px">{html.escape(titre)}</div></div>
<div style="position:absolute;left:{SX}px;top:{SY - 38}px;width:{SW}px;height:{SH + 38}px;border-radius:14px;background:#e9e4da;
box-shadow:0 24px 50px rgba(20,33,61,.3);overflow:hidden"><div style="height:38px;display:flex;align-items:center;gap:9px;padding:0 16px">
<i style="width:13px;height:13px;border-radius:50%;background:#ff5f57"></i><i style="width:13px;height:13px;border-radius:50%;background:#febc2e"></i>
<i style="width:13px;height:13px;border-radius:50%;background:#28c840"></i><span style="margin-left:18px;font:16px sans-serif;color:#666;
background:#fff;border-radius:7px;padding:3px 14px">bab-taxi-eu.onrender.com/admin</span></div></div>'''
pages = [dict(fichier='fond.png', html=fond)]
for i, c in enumerate(caps):
    taille = 46 if TEL else 38
    if len(c['texte']) > (60 if TEL else 90):
        taille = 40 if TEL else 34
    if TEL:
        boite = f'left:50px;right:50px;bottom:28px;min-height:150px'
    else:
        boite = f'left:50%;transform:translateX(-50%);bottom:18px;max-width:1500px'
    pages.append(dict(fichier=f'leg{i}.png', html=f'''<div style="position:absolute;{boite};background:#fff;border-radius:30px;
border-left:12px solid #006233;box-shadow:0 14px 34px rgba(20,33,61,.22);padding:22px 34px;display:flex;align-items:center">
<div style="font-size:{taille}px;font-weight:700;color:#14213d;line-height:1.22">{html.escape(c["texte"])}</div></div>'''))
carte = lambda grand, petit: f'''<div style="position:absolute;inset:0;background:#006233;display:flex;flex-direction:column;align-items:center;
justify-content:center;gap:{30 if TEL else 20}px;color:#fff;text-align:center;padding:60px">
<div style="background:#F3EAD7;border-radius:50%;padding:26px;display:flex">{LOGO.format(s=150 if TEL else 110)}</div>
<div style="font-size:{72 if TEL else 64}px;font-weight:800;line-height:1.1">{html.escape(grand)}</div>
<div style="font-size:{40 if TEL else 34}px;font-weight:600;opacity:.92;max-width:900px">{html.escape(petit)}</div></div>'''  # noqa: E731
pages.append(dict(fichier='intro.png', html=carte(titre, sous_titre)))
pages.append(dict(fichier='fin.png', html=carte('Bab Taxi', marks.get('fin', 'Le taxi marocain, simple, juste et sûr'))))
for p in pages:
    p['html'] = f'<!doctype html><html><head><meta charset="utf-8"><style>{CSS}</style></head><body>{p["html"]}</body></html>'
json.dump(dict(largeur=W, hauteur=H, dossier=tmp, pages=pages), open(os.path.join(tmp, 'pages.json'), 'w'))
subprocess.run(['node', os.path.join(HERE, 'rendu_pages.js'), os.path.join(tmp, 'pages.json')], check=True)

# ---------------------------------------------------------------- flux de l'application
lignes = []
for f, d in zip(frames, durs):
    if d > 0:
        lignes.append(f"file '{os.path.abspath(os.path.join(A.dossier, 'frames', f['file']))}'\nduration {d:.4f}")
lignes.append(lignes[-1].split('\n')[0])
concat = os.path.join(tmp, 'frames.txt')
open(concat, 'w').write('\n'.join(lignes) + '\n')

entrees = ['-f', 'concat', '-safe', '0', '-i', concat, '-loop', '1', '-i', os.path.join(tmp, 'fond.png')]
n = 2
if TEL:
    entrees += ['-loop', '1', '-i', os.path.join(HERE, 'samsung', 'status.png'), '-loop', '1', '-i', os.path.join(HERE, 'samsung', 'nav.png')]
    st, nav = n, n + 1
    n += 2
    hs, hn = round(SW * 80 / 1080), round(SW * 126 / 1080)
    ha = SH - hs - hn
    fc = (f'[0:v]scale={SW}:{ha}:flags=lanczos,fps=30,setsar=1[app];[{st}:v]scale={SW}:{hs},setsar=1[st];'
          f'[{nav}:v]scale={SW}:{hn},setsar=1[nav];[st][app][nav]vstack=inputs=3:shortest=1,'
          # coins arrondis de l'écran
          f"format=yuva420p,geq=lum='p(X,Y)':a='if(gt(abs(W/2-X),W/2-46)*gt(abs(H/2-Y),H/2-46),"
          f"if(lte(hypot(46-(W/2-abs(W/2-X)),46-(H/2-abs(H/2-Y))),46),255,0),255)'[ecran];"
          f'[1:v][ecran]overlay={SX}:{SY}:shortest=1[v0];')
else:
    fc = f'[0:v]scale={SW}:{SH}:flags=lanczos,fps=30,setsar=1[ecran];[1:v][ecran]overlay={SX}:{SY}:shortest=1[v0];'
cur = 'v0'
for i, c in enumerate(caps):
    entrees += ['-loop', '1', '-i', os.path.join(tmp, f'leg{i}.png')]
    fc += f"[{cur}][{n}:v]overlay=0:0:enable='between(t,{c['t0']:.3f},{c['t1'] - 0.04:.3f})'[v{i + 1}];"
    cur = f'v{i + 1}'
    n += 1
fc += f'[{cur}]trim=duration={total_app:.3f},format=yuv420p[corps]'
corps = os.path.join(tmp, 'corps.mp4')
subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', *entrees, '-filter_complex', fc, '-map', '[corps]', '-r', '30',
                '-c:v', 'libx264', '-preset', 'medium', '-crf', '20', corps], check=True)


# ---------------------------------------------------------------- cartes d'ouverture et de fin, voix, assemblage
def fixe(png, d, sortie):
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-loop', '1', '-i', png, '-t', f'{d}', '-r', '30',
                    '-vf', 'format=yuv420p', '-c:v', 'libx264', '-preset', 'medium', '-crf', '20', sortie], check=True)


fixe(os.path.join(tmp, 'intro.png'), INTRO, os.path.join(tmp, 'intro.mp4'))
fixe(os.path.join(tmp, 'fin.png'), OUTRO, os.path.join(tmp, 'fin.mp4'))
total = INTRO + total_app + OUTRO
fc = ('[0:v][1:v]xfade=transition=fade:duration=0.5:offset={a:.3f}[x1];[x1][2:v]xfade=transition=fade:duration=0.5:offset={b:.3f}[v]'
      .format(a=INTRO - 0.5, b=INTRO - 0.5 + total_app - 0.5))
entrees = ['-i', os.path.join(tmp, 'intro.mp4'), '-i', corps, '-i', os.path.join(tmp, 'fin.mp4')]
# Voix : chaque phrase commence avec sa légende (décalage de l'ouverture, moins le fondu).
# Sons de l'enregistrement (« sons » : vocaux WhatsApp...) : placés à l'heure de l'image correspondante.
def sortie_de(t):
    i = next((k for k, f in enumerate(frames) if f['t'] >= t), len(frames) - 1)
    return debut(i)


pistes = [(c['voix'], c['t0'] + 0.15) for c in caps if c['voix']]
for s in marks.get('sons', []):
    f = s['file'] if os.path.isabs(s['file']) else os.path.join(A.dossier, s['file'])
    if os.path.exists(f) and not coupe(s['t']):
        pistes.append((f, sortie_de(s['t'])))
voix = pistes
base = INTRO - 0.5
for f, _ in voix:
    entrees += ['-i', f]
if voix:
    for k, (_, t) in enumerate(voix):
        ms = int((base + t) * 1000)
        f = voix[k][0]
        d = duree(f)
        # Fondus très courts aux bords : jamais de claquement à l'entrée ou à la sortie d'une phrase.
        fc += (f';[{3 + k}:a]aresample=44100,afade=t=in:d=0.03,afade=t=out:st={max(0, d - 0.06):.3f}:d=0.06,'
               f'adelay={ms}|{ms},apad[a{k}]')
    fc += ';' + ''.join(f'[a{k}]' for k in range(len(voix))) + f'amix=inputs={len(voix)}:normalize=0,atrim=duration={total - 1:.3f}[a]'
    carte_audio = ['-map', '[a]', '-c:a', 'aac', '-b:a', '160k']
else:
    carte_audio = ['-an']
subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', *entrees, '-filter_complex', fc, '-map', '[v]', *carte_audio,
                '-c:v', 'libx264', '-preset', 'slow', '-crf', '21', '-movflags', '+faststart', A.sortie], check=True)
print(f'{A.sortie} : {total - 1:.1f} s, {len(caps)} légendes, {len(voix)} sons, {os.path.getsize(A.sortie) / 1e6:.1f} Mo')
