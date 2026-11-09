import { BadRequestException, Body, Controller, Get, Param, Post, Query } from '@nestjs/common';
import { Point } from '../domain/geo';
import { ActionAssistance, AssistanceService, MotifAssistance } from './assistance.service';

const point = (p: unknown): Point => {
  const q = p as Point | undefined;
  if (!q || !Number.isFinite(q.lat) || !Number.isFinite(q.lng)) throw new BadRequestException('position est requise');
  return { lat: q.lat, lng: q.lng };
};

const taxiId = (id: unknown): string => {
  if (typeof id !== 'string' || !/^[A-Za-z0-9_-]{1,64}$/.test(id)) throw new BadRequestException('taxiId est requis');
  return id;
};

/** Entraide entre chauffeurs : panne ou accident, appel aux taxis Bab Taxi proches. */
@Controller('assistance')
export class AssistanceController {
  constructor(private readonly assistance: AssistanceService) {}

  @Post()
  creer(@Body() body: { taxiId?: string; motif?: string; position?: Point; blesses?: boolean; nom?: string }) {
    const motif = body?.motif;
    if (motif !== 'panne' && motif !== 'accident') throw new BadRequestException('motif : panne ou accident');
    return this.assistance.creer(taxiId(body.taxiId), motif as MotifAssistance, point(body.position), body.blesses === true,
      typeof body.nom === 'string' ? body.nom.slice(0, 60) : undefined);
  }

  /** Appels ouverts autour du chauffeur (moins de 5 km). */
  @Get('proches')
  proches(@Query('taxiId') id: string, @Query('lat') lat: string, @Query('lng') lng: string) {
    return this.assistance.proches(taxiId(id), point({ lat: Number(lat), lng: Number(lng) }));
  }

  @Get(':id')
  get(@Param('id') id: string) {
    return this.assistance.get(id);
  }

  /** « J'arrive » (arrive) ou « Je prends les passagers » (reprend). */
  @Post(':id/reponse')
  repondre(@Param('id') id: string, @Body() body: { taxiId?: string; action?: string }) {
    const action = body?.action;
    if (action !== 'arrive' && action !== 'reprend') throw new BadRequestException('action : arrive ou reprend');
    return this.assistance.repondre(id, taxiId(body.taxiId), action as ActionAssistance);
  }

  @Post(':id/retrait')
  retirer(@Param('id') id: string, @Body() body: { taxiId?: string }) {
    return this.assistance.retirer(id, taxiId(body?.taxiId));
  }

  /** Problème réglé : l'appel est fermé. */
  @Post(':id/fin')
  terminer(@Param('id') id: string, @Body() body: { taxiId?: string }) {
    return this.assistance.terminer(id, taxiId(body?.taxiId));
  }
}
