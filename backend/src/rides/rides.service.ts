import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { randomUUID } from 'crypto';
import { Correspondance, DemandePassager, TaxiEnRoute, trouverTaxis } from '../domain/matching';

export interface DemandeCourse {
  id: string;
  demande: DemandePassager;
  /** Taxis sur la route du passager qui ont reçu la demande. */
  proposeeA: Correspondance[];
  statut: 'en_attente' | 'acceptee' | 'annulee';
  accepteePar?: string;
  creeLe: string;
}

/**
 * Stockage en mémoire pour la première version.
 * À remplacer par PostgreSQL + PostGIS et des WebSockets pour les positions en direct.
 */
@Injectable()
export class RidesService {
  private readonly taxis = new Map<string, TaxiEnRoute>();
  private readonly demandes = new Map<string, DemandeCourse>();

  updateTaxi(taxi: TaxiEnRoute) {
    this.taxis.set(taxi.id, taxi);
  }

  removeTaxi(id: string) {
    this.taxis.delete(id);
  }

  match(demande: DemandePassager) {
    return trouverTaxis(demande, [...this.taxis.values()]);
  }

  /** Le passager commande : la demande part à tous les taxis qui passent sur sa route. */
  createRequest(demande: DemandePassager): DemandeCourse {
    const d: DemandeCourse = {
      id: randomUUID(),
      demande,
      proposeeA: this.match(demande),
      statut: 'en_attente',
      creeLe: new Date().toISOString(),
    };
    this.demandes.set(d.id, d);
    return d;
  }

  getRequest(id: string): DemandeCourse {
    const d = this.demandes.get(id);
    if (!d) throw new NotFoundException('Demande introuvable');
    return d;
  }

  /** Demandes encore ouvertes proposées à un taxi. */
  offersFor(taxiId: string): DemandeCourse[] {
    return [...this.demandes.values()].filter(
      (d) => d.statut === 'en_attente' && d.proposeeA.some((c) => c.taxiId === taxiId),
    );
  }

  /**
   * Le premier chauffeur qui accepte prend la course ; la demande est alors bloquée pour les autres.
   * Node.js traite les requêtes une par une, donc la vérification et la mise à jour ne peuvent pas
   * être entrelacées. Avec une base de données, il faudra un UPDATE ... WHERE statut = 'en_attente'.
   */
  accept(id: string, taxiId: string): DemandeCourse {
    const d = this.getRequest(id);
    if (!d.proposeeA.some((c) => c.taxiId === taxiId)) {
      throw new ConflictException("Cette demande n'a pas été proposée à ce taxi");
    }
    if (d.statut !== 'en_attente') {
      throw new ConflictException('Course déjà prise par un autre chauffeur');
    }
    d.statut = 'acceptee';
    d.accepteePar = taxiId;
    return d;
  }

  cancel(id: string): DemandeCourse {
    const d = this.getRequest(id);
    if (d.statut === 'en_attente') d.statut = 'annulee';
    return d;
  }
}
