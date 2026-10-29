"""Voix off du film Bab Taxi avec ElevenLabs (clé dans le secret ELEVENLABS_API_KEY).
python3 voix.py textes.json sortie/
- Sans voix choisie (VOICE_ID vide) : essais de quelques voix françaises de la bibliothèque ElevenLabs
  sur deux phrases du film (essais/<nom>.mp3), pour choisir.
- Avec VOICE_ID : une piste par scène (<id>.mp3), en donnant le texte voisin pour garder le ton."""
import json, os, sys, urllib.request, urllib.parse, urllib.error

KEY = os.environ['ELEVENLABS_API_KEY']
API = 'https://api.elevenlabs.io/v1'
src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
data = json.load(open(src))
lines = [l for l in data['lignes'] if l['texte']]


def call(path, body=None, method=None):
    req = urllib.request.Request(API + path, method=method or ('POST' if body is not None else 'GET'),
                                 data=json.dumps(body).encode() if body is not None else None,
                                 headers={'xi-api-key': KEY, 'Content-Type': 'application/json'})
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            return r.read()
    except urllib.error.HTTPError as e:
        print('ERREUR', e.code, path.split('?')[0], e.read()[:500].decode(errors='replace'), flush=True)
        raise


def tts(voice, text, prev='', nxt=''):
    body = dict(text=text, model_id=data.get('modele', 'eleven_multilingual_v2'), previous_text=prev, next_text=nxt,
                voice_settings=dict(stability=0.5, similarity_boost=0.8, style=0.25, use_speaker_boost=True, speed=0.97))
    return call(f'/text-to-speech/{voice}?output_format=mp3_44100_128', body)


voice = os.environ.get('VOICE_ID', '').strip()
if not voice:
    os.makedirs(out + '/essais', exist_ok=True)
    picks = []
    PREMADE = [('George', 'JBFqnCBsd6RMkjVDRZzb', 'male'), ('Daniel', 'onwK4e9ZLuTAKqWW03F9', 'male'),
               ('Brian', 'nPczCjzI2devNBz1zQrb', 'male'), ('Charlotte', 'XB0fDUnXU5powFXDhCwa', 'female')]
    for gender in ('male', 'female'):
      try:
          q = urllib.parse.urlencode(dict(language='fr', gender=gender, use_cases='narrative_story', page_size=30, sort='cloned_by_count'))
          voices = json.loads(call('/shared-voices?' + q))['voices']
          fr = [v for v in voices if (v.get('accent') or '').lower() in ('parisian', 'standard', 'french', '')][:3 if gender == 'male' else 2]
          picks += fr or voices[:2]
      except Exception as e:
        print('bibliothèque de voix inaccessible :', e)
    if not picks:
        picks = [dict(name=n, voice_id=v, gender=g, public_owner_id=None) for n, v, g in PREMADE]
    sample = ' '.join(l['texte'] for l in lines if l['id'] in ('P02', 'P04'))
    infos = []
    for v in picks:
        name = ''.join(c for c in v['name'] if c.isalnum() or c in ' -').strip().replace(' ', '-')
        try:
            if not v.get('public_owner_id'): raise ValueError('voix de base')
            vid = json.loads(call(f"/voices/add/{v['public_owner_id']}/{v['voice_id']}", {'new_name': 'Bab ' + v['name'][:40]}))['voice_id']
        except Exception as e:  # déjà ajoutée au compte
            vid = v['voice_id']
        open(f'{out}/essais/{name}.mp3', 'wb').write(tts(vid, sample))
        infos.append(dict(nom=v['name'], voice_id=vid, genre=v.get('gender'), accent=v.get('accent'), description=v.get('description', '')[:200]))
        print('essai', name, vid)
    json.dump(infos, open(f'{out}/essais/voix.json', 'w'), ensure_ascii=False, indent=1)
else:
    for i, l in enumerate(lines):
        prev = lines[i - 1]['texte'] if i else ''
        nxt = lines[i + 1]['texte'] if i + 1 < len(lines) else ''
        open(f"{out}/{l['id']}.mp3", 'wb').write(tts(voice, l['texte'], prev, nxt))
        print('voix', l['id'])
