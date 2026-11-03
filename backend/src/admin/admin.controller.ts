import { BadRequestException, Body, Controller, ForbiddenException, Get, Header, Headers, HttpCode, Param, Post, Query, Req, Res } from '@nestjs/common';
import { readFileSync } from 'fs';
import { dirname, join } from 'path';
import { IncomingMessage, ServerResponse } from 'http';
import { AdsService, SaisiePublicite } from '../ads/ads.service';
import { DriversService } from '../drivers/drivers.service';
import { CONSOLE } from './console-page';
import { AdminService } from './admin.service';

const VENDOR: Record<string, string> = {
  'leaflet.js': require.resolve('leaflet/dist/leaflet.js'),
  'leaflet.css': require.resolve('leaflet/dist/leaflet.css'),
  // chart.js n'exporte pas ce chemin : on le prend à côté de son point d'entrée (dist/chart.cjs).
  'chart.js': join(dirname(require.resolve('chart.js')), 'chart.umd.js'),
};

/** Clé de la console : BAB_ADMIN_TOKEN (sinon celle du centre de sécurité). */
export function cleAdmin() {
  return process.env.BAB_ADMIN_TOKEN || process.env.SOS_CENTRE_TOKEN || '';
}

/**
 * Console d'administration Bab Taxi : https://bab-taxi-eu.onrender.com/admin
 * La page se charge sans clé ; toutes les données passent par /admin/api/… avec la clé (en-tête x-cle-admin).
 */
@Controller('admin')
export class AdminController {
  constructor(
    private readonly admin: AdminService,
    private readonly drivers: DriversService,
    private readonly ads: AdsService,
  ) {}

  private verifier(entete?: string, query?: string) {
    const attendue = cleAdmin();
    const cle = (entete || query || '').trim();
    if (!attendue || cle !== attendue) throw new ForbiddenException('Clé invalide');
  }

  /** Carte et graphiques servis par le serveur lui-même (pas de dépendance à un CDN, réseaux d'administration filtrés). */
  @Get('vendor/:fichier')
  vendor(@Param('fichier') fichier: string, @Res() res: ServerResponse) {
    const chemin = VENDOR[fichier];
    if (!chemin) {
      res.statusCode = 404;
      return res.end();
    }
    res.setHeader('Content-Type', fichier.endsWith('.css') ? 'text/css; charset=utf-8' : 'application/javascript; charset=utf-8');
    res.setHeader('Cache-Control', 'public, max-age=86400');
    res.end(readFileSync(chemin));
  }

  @Get()
  @Header('Content-Type', 'text/html; charset=utf-8')
  @Header('Cache-Control', 'no-store')
  page() {
    return CONSOLE;
  }

  /** Vérifie la clé saisie à la connexion et donne les liens utiles. */
  @Get('api/session')
  session(@Headers('x-cle-admin') h?: string, @Query('cle') q?: string) {
    this.verifier(h, q);
    const sos = process.env.SOS_CENTRE_TOKEN;
    // Clé Google Maps (navigateur) pour la carte en temps réel ; sans clé, la console utilise OpenStreetMap.
    const carte = process.env.GOOGLE_MAPS_API_KEY || process.env.MAPS_API_KEY || '';
    return { ok: true, sosCentre: sos ? `/sos/centre?cle=${encodeURIComponent(sos)}` : null, cleCarte: carte };
  }

  @Get('api/resume')
  resume(@Headers('x-cle-admin') h?: string, @Query('cle') q?: string) {
    this.verifier(h, q);
    return this.admin.resume();
  }

  @Get('api/temps-reel')
  tempsReel(@Headers('x-cle-admin') h?: string, @Query('cle') q?: string) {
    this.verifier(h, q);
    return this.admin.tempsReel();
  }

  @Get('api/chauffeurs')
  chauffeurs(@Headers('x-cle-admin') h?: string, @Query('cle') q?: string) {
    this.verifier(h, q);
    return this.admin.chauffeurs();
  }

  /** Valider, refuser (motif), suspendre (motif) ou réactiver un chauffeur. */
  @Post('api/chauffeurs/:id/decision')
  @HttpCode(200)
  decision(
    @Param('id') id: string,
    @Body() corps: { decision?: string; motif?: string },
    @Headers('x-cle-admin') h?: string,
    @Query('cle') q?: string,
  ) {
    this.verifier(h, q);
    return this.drivers.vue(this.drivers.decider(id, corps?.decision ?? '', corps?.motif));
  }

  @Get('api/passagers')
  passagers(@Headers('x-cle-admin') h?: string, @Query('cle') q?: string) {
    this.verifier(h, q);
    return this.admin.passagers();
  }

  @Post('api/passagers/:id/blocage')
  @HttpCode(200)
  blocage(
    @Param('id') id: string,
    @Body() corps: { bloque?: boolean; motif?: string },
    @Headers('x-cle-admin') h?: string,
    @Query('cle') q?: string,
  ) {
    this.verifier(h, q);
    return this.admin.bloquerPassager(id, !!corps?.bloque, corps?.motif);
  }

  @Get('api/courses')
  courses(@Headers('x-cle-admin') h?: string, @Query('cle') q?: string) {
    this.verifier(h, q);
    return this.admin.courses();
  }

  /** Annule d'un coup toutes les courses en cours (essais, incident). */
  @Post('api/courses/annuler-en-cours')
  annulerEnCours(@Headers('x-cle-admin') h?: string, @Query('cle') q?: string) {
    this.verifier(h, q);
    return this.admin.annulerCoursesEnCours();
  }

  /** Export Excel (CSV) : lien direct avec ?cle=… */
  @Get('api/courses.csv')
  csv(@Res() res: ServerResponse, @Headers('x-cle-admin') h?: string, @Query('cle') q?: string) {
    this.verifier(h, q);
    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader('Content-Disposition', `attachment; filename="bab-taxi-courses-${new Date().toISOString().slice(0, 10)}.csv"`);
    res.end(this.admin.coursesCsv());
  }

  @Get('api/reporting')
  reporting(@Query('jours') jours?: string, @Headers('x-cle-admin') h?: string, @Query('cle') q?: string) {
    this.verifier(h, q);
    return this.admin.reporting(Number(jours ?? 30));
  }

  @Get('api/plaintes')
  plaintes(@Headers('x-cle-admin') h?: string, @Query('cle') q?: string) {
    this.verifier(h, q);
    return this.admin.listePlaintes();
  }

  @Post('api/plaintes/:id')
  @HttpCode(200)
  plainte(
    @Param('id') id: string,
    @Body() corps: { statut?: string; reponse?: string },
    @Headers('x-cle-admin') h?: string,
    @Query('cle') q?: string,
  ) {
    this.verifier(h, q);
    return this.admin.traiterPlainte(id, corps?.statut ?? '', corps?.reponse);
  }

  // ---------- Publicités ----------

  @Get('api/publicites')
  publicites(@Headers('x-cle-admin') h?: string, @Query('cle') q?: string) {
    this.verifier(h, q);
    return this.ads.pourConsole();
  }

  @Post('api/publicites')
  @HttpCode(201)
  creerPublicite(@Body() corps: SaisiePublicite, @Headers('x-cle-admin') h?: string, @Query('cle') q?: string) {
    this.verifier(h, q);
    return this.ads.creer(corps ?? {});
  }

  @Post('api/publicites/:id')
  @HttpCode(200)
  modifierPublicite(@Param('id') id: string, @Body() corps: SaisiePublicite, @Headers('x-cle-admin') h?: string, @Query('cle') q?: string) {
    this.verifier(h, q);
    return this.ads.modifier(id, corps ?? {});
  }

  @Post('api/publicites/:id/supprimer')
  @HttpCode(200)
  supprimerPublicite(@Param('id') id: string, @Headers('x-cle-admin') h?: string, @Query('cle') q?: string) {
    this.verifier(h, q);
    return this.ads.supprimer(id);
  }

  /** Logo de l'annonceur : corps brut image/png, image/jpeg ou image/webp (1 Mo au plus). */
  @Post('api/publicites/:id/image')
  @HttpCode(200)
  async imagePublicite(@Param('id') id: string, @Req() req: IncomingMessage, @Headers('x-cle-admin') h?: string, @Query('cle') q?: string) {
    this.verifier(h, q);
    const type = String(req.headers['content-type'] ?? '').split(';')[0].trim();
    const donnees = await new Promise<Buffer>((ok, ko) => {
      const parts: Buffer[] = [];
      let taille = 0;
      req.on('data', (c: Buffer) => {
        taille += c.length;
        if (taille > 1_000_000) {
          ko(new BadRequestException('image trop lourde (1 Mo au plus)'));
          req.destroy();
        } else parts.push(c);
      });
      req.on('end', () => ok(Buffer.concat(parts)));
      req.on('error', ko);
    });
    return this.ads.mettreImage(id, type, donnees);
  }

  @Post('api/publicites/:id/image/retirer')
  @HttpCode(200)
  retirerImagePublicite(@Param('id') id: string, @Headers('x-cle-admin') h?: string, @Query('cle') q?: string) {
    this.verifier(h, q);
    return this.ads.retirerImage(id);
  }
}
