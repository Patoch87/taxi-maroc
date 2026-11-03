"""Voix des vidéos « fonctionnalités » avec ElevenLabs (secret ELEVENLABS_API_KEY).

python3 voix_fonctions.py legendes <dossier des voix> <marks.json>...
    Lit chaque légende des enregistrements (sauf ceux marqués « sansNarration ») et crée <clé>.mp3 avec la voix
    du narrateur des films (Nicolas). Clé = empreinte du texte (même calcul que compose_fonction.py) : une
    phrase déjà dite n'est pas redemandée.
python3 voix_fonctions.py phrase <voix> <sortie.mp3> "<texte>"
    Une phrase avec une autre voix (passagère du WhatsApp : « passagere »).
Sans clé ou en cas d'erreur : rien n'est créé, les vidéos sont montées avec les légendes seules.
"""
import array
import hashlib
import json
import math
import os
import subprocess
import sys
import urllib.error
import urllib.request

KEY = os.environ.get('ELEVENLABS_API_KEY', '').strip()
VOIX = {
    'nicolas': ('aQROLel5sQbj1vuIVi6B', 'eleven_multilingual_v2'),   # narrateur des films (français)
    'passagere': ('XB0fDUnXU5powFXDhCwa', 'eleven_multilingual_v2'),  # Charlotte : passagère du WhatsApp
}


def cle(texte):
    # « v2 » : voix refaites phrase par phrase (les premières, liées au texte voisin, étaient coupées).
    return hashlib.sha1(('v2|' + texte.strip()).encode()).hexdigest()[:16]


def a_dire(texte):
    # Une phrase qui se termine par un point est dite en entier, avec une fin posée.
    t = texte.strip()
    return t if t[-1] in '.?!…' else t + '.'


def enveloppe(fichier):
    brut = subprocess.run(['ffmpeg', '-v', 'error', '-i', fichier, '-f', 's16le', '-ac', '1', '-ar', '16000', '-'],
                          capture_output=True).stdout
    a = array.array('h', brut)
    w = 800  # 50 ms
    return [math.sqrt(sum(x * x for x in a[i:i + w]) / w) for i in range(0, len(a) - w + 1, w)]


def defaut(fichier, texte):
    # Voix coupée : elle commence ou finit en pleine parole, ou elle est trop courte pour le texte.
    e = enveloppe(fichier)
    if len(e) < 6:
        return 'vide'
    duree = len(e) * 0.05
    if e[0] > 2500:
        return 'début coupé'
    if e[-1] > 800 and e[-2] > 800:
        return 'fin coupée'
    if duree < 0.045 * len(texte):
        return f'trop courte ({duree:.1f} s)'
    return None


def tts(voix, texte, sortie, essais=4):
    vid, modele = VOIX[voix]
    dit = a_dire(texte)
    for n in range(essais):
        corps = dict(text=dit, model_id=modele,
                     voice_settings=dict(stability=0.6, similarity_boost=0.8, style=0.15, use_speaker_boost=True,
                                         speed=0.97))
        req = urllib.request.Request(f'https://api.elevenlabs.io/v1/text-to-speech/{vid}?output_format=mp3_44100_128',
                                     data=json.dumps(corps).encode(), method='POST',
                                     headers={'xi-api-key': KEY, 'Content-Type': 'application/json'})
        with urllib.request.urlopen(req, timeout=120) as r:
            donnees = r.read()
        essai = sortie + '.essai.mp3'
        open(essai, 'wb').write(donnees)
        souci = defaut(essai, dit)
        if not souci or n == essais - 1:
            os.replace(essai, sortie)
            if souci:
                print(f'::warning::voix imparfaite après {essais} essais ({souci}) : {texte}')
            return
        print(f'voix refaite ({souci}) : {texte}')


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
        for t in textes:
            sortie = os.path.join(dossier, cle(t) + '.mp3')
            if os.path.exists(sortie):
                continue
            try:
                tts('nicolas', t, sortie)
                nouvelles += 1
            except urllib.error.HTTPError as e:
                print('ElevenLabs :', e.code, e.read()[:300].decode(errors='replace'))
                if e.code in (401, 402, 403):
                    return
    print(f'{nouvelles} nouvelle(s) voix dans {dossier}')


main()
