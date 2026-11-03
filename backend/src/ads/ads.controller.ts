import { BadRequestException, Body, Controller, Get, HttpCode, NotFoundException, Param, Post, Query, Res } from '@nestjs/common';
import { ServerResponse } from 'http';
import { EMPLACEMENTS, Emplacement } from './ads';
import { AdsService } from './ads.service';

type Evenement = 'vue' | 'clic' | 'bon';

/**
 * Publicités diffusées dans l'application (gérées dans la console, module « Publicités ») et compteurs
 * de vues / clics / bons, gardés dans la base (facturation des annonceurs).
 */
@Controller('ads')
export class AdsController {
  constructor(private readonly ads: AdsService) {}

  @Get()
  list(@Query('emplacement') emplacement?: string) {
    if (emplacement && !EMPLACEMENTS.includes(emplacement as Emplacement)) {
      throw new BadRequestException(`emplacement doit être l'un de : ${EMPLACEMENTS.join(', ')}`);
    }
    return this.ads.actives(emplacement);
  }

  @Post(':id/events')
  @HttpCode(204)
  event(@Param('id') id: string, @Body() body: { type?: Evenement }) {
    if (!this.ads.existe(id)) throw new NotFoundException('Publicité inconnue');
    const type = body?.type ?? 'vue';
    if (!['vue', 'clic', 'bon'].includes(type)) throw new BadRequestException('type : vue, clic ou bon');
    this.ads.compter(id, type);
  }

  @Get(':id/stats')
  statsFor(@Param('id') id: string) {
    if (!this.ads.existe(id)) throw new NotFoundException('Publicité inconnue');
    return { id, ...this.ads.stats(id) };
  }

  /** Logo de l'annonceur, affiché dans l'application. */
  @Get(':id/image')
  async image(@Param('id') id: string, @Res() res: ServerResponse) {
    const f = this.ads.existe(id) ? await this.ads.image(id) : undefined;
    if (!f) {
      res.statusCode = 404;
      return res.end();
    }
    res.setHeader('Content-Type', f.type);
    res.setHeader('Cache-Control', 'public, max-age=86400');
    res.end(f.donnees);
  }
}
