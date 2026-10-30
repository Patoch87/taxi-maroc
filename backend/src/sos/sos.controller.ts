import {
  BadRequestException,
  Body,
  Controller,
  ForbiddenException,
  Get,
  Header,
  Headers,
  NotFoundException,
  Param,
  Post,
  Query,
  Req,
  Res,
} from '@nestjs/common';
import { randomUUID } from 'crypto';
import type { IncomingMessage, ServerResponse } from 'http';

/** Taille maximale d'une séquence vidéo (10 s en qualité moyenne : environ 1 à 3 Mo). */
export const MAX_SEGMENT = 20 * 1024 * 1024;
/** Mémoire totale gardée pour les vidéos (offre gratuite Render : 512 Mo). Les plus anciennes partent d'abord. */
export const MAX_TOTAL = 150 * 1024 * 1024;

interface Position {
  lat: number;
  lng: number;
  a: string;
}

interface Segment {
  index: number;
  type: string;
  taille: number;
  recuLe: string;
  data?: Buffer;
}

interface AlerteSos {
  id: string;
  passagerId?: string;
  nom?: string;
  courseId?: string;
  taxiId?: string;
  statut: 'en_direct' | 'terminee';
  creeLe: string;
  termineeLe?: string;
  positions: Position[];
  segments: Segment[];
}

function position(body: { lat?: unknown; lng?: unknown }): Position | undefined {
  const lat = Number(body?.lat);
  const lng = Number(body?.lng);
  if (!Number.isFinite(lat) || !Number.isFinite(lng) || Math.abs(lat) > 90 || Math.abs(lng) > 180) return undefined;
  return { lat, lng, a: new Date().toISOString() };
}

/** Lit le corps brut (vidéo) : le serveur ne lit lui-même que le JSON. */
function lireCorps(req: IncomingMessage, max: number): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    const parts: Buffer[] = [];
    let taille = 0;
    req.on('data', (c: Buffer) => {
      taille += c.length;
      if (taille > max) {
        reject(new BadRequestException('Séquence trop grande'));
        req.destroy();
      } else {
        parts.push(c);
      }
    });
    req.on('end', () => resolve(Buffer.concat(parts)));
    req.on('error', reject);
  });
}

/**
 * SOS du passager : alerte avec position, puis vidéo et son envoyés en direct par séquences de quelques secondes.
 * Le centre de sécurité Bab Taxi les regarde sur /sos/centre et alerte les autorités compétentes
 * (aucun raccordement direct à la police n'existe encore). Stockage en mémoire pour la première version.
 * Les vidéos ne sont lisibles qu'avec la clé du centre (variable SOS_CENTRE_TOKEN) : loi 09-08.
 */
@Controller('sos')
export class SosController {
  private readonly alertes = new Map<string, AlerteSos>();

  private verifierCle(cle?: string) {
    const attendue = process.env.SOS_CENTRE_TOKEN;
    if (!attendue || cle !== attendue) throw new ForbiddenException('Accès réservé au centre de sécurité');
  }

  private alerte(id: string) {
    const a = this.alertes.get(id);
    if (!a) throw new NotFoundException('Alerte introuvable');
    return a;
  }

  /** Résumé sans les vidéos, renvoyé au téléphone. */
  private resume(a: AlerteSos) {
    return {
      id: a.id,
      statut: a.statut,
      creeLe: a.creeLe,
      termineeLe: a.termineeLe,
      derniere: a.positions.at(-1),
      segments: a.segments.length,
    };
  }

  /** Les séquences les plus anciennes sont libérées quand la mémoire réservée est pleine. */
  private liberer() {
    const toutes = [...this.alertes.values()].flatMap((a) => a.segments.filter((s) => s.data));
    let total = toutes.reduce((n, s) => n + s.taille, 0);
    toutes.sort((x, y) => x.recuLe.localeCompare(y.recuLe));
    for (const s of toutes) {
      if (total <= MAX_TOTAL) break;
      total -= s.taille;
      s.data = undefined;
    }
  }

  @Post()
  create(@Body() body: { passagerId?: string; nom?: string; courseId?: string; taxiId?: string; lat?: number; lng?: number }) {
    const pos = position(body ?? {});
    const a: AlerteSos = {
      id: randomUUID(),
      passagerId: body?.passagerId,
      nom: body?.nom,
      courseId: body?.courseId,
      taxiId: body?.taxiId,
      statut: 'en_direct',
      creeLe: new Date().toISOString(),
      positions: pos ? [pos] : [],
      segments: [],
    };
    this.alertes.set(a.id, a);
    return this.resume(a);
  }

  @Post(':id/position')
  move(@Param('id') id: string, @Body() body: { lat?: number; lng?: number }) {
    const a = this.alerte(id);
    const pos = position(body ?? {});
    if (!pos) throw new BadRequestException('lat et lng attendus');
    a.positions.push(pos);
    return this.resume(a);
  }

  /** Une séquence vidéo (corps brut, video/mp4 ou video/quicktime), numérotée par l'en-tête x-segment. */
  @Post(':id/segments')
  async segment(@Param('id') id: string, @Req() req: IncomingMessage, @Headers('x-segment') numero?: string) {
    const a = this.alerte(id);
    const data = await lireCorps(req, MAX_SEGMENT);
    if (data.length === 0) throw new BadRequestException('Séquence vide');
    const index = Number.isInteger(Number(numero)) ? Number(numero) : a.segments.length;
    a.segments.push({
      index,
      type: req.headers['content-type'] ?? 'video/mp4',
      taille: data.length,
      recuLe: new Date().toISOString(),
      data,
    });
    this.liberer();
    return this.resume(a);
  }

  @Post(':id/end')
  end(@Param('id') id: string) {
    const a = this.alerte(id);
    a.statut = 'terminee';
    a.termineeLe = new Date().toISOString();
    return this.resume(a);
  }

  /** Liste des alertes pour le centre de sécurité (clé obligatoire). */
  @Get()
  list(@Query('cle') cle?: string) {
    this.verifierCle(cle);
    return [...this.alertes.values()]
      .sort((x, y) => y.creeLe.localeCompare(x.creeLe))
      .map((a) => ({
        ...this.resume(a),
        passagerId: a.passagerId,
        nom: a.nom,
        courseId: a.courseId,
        taxiId: a.taxiId,
        positions: a.positions,
        videos: a.segments.map((s) => ({ index: s.index, taille: s.taille, recuLe: s.recuLe, disponible: !!s.data })),
      }));
  }

  /** Page du centre de sécurité : alertes en direct, carte et vidéos (rafraîchie toutes les 5 s). */
  @Get('centre')
  @Header('Content-Type', 'text/html; charset=utf-8')
  @Header('Cache-Control', 'no-store')
  centre(@Query('cle') cle?: string) {
    this.verifierCle(cle);
    return PAGE_CENTRE;
  }

  @Get(':id')
  get(@Param('id') id: string) {
    return this.resume(this.alerte(id));
  }

  @Get(':id/segments/:n')
  video(@Param('id') id: string, @Param('n') n: string, @Query('cle') cle: string | undefined, @Res() res: ServerResponse) {
    this.verifierCle(cle);
    const s = this.alerte(id).segments[Number(n)];
    if (!s?.data) throw new NotFoundException('Séquence introuvable ou déjà libérée');
    res.setHeader('Content-Type', s.type);
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('Content-Length', s.data.length);
    res.end(s.data);
  }
}

const PAGE_CENTRE = `<!doctype html>
<html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Bab Taxi · Centre de sécurité</title>
<style>
body{font-family:system-ui,sans-serif;margin:0;background:#F3EAD7;color:#0F2A1E}
header{background:#C1272D;color:#fff;padding:14px 18px;font-weight:800;font-size:20px}
main{padding:16px;display:grid;gap:16px;max-width:1100px;margin:auto}
.a{background:#fff;border-radius:14px;padding:14px;box-shadow:0 1px 3px #0002}
.live{color:#C1272D;font-weight:800}.fin{color:#006233;font-weight:700}
video{width:100%;max-width:520px;border-radius:10px;background:#000}
small{color:#5b6b63}a{color:#006233}
</style></head><body>
<header>Bab Taxi · Centre de sécurité · alertes SOS</header>
<main id="m"><p>Chargement…</p></main>
<script>
const cle = new URLSearchParams(location.search).get('cle') || '';
const esc = (t) => String(t).replace(/[&<>"']/g, (c) => '&#' + c.charCodeAt(0) + ';');
let dernier = '';
async function charger(){
  const r = await fetch('/sos?cle=' + encodeURIComponent(cle));
  const liste = await r.json();
  // La page n'est redessinée que si une alerte a changé (sinon la vidéo en cours s'arrêterait).
  const cleVue = liste.map(a => a.id + a.statut + a.segments + (a.derniere ? a.derniere.a : '')).join('|');
  if (cleVue === dernier) return;
  dernier = cleVue;
  const m = document.getElementById('m');
  if (!liste.length) { m.innerHTML = '<p>Aucune alerte.</p>'; return; }
  m.innerHTML = liste.map(a => {
    const p = a.derniere;
    const carte = p ? '<a target="_blank" href="https://www.google.com/maps?q=' + p.lat + ',' + p.lng + '">Position ' + p.lat.toFixed(5) + ', ' + p.lng.toFixed(5) + '</a> <small>(' + new Date(p.a).toLocaleTimeString('fr-FR') + ')</small>' : 'Position inconnue';
    const vids = a.videos.filter(v => v.disponible);
    const der = vids.at(-1);
    return '<div class="a"><div>' + (a.statut === 'en_direct' ? '<span class="live">● EN DIRECT</span>' : '<span class="fin">Terminée</span>') +
      ' · ' + new Date(a.creeLe).toLocaleString('fr-FR') + '</div>' +
      '<div><b>' + esc(a.nom || a.passagerId || 'Passager') + '</b> · taxi ' + esc(a.taxiId || '?') + ' · course ' + esc(a.courseId || '?') + '</div>' +
      '<div>' + carte + '</div>' +
      '<div><small>' + a.segments + ' séquence(s) reçue(s)</small></div>' +
      (der ? '<video controls autoplay muted playsinline src="/sos/' + a.id + '/segments/' + (a.videos.length - 1) + '?cle=' + encodeURIComponent(cle) + '"></video>' : '') +
      '<div>' + vids.map(v => '<a target="_blank" href="/sos/' + a.id + '/segments/' + a.videos.indexOf(v) + '?cle=' + encodeURIComponent(cle) + '">' + (v.index + 1) + '</a>').join(' · ') + '</div></div>';
  }).join('');
}
charger(); setInterval(charger, 5000);
</script></body></html>`;
