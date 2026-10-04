"""Fabrique le petit son des demandes chauffeur : deux notes douces (sinus), volume bas.

Son synthétisé ici, sans aucun enregistrement protégé. Usage : python3 tool/make_chime.py
Écrit assets/sounds/request_chime.wav (mono, 22 050 Hz, 16 bits, moins d'une seconde).
"""
import math
import struct
import wave

RATE = 22050
GAIN = 0.3  # volume bas
NOTES = [(659.25, 0.0, 0.32), (880.0, 0.22, 0.45)]  # mi5 puis la5 : (fréquence, début, durée) en secondes
LENGTH = 0.7


def envelope(t, d):
    attack = 0.012
    if t < attack:
        return t / attack
    return math.exp(-5.0 * (t - attack) / d)  # décroissance douce, comme une clochette


samples = []
for i in range(int(RATE * LENGTH)):
    t = i / RATE
    v = 0.0
    for f, start, d in NOTES:
        u = t - start
        if 0 <= u < d:
            # Fondamentale + un peu d'octave pour un timbre de clochette.
            v += envelope(u, d) * (math.sin(2 * math.pi * f * u) + 0.25 * math.sin(4 * math.pi * f * u)) / 1.25
    samples.append(max(-1.0, min(1.0, v * GAIN)))

with wave.open('assets/sounds/request_chime.wav', 'wb') as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(RATE)
    w.writeframes(b''.join(struct.pack('<h', int(x * 32767)) for x in samples))
