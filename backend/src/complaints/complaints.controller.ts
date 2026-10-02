import { BadRequestException, Body, Controller, Get, Param, Post } from '@nestjs/common';
import { randomUUID } from 'crypto';

export const MOTIFS = ['refus', 'prix_abusif', 'conduite_dangereuse', 'comportement', 'objet_oublie', 'autre'] as const;
type Motif = (typeof MOTIFS)[number];

interface Plainte {
  id: string;
  courseId?: string;
  taxiId?: string;
  motif: Motif;
  message?: string;
  statut: 'recue' | 'en_cours' | 'traitee';
  creeLe: string;
}

/** Plaintes des passagers et des chauffeurs. Stockage en mémoire pour la première version. */
@Controller('complaints')
export class ComplaintsController {
  private readonly plaintes = new Map<string, Plainte>();

  @Post()
  create(@Body() body: { courseId?: string; taxiId?: string; motif: Motif; message?: string }) {
    if (!MOTIFS.includes(body?.motif)) throw new BadRequestException(`motif doit être l'un de : ${MOTIFS.join(', ')}`);
    const plainte: Plainte = { ...body, id: randomUUID(), statut: 'recue', creeLe: new Date().toISOString() };
    this.plaintes.set(plainte.id, plainte);
    return plainte;
  }

  @Get(':id')
  get(@Param('id') id: string) {
    return this.plaintes.get(id) ?? { erreur: 'Plainte introuvable' };
  }
}
