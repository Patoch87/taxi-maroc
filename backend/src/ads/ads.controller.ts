import { BadRequestException, Body, Controller, Get, HttpCode, NotFoundException, Param, Post, Query } from '@nestjs/common';
import { StoreService } from '../store/store.service';
import { EMPLACEMENTS, Emplacement, PUBLICITES } from './ads';

type Evenement = 'vue' | 'clic' | 'bon';

/** Publicités (annonceurs fictifs) et compteurs de vues / clics, gardés dans la base (facturation des annonceurs). */
@Controller('ads')
export class AdsController {
  constructor(private readonly store: StoreService) {}

  @Get()
  list(@Query('emplacement') emplacement?: string) {
    if (emplacement && !EMPLACEMENTS.includes(emplacement as Emplacement)) {
      throw new BadRequestException(`emplacement doit être l'un de : ${EMPLACEMENTS.join(', ')}`);
    }
    return PUBLICITES.filter((p) => !emplacement || p.emplacement === emplacement);
  }

  @Post(':id/events')
  @HttpCode(204)
  event(@Param('id') id: string, @Body() body: { type?: Evenement }) {
    if (!PUBLICITES.some((p) => p.id === id)) throw new NotFoundException('Publicité inconnue');
    const type = body?.type ?? 'vue';
    if (!['vue', 'clic', 'bon'].includes(type)) throw new BadRequestException('type : vue, clic ou bon');
    const s = { ...(this.store.get<Record<Evenement, number>>('pub_stats', id) ?? { vue: 0, clic: 0, bon: 0 }) };
    s[type] += 1;
    this.store.put('pub_stats', id, s);
  }

  @Get(':id/stats')
  statsFor(@Param('id') id: string) {
    if (!PUBLICITES.some((p) => p.id === id)) throw new NotFoundException('Publicité inconnue');
    return { id, ...(this.store.get<Record<Evenement, number>>('pub_stats', id) ?? { vue: 0, clic: 0, bon: 0 }) };
  }
}
