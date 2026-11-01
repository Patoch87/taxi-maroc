"""Montage « enregistrement d'écran Samsung » : images de l'application (412 x 820 points, densité 2,625)
entre la barre d'état et la barre de navigation Android, passages d'attente coupés, sans légendes ni
musique. Sortie MP4 H.264 1080 x 2340, 30 images/s.

Usage : python3 compose_samsung.py <dossier> <sortie.mp4>
"""
import json
import os
import subprocess
import sys

folder, output = sys.argv[1], sys.argv[2]
here = os.path.dirname(os.path.abspath(__file__))
marks = json.load(open(os.path.join(folder, 'marks.json')))
W, ST, APP, NAV = 1080, 80, 2134, 126
MAX_S = 180.0

duration = marks['duration']
skips = sorted((s['start'], s['end']) for s in marks['skips'] if s['end'] - s['start'] > 0.3)
frames = sorted(marks['frames'], key=lambda f: f['t'])
if not frames:
    sys.exit('aucune image enregistrée')


def kept_before(t):
    return t - sum(max(0.0, min(e, t) - s) for s, e in skips if s < t)


speed = max(1.0, kept_before(duration) / MAX_S)
out_t = lambda t: kept_before(t) / speed  # noqa: E731
lines, total = [], 0.0
for i, f in enumerate(frames):
    end = frames[i + 1]['t'] if i + 1 < len(frames) else duration
    d = out_t(min(end, duration)) - out_t(min(max(0.0, f['t']), duration))
    if d <= 0:
        continue
    lines.append(f"file '{os.path.abspath(os.path.join(folder, 'frames', f['file']))}'\nduration {d:.4f}")
    total += d
lines.append(lines[-1].split('\n')[0])
concat = os.path.join(folder, 'frames.txt')
open(concat, 'w').write('\n'.join(lines) + '\n')

fc = (f'[0:v]scale={W}:{APP},fps=30,setsar=1[app];'
      f'[1:v]scale={W}:{ST},setsar=1[st];[2:v]scale={W}:{NAV},setsar=1[nav];'
      '[st][app][nav]vstack=inputs=3,format=yuv420p[v]')
cmd = ['ffmpeg', '-y', '-loglevel', 'error', '-f', 'concat', '-safe', '0', '-i', concat,
       '-loop', '1', '-i', os.path.join(here, 'samsung', 'status.png'),
       '-loop', '1', '-i', os.path.join(here, 'samsung', 'nav.png'),
       '-filter_complex', fc, '-map', '[v]', '-shortest', '-an', '-r', '30',
       '-c:v', 'libx264', '-preset', 'slow', '-crf', '20', '-movflags', '+faststart', output]
subprocess.run(cmd, check=True)
print(f'vidéo : {total:.1f} s, vitesse ×{speed:.2f}, {os.path.getsize(output) / 1e6:.1f} Mo, {len(frames)} images')
