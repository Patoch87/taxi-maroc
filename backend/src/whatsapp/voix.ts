/**
 * Voix de l'agent avec ElevenLabs (le compte déjà utilisé pour les vidéos Bab Taxi) :
 * transcription des vocaux du passager (Scribe) et lecture des réponses (synthèse vocale multilingue).
 * Sans ELEVENLABS_API_KEY : pas de transcription ni de voix, l'agent répond par écrit.
 */
const API = 'https://api.elevenlabs.io/v1';
const cle = () => process.env.ELEVENLABS_API_KEY;

export const voixActive = () => !!cle();

/** Texte d'un message vocal (ogg/opus de WhatsApp, webm du navigateur...). */
export async function transcrire(audio: Buffer, type: string): Promise<{ texte: string; langue?: string }> {
  if (!cle()) throw new Error('ELEVENLABS_API_KEY manquante : transcription impossible');
  const form = new FormData();
  form.append('model_id', process.env.ELEVENLABS_STT_MODELE || 'scribe_v1');
  form.append('file', new Blob([new Uint8Array(audio)], { type }), 'vocal' + (type.includes('webm') ? '.webm' : type.includes('mp4') ? '.m4a' : type.includes('mpeg') ? '.mp3' : '.ogg'));
  form.append('tag_audio_events', 'false');
  const res = await fetch(`${API}/speech-to-text`, {
    method: 'POST',
    headers: { 'xi-api-key': cle()! },
    body: form,
    signal: AbortSignal.timeout(30_000),
  });
  if (!res.ok) throw new Error(`Transcription ElevenLabs : ${res.status} ${await res.text()}`);
  const r = (await res.json()) as { text?: string; language_code?: string };
  return { texte: (r.text ?? '').trim(), langue: r.language_code };
}

/** Réponse lue à voix haute, en mp3 (accepté par WhatsApp comme message audio). */
export async function synthetiser(texte: string, arabe: boolean): Promise<{ donnees: Buffer; type: string }> {
  if (!cle()) throw new Error('ELEVENLABS_API_KEY manquante : voix impossible');
  // Une voix par langue si besoin (ex. une voix marocaine pour la darija), sinon la même voix multilingue.
  const voix =
    (arabe ? process.env.ELEVENLABS_VOIX_DARIJA : undefined) || process.env.ELEVENLABS_VOIX || 'JBFqnCBsd6RMkjVDRZzb';
  const res = await fetch(`${API}/text-to-speech/${voix}?output_format=mp3_44100_128`, {
    method: 'POST',
    headers: { 'xi-api-key': cle()!, 'content-type': 'application/json' },
    body: JSON.stringify({
      text: texte,
      model_id: process.env.ELEVENLABS_TTS_MODELE || 'eleven_multilingual_v2',
      voice_settings: { stability: 0.5, similarity_boost: 0.8 },
    }),
    signal: AbortSignal.timeout(30_000),
  });
  if (!res.ok) throw new Error(`Voix ElevenLabs : ${res.status} ${await res.text()}`);
  return { donnees: Buffer.from(await res.arrayBuffer()), type: 'audio/mpeg' };
}
