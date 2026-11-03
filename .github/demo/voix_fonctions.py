"""Voix des vidéos « fonctionnalités » avec ElevenLabs (secret ELEVENLABS_API_KEY).

python3 voix_fonctions.py legendes <dossier des voix> <marks.json>...
    Lit chaque légende des enregistrements (sauf ceux marqués « sansNarration ») et crée <clé>.mp3 avec la voix
    du narrateur des films (Nicolas). Clé = empreinte du texte (même calcul que compose_fonction.py) : une
    phrase déjà dite n'est pas redemandée.
python3 voix_fonctions.py phrase <voix> <sortie.mp3> "<texte>"
    Une phrase avec une autre voix (passagère du WhatsApp : « passagere »).
Sans clé ou en cas d'erreur : rien n'est créé, les vidéos sont montées avec les légendes seules.
"""
import hashlib
import json
import os
import sys
import urllib.error
import urllib.request

KEY = os.environ.get('ELEVENLABS_API_KEY', '').strip()
VOIX = {
    'nicolas': ('aQROLel5sQbj1vuIVi6B', 'eleven_multilingual_v2'),   # narrateur des films (français)
    'passagere': ('XB0fDUnXU5powFXDhCwa', 'eleven_multilingual_v2'),  # Charlotte : passagère du WhatsApp
}


def cle(texte):
    return hashlib.sha1(texte.strip().encode()).hexdigest()[:16]


def tts(voix, texte, sortie, precedent='', suivant=''):
    vid, modele = VOIX[voix]
    corps = dict(text=texte, model_id=modele, previous_text=precedent, next_text=suivant,
                 voice_settings=dict(stability=0.5, similarity_boost=0.8, style=0.25, use_speaker_boost=True, speed=1.0))
    req = urllib.request.Request(f'https://api.elevenlabs.io/v1/text-to-speech/{vid}?output_format=mp3_44100_128',
                                 data=json.dumps(corps).encode(), method='POST',
                                 headers={'xi-api-key': KEY, 'Content-Type': 'application/json'})
    with urllib.request.urlopen(req, timeout=120) as r:
        donnees = r.read()
    open(sortie, 'wb').write(donnees)


def main():
    if not KEY:
        print('ELEVENLABS_API_KEY absente : pas de voix')
        return
    mode = sys.argv[1]
    if mode == 'phrase':
        voix, sortie, texte = sys.argv[2:5]
        if not os.path.exists(sortie):
            tts(voix, texte, sortie)
        print('voix :', sortie)
        return
    dossier = sys.argv[2]
    os.makedirs(dossier, exist_ok=True)
    nouvelles = 0
    for m in sys.argv[3:]:
        if not os.path.exists(m):
            continue
        marks = json.load(open(m))
        if marks.get('sansNarration'):
            continue
        textes = [c['text'] for c in marks['captions'] if c.get('text')]
        for i, t in enumerate(textes):
            sortie = os.path.join(dossier, cle(t) + '.mp3')
            if os.path.exists(sortie):
                continue
            try:
                tts('nicolas', t, sortie, textes[i - 1] if i else '', textes[i + 1] if i + 1 < len(textes) else '')
                nouvelles += 1
            except urllib.error.HTTPError as e:
                print('ElevenLabs :', e.code, e.read()[:300].decode(errors='replace'))
                if e.code in (401, 402, 403):
                    return
    print(f'{nouvelles} nouvelle(s) voix dans {dossier}')


main()
