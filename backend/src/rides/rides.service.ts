import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { randomUUID } from 'crypto';
import { haversine, Point } from '../domain/geo';
import { Correspondance, DemandePassager, TaxiEnRoute, trouverTaxis } from '../domain/matching';

export type StatutCourse = 'en_attente' | 'acceptee' | 'a_bord' | 'terminee' | 'annulee' | 'expiree';

export interface DemandeCourse {
  id: string;
  demande: DemandePassager;
  /** Taxis sur la route du passager qui ont reçu la demande. */
  proposeeA: Correspondance[];
  statut: StatutCourse;
  accepteePar?: string;
  creeLe: string;
  /** Chauffeurs qui ont refusé : la demande ne leur est plus proposée. */
  refuseePar: string[];
}

/** Taxi vu par le passager : profil et position en direct. */
export interface TaxiPublic {
  id: string;
  nom?: string;
  plaque?: string;
  type: TaxiEnRoute['type'];
  position: Point;
}

/** Un taxi qui n'envoie plus sa position depuis ce délai est considéré hors ligne. */
export const TAXI_HORS_LIGNE_MS = 90_000;
/** Une demande sans réponse expire après ce délai. */
export const DEMANDE_EXPIRE_MS = 3 * 60_000;

/**
 * Stockage en mémoire pour la première version (un seul serveur, test réel).
 * À remplacer par PostgreSQL + PostGIS et des WebSockets pour les positions en direct.
 */
@Injectable()
export class RidesService {
  private readonly taxis = new Map<string, TaxiEnRoute & { majLe: number }>();
  private readonly demandes = new Map<string, DemandeCourse>();

  /** Horloge remplaçable dans les tests. */
  now = () => Date.now();

  updateTaxi(taxi: TaxiEnRoute) {
    this.taxis.set(taxi.id, { ...taxi, position: taxi.position ?? taxi.itineraire[0], majLe: this.now() });
  }

  removeTaxi(id: string) {
    this.taxis.delete(id);
  }

  private actifs(): TaxiEnRoute[] {
    const limite = this.now() - TAXI_HORS_LIGNE_MS;
    return [...this.taxis.values()].filter((t) => t.majLe >= limite);
  }

  private public(t: TaxiEnRoute): TaxiPublic {
    return { id: t.id, nom: t.nom, plaque: t.plaque, type: t.type, position: t.position ?? t.itineraire[0] };
  }

  /** Taxis en ligne autour d'un point (carte du passager). */
  nearby(p: Point, rayonM = 5000): TaxiPublic[] {
    return this.actifs()
      .filter((t) => haversine(t.position ?? t.itineraire[0], p) <= rayonM)
      .map((t) => this.public(t));
  }

  match(demande: DemandePassager) {
    return trouverTaxis(demande, this.actifs());
  }

  /** Le passager commande : la demande part à tous les taxis qui passent sur sa route. */
  createRequest(demande: DemandePassager): DemandeCourse {
    const d: DemandeCourse = {
      id: randomUUID(),
      demande,
      proposeeA: this.match(demande),
      statut: 'en_attente',
      creeLe: new Date(this.now()).toISOString(),
      refuseePar: [],
    };
    this.demandes.set(d.id, d);
    return d;
  }

  private expirer(d: DemandeCourse) {
    if (d.statut === 'en_attente' && this.now() - Date.parse(d.creeLe) > DEMANDE_EXPIRE_MS) d.statut = 'expiree';
  }

  private find(id: string): DemandeCourse {
    const d = this.demandes.get(id);
    if (!d) throw new NotFoundException('Demande introuvable');
    this.expirer(d);
    return d;
  }

  /** La demande, avec le taxi qui l'a acceptée et sa position en direct. */
  getRequest(id: string): DemandeCourse & { taxi?: TaxiPublic } {
    const d = this.find(id);
    const t = d.accepteePar ? this.taxis.get(d.accepteePar) : undefined;
    return t ? { ...d, taxi: this.public(t) } : d;
  }

  /**
   * Demandes encore ouvertes proposées à un taxi. Le calcul est refait à chaque fois : un taxi
   * qui passe en ligne après la demande la reçoit aussi s'il passe sur la route du passager.
   */
  offersFor(taxiId: string): DemandeCourse[] {
    const taxi = this.actifs().find((t) => t.id === taxiId);
    return [...this.demandes.values()].filter((d) => {
      this.expirer(d);
      if (d.statut !== 'en_attente' || d.refuseePar.includes(taxiId)) return false;
      if (d.proposeeA.some((c) => c.taxiId === taxiId)) return true;
      return !!taxi && trouverTaxis(d.demande, [taxi]).length > 0;
    });
  }

  /** Courses acceptées et pas encore terminées d'un taxi (reprise après redémarrage de l'appli). */
  ridesOf(taxiId: string): DemandeCourse[] {
    return [...this.demandes.values()].filter(
      (d) => d.accepteePar === taxiId && (d.statut === 'acceptee' || d.statut === 'a_bord'),
    );
  }

  /**
   * Le premier chauffeur qui accepte prend la course ; la demande est alors bloquée pour les autres.
   * Node.js traite les requêtes une par une, donc la vérification et la mise à jour ne peuvent pas
   * être entrelacées. Avec une base de données, il faudra un UPDATE ... WHERE statut = 'en_attente'.
   */
  accept(id: string, taxiId: string): DemandeCourse {
    const d = this.find(id);
    if (!this.offersFor(taxiId).includes(d) && d.statut === 'en_attente') {
      throw new ConflictException("Cette demande n'a pas été proposée à ce taxi");
    }
    if (d.statut !== 'en_attente') {
      throw new ConflictException('Course déjà prise par un autre chauffeur');
    }
    d.statut = 'acceptee';
    d.accepteePar = taxiId;
    return d;
  }

  decline(id: string, taxiId: string): DemandeCourse {
    const d = this.find(id);
    if (!d.refuseePar.includes(taxiId)) d.refuseePar.push(taxiId);
    return d;
  }

  /** Le chauffeur a pris le passager, puis l'a déposé. */
  advance(id: string, taxiId: string, statut: 'a_bord' | 'terminee'): DemandeCourse {
    const d = this.find(id);
    if (d.accepteePar !== taxiId) throw new ConflictException("Cette course n'est pas à ce taxi");
    if (d.statut === 'annulee') throw new ConflictException('Course annulée par le passager');
    d.statut = statut;
    return d;
  }

  cancel(id: string): DemandeCourse {
    const d = this.find(id);
    if (d.statut === 'en_attente' || d.statut === 'acceptee') d.statut = 'annulee';
    return d;
  }
}
