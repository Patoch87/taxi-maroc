"""Voix de la vidéo de démonstration « Commander par WhatsApp » (ElevenLabs, secret ELEVENLABS_API_KEY).
python3 voix_whatsapp.py whatsapp-demo.json sortie/  ->  <id>.mp3 par réplique + voix.json (voix choisies)."""
import json, os, sys, urllib.request, urllib.parse, urllib.error

KEY = os.environ['ELEVENLABS_API_KEY']
API = 'https://api.elevenlabs.io/v1'
src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
data = json.load(open(src))


def call(path, body=None):
    req = urllib.request.Request(API + path, method='POST' if body is not None else 'GET',
                                 data=json.dumps(body).encode() if body is not None else None,
                                 headers={'xi-api-key': KEY, 'Content-Type': 'application/json'})
    try:
        with urllib.request.urlopen(req, timeout=180) as r:
            return r.read()
    except urllib.error.HTTPError as e:
        print('ERREUR', e.code, path.split('?')[0], e.read()[:400].decode(errors='replace'), flush=True)
        raise


def choisir(role):
    """Voix fixée, sinon la voix la plus utilisée de la bibliothèque qui correspond à la recherche."""
    if role.get('voice_id'):
        return role['voice_id'], 'fixée'
    try:
        q = urllib.parse.urlencode(dict(role['recherche'], page_size=10, sort='cloned_by_count'))
        for v in json.loads(call('/shared-voices?' + q))['voices']:
            try:
                vid = json.loads(call(f"/voices/add/{v['public_owner_id']}/{v['voice_id']}", {'new_name': 'Bab WA ' + v['name'][:30]}))['voice_id']
            except Exception:
                vid = v['voice_id']
            return vid, v['name']
    except Exception as e:
        print('recherche impossible', e)
    return role['secours'], 'secours'


voix = {}
for nom, role in data['roles'].items():
    vid, nomv = choisir(role)
    voix[nom] = dict(voice_id=vid, nom=nomv, modele=role['modele'])
    print('rôle', nom, '->', nomv, vid, flush=True)
json.dump(voix, open(f'{out}/voix.json', 'w'), ensure_ascii=False, indent=1)

for l in data['lignes']:
    role = data['roles'][l['role']]
    body = dict(text=l['texte'], model_id=role['modele'], language_code=role['langue'],
                voice_settings=dict(stability=0.5, similarity_boost=0.8))
    try:
        audio = call(f"/text-to-speech/{voix[l['role']]['voice_id']}?output_format=mp3_44100_128", body)
    except urllib.error.HTTPError:
        body.pop('language_code')  # certains modèles refusent le code langue
        audio = call(f"/text-to-speech/{voix[l['role']]['voice_id']}?output_format=mp3_44100_128", body)
    open(f"{out}/{l['id']}.mp3", 'wb').write(audio)
    print('voix', l['id'], flush=True)
