"""Montage de la vidéo de démo : images de l'application (720 x 1170) en plein cadre, légende en bas
(bandeau vert de 110 px, filet rouge, texte crème), passages d'attente coupés, durée ramenée à
3 min 05 au plus, MP4 H.264 720 x 1280.

Usage : python3 compose.py <dossier> <sortie.mp4>
"""
import json
import os
import subprocess
import sys
import textwrap

folder, output = sys.argv[1], sys.argv[2]
marks = json.load(open(os.path.join(folder, 'marks.json')))
FONT = '/usr/share/fonts/truetype/noto/NotoSans-Bold.ttf'
APP_H, BAR_H, W = 1170, 110, 720
MAX_S = 185.0

duration = marks['duration']
skips = sorted((s['start'], s['end']) for s in marks['skips'] if s['end'] - s['start'] > 0.3)
frames = sorted(marks['frames'], key=lambda f: f['t'])
if not frames:
    sys.exit('aucune image enregistrée')


def kept_before(t):
    """Temps conservé (hors passages coupés) entre 0 et t."""
    cut = sum(max(0.0, min(e, t) - s) for s, e in skips if s < t)
    return t - cut


kept = kept_before(duration)
speed = max(1.0, kept / MAX_S)  # vitesse globale si la vidéo dépasse 3 min 05
out_t = lambda t: kept_before(t) / speed  # noqa: E731

# Liste d'images avec leur durée à l'écran (format concat de ffmpeg).
lines, total = [], 0.0
for i, f in enumerate(frames):
    start = max(0.0, f['t'])
    end = frames[i + 1]['t'] if i + 1 < len(frames) else duration
    d = out_t(min(end, duration)) - out_t(min(start, duration))
    if d <= 0:
        continue
    lines.append(f"file '{os.path.abspath(os.path.join(folder, 'frames', f['file']))}'\nduration {d:.4f}")
    total += d
lines.append(lines[-1].split('\n')[0])  # la dernière image doit être répétée pour garder sa durée
concat = os.path.join(folder, 'frames.txt')
open(concat, 'w').write('\n'.join(lines) + '\n')

filters = [
    f'scale={W}:{APP_H}:force_original_aspect_ratio=decrease,pad={W}:{APP_H}:(ow-iw)/2:0:color=0xFFF8E7',
    'fps=25',
    f'pad={W}:{APP_H + BAR_H}:0:0:color=0x006233',
    f'drawbox=x=0:y={APP_H}:w={W}:h=6:color=0xC1272D:t=fill',
]
for i, c in enumerate(marks['captions']):
    start, end = out_t(c['start']), out_t(c.get('end', duration))
    if end - start < 0.3:
        continue
    text = textwrap.wrap(c['text'], 30)[:2]
    path = os.path.join(folder, f'caption{i}.txt')
    with open(path, 'w') as f:
        f.write('\n'.join(text))
    size = 38 if len(text) == 1 else 33
    filters.append(
        f"drawtext=fontfile={FONT}:expansion=none:textfile={path}:fontsize={size}:fontcolor=0xFFF8E7:line_spacing=6:"
        f"x=(w-text_w)/2:y={APP_H + 6}+({BAR_H - 6}-text_h)/2:enable='between(t,{start:.2f},{end:.2f})'"
    )

cmd = [
    'ffmpeg', '-y', '-loglevel', 'error', '-f', 'concat', '-safe', '0', '-i', concat,
    '-vf', ','.join(filters), '-an', '-r', '25',
    '-c:v', 'libx264', '-preset', 'slow', '-crf', '21', '-pix_fmt', 'yuv420p', '-movflags', '+faststart',
    output,
]
subprocess.run(cmd, check=True)
size = os.path.getsize(output) / 1e6
print(f'vidéo : {total:.1f} s, vitesse ×{speed:.2f}, {size:.1f} Mo, {len(frames)} images')
if size > 30:
    sys.exit('vidéo trop lourde (> 30 Mo)')
if not 60 <= total <= 190:
    sys.exit(f'durée inattendue ({total:.0f} s)')
