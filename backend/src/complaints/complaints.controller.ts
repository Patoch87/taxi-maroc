import { BadRequestException, Body, Controller, Get, Param, Post } from '@nestjs/common';
import { randomUUID } from 'crypto';
import { StoreService } from '../store/store.service';

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

/** Plaintes des passagers et des chauffeurs, gardées dans la base. */
@Controller('complaints')
export class ComplaintsController {
  constructor(private readonly store: StoreService) {}

  @Post()
  create(@Body() body: { courseId?: string; taxiId?: string; motif: Motif; message?: string }) {
    if (!MOTIFS.includes(body?.motif)) throw new BadRequestException(`motif doit être l'un de : ${MOTIFS.join(', ')}`);
    const plainte: Plainte = { ...body, id: randomUUID(), statut: 'recue', creeLe: new Date().toISOString() };
    return this.store.put('plaintes', plainte.id, plainte);
  }

  @Get(':id')
  get(@Param('id') id: string) {
    return this.store.get<Plainte>('plaintes', id) ?? { erreur: 'Plainte introuvable' };
  }
}
