import { Injectable } from '@nestjs/common';
import { DemandePassager, TaxiEnRoute, trouverTaxis } from '../domain/matching';

/**
 * Stockage en mémoire pour la première version.
 * À remplacer par PostgreSQL + PostGIS et des WebSockets pour les positions en direct.
 */
@Injectable()
export class RidesService {
  private readonly taxis = new Map<string, TaxiEnRoute>();

  updateTaxi(taxi: TaxiEnRoute) {
    this.taxis.set(taxi.id, taxi);
  }

  removeTaxi(id: string) {
    this.taxis.delete(id);
  }

  match(demande: DemandePassager) {
    return trouverTaxis(demande, [...this.taxis.values()]);
  }
}
