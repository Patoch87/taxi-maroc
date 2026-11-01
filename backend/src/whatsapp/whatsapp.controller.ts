import {
  BadRequestException,
  Body,
  Controller,
  ForbiddenException,
  Get,
  Header,
  Headers,
  HttpCode,
  Post,
  Query,
  Req,
  Res,
} from '@nestjs/common';
import type { RawBodyRequest } from '@nestjs/common';
import type { IncomingMessage, ServerResponse } from 'http';
import { haversine } from '../domain/geo';
import { RidesService } from '../rides/rides.service';
import { SIMULATEUR } from './simulateur';
import { Reponse, WhatsappService } from './whatsapp.service';
import { signatureValide } from './whatsapp-api';

const MAX_VOCAL = 5 * 1024 * 1024;

function lireCorps(req: IncomingMessage, max: number): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    const parts: Buffer[] = [];
    let taille = 0;
    req.on('data', (c: Buffer) => {
      taille += c.length;
      if (taille > max) {
        reject(new BadRequestException('Vocal trop long'));
        req.destroy();
      } else parts.push(c);
    });
    req.on('end', () => resolve(Buffer.concat(parts)));
    req.on('error', reject);
  });
}

const versJson = (r: Reponse) => ({
  texte: r.texte,
  audio: r.audio ? `data:${r.audio.type};base64,${r.audio.donnees.toString('base64')}` : undefined,
});

/**
 * Agent WhatsApp de commande vocale.
 * - /whatsapp/webhook : adresse à donner à Meta (WhatsApp Business Cloud API).
 * - /whatsapp/demo : simulateur dans le navigateur, pour essayer l'agent sans numéro WhatsApp.
 */
@Controller('whatsapp')
export class WhatsappController {
  constructor(
    private readonly whatsapp: WhatsappService,
    private readonly rides: RidesService,
  ) {}

  /** Vérification de l'adresse du webhook par Meta (une fois, à l'enregistrement). */
  @Get('webhook')
  verifier(@Query('hub.mode') mode: string, @Query('hub.verify_token') jeton: string, @Query('hub.challenge') defi: string, @Res() res: ServerResponse) {
    const attendu = process.env.WHATSAPP_VERIFY_TOKEN;
    if (mode === 'subscribe' && attendu && jeton === attendu) {
      res.setHeader('Content-Type', 'text/plain');
      res.end(defi);
      return;
    }
    res.statusCode = 403;
    res.end('Jeton de vérification incorrect');
  }

  /** Messages reçus. Réponse 200 immédiate : le traitement (transcription, IA, voix) continue ensuite. */
  @Post('webhook')
  @HttpCode(200)
  recevoir(@Req() req: RawBodyRequest<IncomingMessage>, @Body() corps: unknown, @Headers('x-hub-signature-256') signature?: string) {
    if (!signatureValide(req.rawBody, signature)) throw new ForbiddenException('Signature invalide');
    void this.whatsapp.webhook(corps);
    return { ok: true };
  }

  @Get('etat')
  etat() {
    return this.whatsapp.etat();
  }

  // ----- Simulateur -----

  private verifierCle(cle?: string) {
    const attendue = process.env.WHATSAPP_DEMO_CLE;
    if (attendue && cle !== attendue) throw new ForbiddenException('Clé du simulateur manquante ou incorrecte');
  }

  private idDemo(id?: string) {
    if (!id || !/^[\w-]{4,40}$/.test(id)) throw new BadRequestException('id invalide');
    return `demo-${id}`;
  }

  @Get('demo')
  @Header('Content-Type', 'text/html; charset=utf-8')
  @Header('Cache-Control', 'no-store')
  simulateur(@Query('cle') cle?: string) {
    this.verifierCle(cle);
    return SIMULATEUR;
  }

  @Post('demo/message')
  async message(
    @Query('cle') cle: string | undefined,
    @Body() body: { id?: string; nom?: string; texte?: string; position?: { lat: number; lng: number; nom?: string } },
  ) {
    this.verifierCle(cle);
    const de = this.idDemo(body?.id);
    const pos = body?.position;
    if (pos && (!Number.isFinite(pos.lat) || !Number.isFinite(pos.lng))) throw new BadRequestException('position invalide');
    const r = await this.whatsapp.simuler({ de, nom: body.nom, texte: body.texte, position: pos });
    return { reponses: r.reponses.map(versJson) };
  }

  /** Vocal enregistré dans le navigateur (corps brut audio/webm ou audio/ogg). */
  @Post('demo/vocal')
  async vocal(
    @Query('cle') cle: string | undefined,
    @Query('id') id: string,
    @Query('nom') nom: string | undefined,
    @Req() req: IncomingMessage,
    @Headers('content-type') type = 'audio/webm',
  ) {
    this.verifierCle(cle);
    const de = this.idDemo(id);
    const donnees = await lireCorps(req, MAX_VOCAL);
    if (donnees.length === 0) throw new BadRequestException('Vocal vide');
    const r = await this.whatsapp.simuler({ de, nom, audio: { donnees, type: type.split(';')[0] } });
    return { transcription: r.transcription, reponses: r.reponses.map(versJson) };
  }

  /** Messages envoyés depuis (chauffeur trouvé, course démarrée...). */
  @Get('demo/boite')
  boite(@Query('cle') cle: string | undefined, @Query('id') id: string) {
    this.verifierCle(cle);
    return this.whatsapp.relever(this.idDemo(id)).map(versJson);
  }

  /**
   * Fait avancer la course comme le ferait un chauffeur de démonstration :
   * un taxi proche accepte, puis il démarre la course, puis il dépose le passager.
   */
  @Post('demo/chauffeur')
  chauffeur(@Query('cle') cle: string | undefined, @Body() body: { id?: string }) {
    this.verifierCle(cle);
    const conv = this.whatsapp.conversation(this.idDemo(body?.id));
    if (!conv.courseId) throw new BadRequestException("Pas de course : commandez d'abord.");
    const d = this.rides.getRequest(conv.courseId);
    const taxiId = `DEMO-WA-${body.id}`;
    if (d.statut === 'en_attente') {
      const p = d.demande.depart;
      const position = { lat: p.lat + 0.004, lng: p.lng + 0.003 };
      this.rides.updateTaxi({
        id: taxiId,
        type: 'petit',
        categorie: d.demande.categorie ?? 'standard',
        itineraire: [position],
        position,
        passagersABord: 0,
        reserveSeul: false,
        nom: 'Hamid',
        plaque: '12345-A-6',
      });
      this.rides.accept(d.id, taxiId);
      return { statut: 'acceptee', distanceM: Math.round(haversine(position, p)) };
    }
    if (d.statut === 'acceptee') return { statut: this.rides.advance(d.id, d.accepteePar!, 'a_bord').statut };
    if (d.statut === 'a_bord') {
      const fin = this.rides.advance(d.id, d.accepteePar!, 'terminee');
      if (d.accepteePar === taxiId) this.rides.removeTaxi(taxiId);
      return { statut: fin.statut };
    }
    return { statut: d.statut };
  }
}
