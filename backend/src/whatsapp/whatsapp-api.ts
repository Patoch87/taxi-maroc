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
  const form = new FormData();
  form.append('messaging_product', 'whatsapp');
  form.append('type', type);
  form.append('file', new Blob([new Uint8Array(audio)], { type }), type === 'audio/mpeg' ? 'bab.mp3' : 'bab.ogg');
  const { id } = (await (await graph(`/${numero()}/media`, { method: 'POST', body: form })).json()) as { id: string };
  await envoyer({ to: a, type: 'audio', audio: { id } });
}

/** Marque le message comme lu (coches bleues) : le passager voit que Bab l'a reçu. */
export async function marquerLu(messageId: string) {
  if (whatsappActif()) await envoyer({ status: 'read', message_id: messageId }).catch(() => undefined);
}

/** Télécharge le fichier d'un vocal reçu. */
export async function telechargerMedia(mediaId: string): Promise<{ donnees: Buffer; type: string }> {
  const info = (await (await graph(`/${mediaId}`)).json()) as { url: string; mime_type: string };
  const res = await fetch(info.url, { headers: { authorization: `Bearer ${jeton()}` }, signal: AbortSignal.timeout(20_000) });
  if (!res.ok) throw new Error(`Téléchargement du vocal : ${res.status}`);
  return { donnees: Buffer.from(await res.arrayBuffer()), type: info.mime_type.split(';')[0] };
}
