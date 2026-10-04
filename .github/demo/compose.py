"""Montage de la vidéo de démo : légendes en bas (bandeau vert, texte crème), passages d'attente coupés,
durée ramenée à 2 min 30 au plus, MP4 H.264 720 x 1280.

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
MAX_S = 150.0

duration = marks['duration']
skips = [s for s in marks['skips'] if s['end'] - s['start'] > 0.5]
kept = duration - sum(s['end'] - s['start'] for s in skips)
# Vitesse globale si la vidéo dépasse 2 min 30.
speed = max(1.0, kept / MAX_S)

filters = [
    f'fps=25,pad={W}:{APP_H + BAR_H}:0:0:color=0x006233',
    f'drawbox=x=0:y={APP_H}:w={W}:h=6:color=0xC1272D:t=fill',
]
for i, c in enumerate(marks['captions']):
    end = c.get('end', duration)
    if end - c['start'] < 0.3:
        continue
    lines = textwrap.wrap(c['text'], 30)[:2]
    path = os.path.join(folder, f'caption{i}.txt')
    with open(path, 'w') as f:
        f.write('\n'.join(lines))
    size = 38 if len(lines) == 1 else 33
    filters.append(
        f"drawtext=fontfile={FONT}:textfile={path}:fontsize={size}:fontcolor=0xFFF8E7:line_spacing=6:"
        f"x=(w-text_w)/2:y={APP_H + 6}+({BAR_H - 6}-text_h)/2:enable='between(t,{c['start']:.2f},{end:.2f})'"
    )
if skips:
    cond = '+'.join(f"between(t,{s['start']:.2f},{s['end']:.2f})" for s in skips)
    filters.append(f"select='not({cond})'")
filters.append(f'setpts=N/25/TB*{1 / speed:.4f}' if speed > 1 else 'setpts=N/25/TB')

cmd = [
    'ffmpeg', '-y', '-i', os.path.join(folder, 'raw.webm'),
    '-vf', ','.join(filters), '-an', '-r', '25',
    '-c:v', 'libx264', '-preset', 'slow', '-crf', '26', '-pix_fmt', 'yuv420p', '-movflags', '+faststart',
    output,
]
subprocess.run(cmd, check=True)
size = os.path.getsize(output) / 1e6
print(f'vidéo : {kept / speed:.1f} s, vitesse ×{speed:.2f}, {size:.1f} Mo')
if size > 30:
    sys.exit('vidéo trop lourde (> 30 Mo)')
