"""Voix off darija du film Bab Taxi avec ElevenLabs (clé dans le secret ELEVENLABS_API_KEY).
python3 voix_darija.py textes-darija.json sortie/
- Sans voice_id : essais de voix marocaines de la bibliothèque ElevenLabs (et de deux modèles) sur deux
  phrases du film (essais/<voix>-<modèle>.mp3), pour choisir à l'oreille.
- Avec voice_id : une piste par scène (<id>.mp3)."""
import json, os, sys, urllib.request, urllib.parse, urllib.error

KEY = os.environ['ELEVENLABS_API_KEY']
API = 'https://api.elevenlabs.io/v1'
src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
data = json.load(open(src))
lines = [l for l in data['lignes'] if l['texte']]


def call(path, body=None):
    req = urllib.request.Request(API + path, method='POST' if body is not None else 'GET',
                                 data=json.dumps(body).encode() if body is not None else None,
                                 headers={'xi-api-key': KEY, 'Content-Type': 'application/json'})
    try:
        with urllib.request.urlopen(req, timeout=180) as r:
            return r.read()
    except urllib.error.HTTPError as e:
        print('ERREUR', e.code, path.split('?')[0], e.read()[:500].decode(errors='replace'), flush=True)
        raise


def tts(voice, text, model, prev='', nxt=''):
    body = dict(text=text, model_id=model, language_code='ar')
    if model == 'eleven_v3':
        body['voice_settings'] = dict(stability=0.5, similarity_boost=0.8)
    else:
        body.update(previous_text=prev, next_text=nxt,
                    voice_settings=dict(stability=0.5, similarity_boost=0.8, style=0.25, use_speaker_boost=True, speed=0.97))
    return call(f'/text-to-speech/{voice}?output_format=mp3_44100_128', body)


voice = data.get('voice_id', '').strip()
if not voice:
    os.makedirs(out + '/essais', exist_ok=True)
    found = {}
    for q in [dict(language='ar', accent='moroccan'), dict(language='ar', search='moroccan'), dict(language='ar', search='darija'),
              dict(language='ar', search='maroc')]:
        for gender in ('male', 'female'):
            try:
                res = json.loads(call('/shared-voices?' + urllib.parse.urlencode(dict(q, gender=gender, page_size=20, sort='cloned_by_count'))))
                for v in res['voices']:
                    found.setdefault(v['voice_id'], v)
            except Exception as e:
                print('recherche impossible', q, e)
    vs = list(found.values())
    print('voix trouvées :', len(vs))
    for v in vs:
        print(' -', v.get('name'), '|', v.get('gender'), '|', v.get('accent'), '|', v.get('language'), '|', (v.get('description') or '')[:100])
    males = [v for v in vs if v.get('gender') == 'male'][:4]
    females = [v for v in vs if v.get('gender') == 'female'][:2]
    sample = ' '.join(l['texte'] for l in lines if l['id'] in data.get('essai', ['P02', 'P10']))
    infos = []
    for v in males + females:
        name = ''.join(c for c in v['name'] if c.isalnum() or c in ' -').strip().replace(' ', '-')[:30]
        try:
            vid = json.loads(call(f"/voices/add/{v['public_owner_id']}/{v['voice_id']}", {'new_name': 'Bab darija ' + v['name'][:30]}))['voice_id']
        except Exception:
            vid = v['voice_id']
        for model in ('eleven_v3', 'eleven_multilingual_v2'):
            try:
                open(f'{out}/essais/{name}-{model}.mp3', 'wb').write(tts(vid, sample, model))
                print('essai', name, model, vid)
            except Exception as e:
                print('échec', name, model, e)
        infos.append(dict(nom=v['name'], voice_id=vid, genre=v.get('gender'), accent=v.get('accent'), description=(v.get('description') or '')[:200]))
    json.dump(infos, open(f'{out}/essais/voix.json', 'w'), ensure_ascii=False, indent=1)
else:
    model = data.get('modele', 'eleven_v3')
    for i, l in enumerate(lines):
        prev = lines[i - 1]['texte'] if i else ''
        nxt = lines[i + 1]['texte'] if i + 1 < len(lines) else ''
        open(f"{out}/{l['id']}.mp3", 'wb').write(tts(voice, l['texte'], model, prev, nxt))
        print('voix', l['id'])
