import { createHmac, timingSafeEqual } from 'crypto';

/**
 * Client de l'API WhatsApp Business Cloud (Meta). Réglages sur Render :
 * WHATSAPP_TOKEN (jeton d'accès permanent d'un utilisateur système), WHATSAPP_PHONE_NUMBER_ID (identifiant du numéro),
 * WHATSAPP_APP_SECRET (clé secrète de l'application Meta, pour vérifier les webhooks).
 */
const VERSION = () => process.env.WHATSAPP_GRAPH_VERSION || 'v23.0';
const GRAPH = () => `https://graph.facebook.com/${VERSION()}`;
const jeton = () => process.env.WHATSAPP_TOKEN;
const numero = () => process.env.WHATSAPP_PHONE_NUMBER_ID;

export const whatsappActif = () => !!jeton() && !!numero();

/** Vérifie la signature X-Hub-Signature-256 envoyée par Meta (sans clé secrète réglée : accepté). */
export function signatureValide(corps: Buffer | undefined, signature: string | undefined): boolean {
  const secret = process.env.WHATSAPP_APP_SECRET;
  if (!secret) return true;
  if (!corps || !signature?.startsWith('sha256=')) return false;
  const attendu = Buffer.from(createHmac('sha256', secret).update(corps).digest('hex'));
  const recu = Buffer.from(signature.slice(7));
  return attendu.length === recu.length && timingSafeEqual(attendu, recu);
}

async function graph(chemin: string, init: RequestInit = {}): Promise<Response> {
  const res = await fetch(`${GRAPH()}${chemin}`, {
    ...init,
    headers: { authorization: `Bearer ${jeton()}`, ...(init.headers ?? {}) },
    signal: AbortSignal.timeout(20_000),
  });
  if (!res.ok) throw new Error(`WhatsApp ${chemin} : ${res.status} ${await res.text()}`);
  return res;
}

async function envoyer(message: Record<string, unknown>) {
  await graph(`/${numero()}/messages`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ messaging_product: 'whatsapp', ...message }),
  });
}

export const envoyerTexte = (a: string, texte: string) => envoyer({ to: a, type: 'text', text: { body: texte } });

export async function envoyerAudio(a: string, audio: Buffer, type: string) {
  // WhatsApp ne lit tout seul (sans « Télécharger ») que les notes vocales ogg/opus : on convertit le mp3.
  const vocal = await versNoteVocale(audio, type);
  const form = new FormData();
  form.append('messaging_product', 'whatsapp');
  form.append('type', vocal.type);
  form.append('file', new Blob([new Uint8Array(vocal.donnees)], { type: vocal.type }), vocal.type === 'audio/ogg' ? 'bab.ogg' : 'bab.mp3');
  const { id } = (await (await graph(`/${numero()}/media`, { method: 'POST', body: form })).json()) as { id: string };
  if (vocal.type === 'audio/ogg') {
    // « voice: true » : affiché comme une note vocale (micro bleu), lecture directe.
    await envoyer({ to: a, type: 'audio', audio: { id, voice: true } }).catch(() => envoyer({ to: a, type: 'audio', audio: { id } }));
  } else {
    await envoyer({ to: a, type: 'audio', audio: { id } });
  }
}

/** mp3 -> ogg/opus mono (format des notes vocales WhatsApp). En cas d'échec, le mp3 part tel quel. */
export async function versNoteVocale(audio: Buffer, type: string): Promise<{ donnees: Buffer; type: string }> {
  if (type === 'audio/ogg') return { donnees: audio, type };
  try {
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const ffmpeg: string | null = require('ffmpeg-static');
    if (!ffmpeg) throw new Error('ffmpeg absent');
    const { spawn } = await import('child_process');
    const donnees = await new Promise<Buffer>((ok, ko) => {
      const p = spawn(ffmpeg, ['-hide_banner', '-loglevel', 'error', '-i', 'pipe:0', '-ac', '1', '-ar', '48000', '-c:a', 'libopus', '-b:a', '32k', '-application', 'voip', '-f', 'ogg', 'pipe:1']);
      const morceaux: Buffer[] = [];
      let erreur = '';
      const minuteur = setTimeout(() => p.kill('SIGKILL'), 15_000);
      p.stdout.on('data', (d: Buffer) => morceaux.push(d));
      p.stderr.on('data', (d: Buffer) => (erreur += d.toString()));
      p.on('error', ko);
      p.on('close', (code) => {
        clearTimeout(minuteur);
        if (code === 0 && morceaux.length) ok(Buffer.concat(morceaux));
        else ko(new Error(`ffmpeg ${code} ${erreur.slice(0, 200)}`));
      });
      p.stdin.on('error', () => undefined);
      p.stdin.end(audio);
    });
    return { donnees, type: 'audio/ogg' };
  } catch {
    return { donnees: audio, type };
  }
}

/**
 * Marque le message comme lu (coches bleues) et affiche « en train d'écrire… » chez le passager pendant que
 * Bab prépare la réponse (jusqu'à 25 s ou la réponse) : il sait tout de suite que son message est pris en compte.
 */
export async function marquerLu(messageId: string) {
  if (!whatsappActif()) return;
  await envoyer({ status: 'read', message_id: messageId, typing_indicator: { type: 'text' } }).catch(() =>
    envoyer({ status: 'read', message_id: messageId }).catch(() => undefined),
  );
}

/** Télécharge le fichier d'un vocal reçu. */
export async function telechargerMedia(mediaId: string): Promise<{ donnees: Buffer; type: string }> {
  const info = (await (await graph(`/${mediaId}`)).json()) as { url: string; mime_type: string };
  const res = await fetch(info.url, { headers: { authorization: `Bearer ${jeton()}` }, signal: AbortSignal.timeout(20_000) });
  if (!res.ok) throw new Error(`Téléchargement du vocal : ${res.status}`);
  return { donnees: Buffer.from(await res.arrayBuffer()), type: info.mime_type.split(';')[0] };
}
