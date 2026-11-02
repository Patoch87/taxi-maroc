import {
  BadRequestException,
  Body,
  Controller,
  ForbiddenException,
  Get,
  Header,
  Headers,
  HttpCode,
  NotFoundException,
  Param,
  Post,
  Query,
  Req,
  Res,
} from '@nestjs/common';
import { IncomingMessage, ServerResponse } from 'http';
import { DriversService, PIECES } from './drivers.service';
import { PAGE_DOSSIERS } from './admin-page';

function lireCorps(req: IncomingMessage, max: number): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    const parts: Buffer[] = [];
    let taille = 0;
    req.on('data', (c: Buffer) => {
      taille += c.length;
      if (taille > max) {
        reject(new BadRequestException('photo trop lourde'));
        req.destroy();
      } else parts.push(c);
    });
    req.on('end', () => resolve(Buffer.concat(parts)));
    req.on('error', reject);
  });
}

/**
 * Clé de la page des dossiers chauffeurs (BAB_ADMIN_TOKEN, sinon celle du centre de sécurité).
 * Les documents (CIN, casier judiciaire...) ne sont lisibles qu'avec cette clé : loi 09-08.
 */
function verifierCle(cle?: string) {
  const attendue = process.env.BAB_ADMIN_TOKEN || process.env.SOS_CENTRE_TOKEN;
  if (!attendue || cle !== attendue) throw new ForbiddenException('Accès réservé à Bab Taxi');
}

@Controller()
export class DriversController {
  constructor(private readonly drivers: DriversService) {}

  /** Photo ou document du dossier (corps brut image/jpeg). */
  @Post('chauffeurs/:id/pieces/:piece')
  async piece(
    @Param('id') id: string,
    @Param('piece') piece: string,
    @Req() req: IncomingMessage,
    @Headers('content-type') type = 'image/jpeg',
  ) {
    const donnees = await lireCorps(req, 4 * 1024 * 1024 + 1);
    return { id: await this.drivers.ajouterPiece(id, piece, type.split(';')[0].trim(), donnees) };
  }

  @Post('chauffeurs/:id/dossier')
  @HttpCode(200)
  async envoyer(@Param('id') id: string, @Body() corps: Record<string, unknown>) {
    return this.drivers.vue(await this.drivers.envoyer(id, corps ?? {}));
  }

  /** État du dossier, lu par l'application chauffeur. */
  @Get('chauffeurs/:id')
  etat(@Param('id') id: string) {
    const d = this.drivers.get(id);
    if (!d) throw new NotFoundException('aucun dossier');
    return this.drivers.vue(d);
  }

  /** Photo du chauffeur validé, montrée au passager. */
  @Get('chauffeurs/:id/photo')
  async photo(@Param('id') id: string, @Res() res: ServerResponse) {
    const d = this.drivers.get(id);
    const f = d?.statut === 'valide' ? await this.drivers.fichier(d.pieces.photo) : undefined;
    if (!f) {
      res.statusCode = 404;
      return res.end();
    }
    res.setHeader('Content-Type', f.type);
    res.setHeader('Cache-Control', 'public, max-age=3600');
    res.end(f.donnees);
  }

  // ---------- Page de Bab Taxi : vérification des dossiers ----------

  @Get('admin/chauffeurs')
  @Header('Content-Type', 'text/html; charset=utf-8')
  @Header('Cache-Control', 'no-store')
  page(@Query('cle') cle?: string) {
    verifierCle(cle);
    return PAGE_DOSSIERS;
  }

  @Get('admin/chauffeurs.json')
  @Header('Cache-Control', 'no-store')
  liste(@Query('cle') cle?: string) {
    verifierCle(cle);
    return this.drivers.liste().map((d) => ({ ...d, nomPublic: this.drivers.nomPublic(d), pieces: PIECES.map((p) => [p, d.pieces[p]]) }));
  }

  @Get('admin/fichiers/:fid')
  async fichier(@Param('fid') fid: string, @Query('cle') cle: string | undefined, @Res() res: ServerResponse) {
    verifierCle(cle);
    const f = fid.startsWith('chauffeur-') ? await this.drivers.fichier(fid) : undefined;
    if (!f) {
      res.statusCode = 404;
      return res.end();
    }
    res.setHeader('Content-Type', f.type);
    res.setHeader('Cache-Control', 'private, no-store');
    res.end(f.donnees);
  }

  @Post('admin/chauffeurs/:id/decision')
  @HttpCode(200)
  decider(@Param('id') id: string, @Query('cle') cle: string | undefined, @Body() corps: { decision?: string; motif?: string }) {
    verifierCle(cle);
    return this.drivers.vue(this.drivers.decider(id, corps?.decision ?? '', corps?.motif));
  }
}
