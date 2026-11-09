import { ConflictException, ForbiddenException, Injectable, NotFoundException, Optional } from '@nestjs/common';
import { randomUUID } from 'crypto';
import { haversine, Point } from '../domain/geo';
import { DemandeCourse, RidesService } from '../rides/rides.service';
import { StoreService } from '../store/store.service';

export type MotifAssistance = 'panne' | 'accident';
export type ActionAssistance = 'arrive' | 'reprend';

/** Réponse d'un collègue à l'appel à l'aide. */
export interface ReponseAssistance {
  taxiId: string;
  nom?: string;
  plaque?: string;
  type?: 'petit' | 'grand';
  action: ActionAssistance;
  le: string;
}

/**
 * Appel à l'aide d'un chauffeur (panne ou accident) : il part aux chauffeurs Bab Taxi en ligne autour de lui.
 * Ils peuvent venir l'aider (« J'arrive ») et un seul peut reprendre ses passagers (« Je prends les passagers »).
 */
export interface AlerteAssistance {
  id: string;
  taxiId: string;
  nom?: string;
  plaque?: string;
  type?: 'petit' | 'grand';
  motif: MotifAssistance;
  /** Accident avec des blessés : le chauffeur a été invité à appeler les secours (15 / 19 / 177). */
  blesses: boolean;
  position: Point;
  creeLe: string;
  statut: 'ouverte' | 'terminee';
  termineeLe?: string;
  /** Passagers de l'application à reprendre (places) et leurs destinations, au moment de l'appel. */
  passagers: number;
  destinations: string[];
  /** Chauffeurs en ligne à moins de [RAYON_ASSISTANCE_M] au moment de l'appel. */
  prevenus: number;
  reponses: ReponseAssistance[];
  reprisePar?: string;
  coursesReprises: string[];
}

/** Les chauffeurs à moins de 5 km reçoivent l'appel. */
export const RAYON_ASSISTANCE_M = 5000;
/** Un appel oublié se ferme seul après 2 heures. */
export const ASSISTANCE_EXPIRE_MS = 2 * 3600_000;

@Injectable()
export class AssistanceService {
  private readonly alertes = new Map<string, AlerteAssistance>();

  constructor(
    private readonly rides: RidesService,
    @Optional() private readonly store?: StoreService,
  ) {}

  now = () => Date.now();

  private iso() {
    return new Date(this.now()).toISOString();
  }

  private garder(a: AlerteAssistance) {
    this.store?.put('assistances', a.id, a);
    return a;
  }

  private expirer(a: AlerteAssistance) {
    if (a.statut === 'ouverte' && this.now() - Date.parse(a.creeLe) > ASSISTANCE_EXPIRE_MS) {
      a.statut = 'terminee';
      a.termineeLe = this.iso();
      this.garder(a);
    }
  }

  private find(id: string) {
    const a = this.alertes.get(id);
    if (!a) throw new NotFoundException('Appel introuvable');
    this.expirer(a);
    return a;
  }

  private places(courses: DemandeCourse[]) {
    return courses.reduce((n, d) => n + (d.demande.passagers ?? 1), 0);
  }

  /** Le chauffeur en panne ou accidenté appelle les taxis Bab Taxi autour de lui. Un seul appel ouvert par taxi. */
  creer(taxiId: string, motif: MotifAssistance, position: Point, blesses = false, nom?: string): AlerteAssistance {
    for (const a of this.alertes.values()) {
      this.expirer(a);
      if (a.taxiId === taxiId && a.statut === 'ouverte') {
        // Nouvel appui : même appel, position et gravité mises à jour.
        a.position = position;
        a.motif = motif;
        a.blesses = a.blesses || blesses;
        return this.garder(a);
      }
    }
    const taxi = this.rides.taxi(taxiId);
    const courses = this.rides.coursesEnCours(taxiId);
    const a: AlerteAssistance = {
      id: randomUUID(),
      taxiId,
      nom: taxi?.nom ?? nom,
      plaque: taxi?.plaque,
      type: taxi?.type,
      motif,
      blesses,
      position,
      creeLe: this.iso(),
      statut: 'ouverte',
      passagers: this.places(courses),
      destinations: courses.map((d) => d.demande.destinationNom ?? '').filter((n) => n),
      prevenus: this.rides.taxisEnLigne().filter((t) => t.id !== taxiId && haversine(t.position ?? t.itineraire[0], position) <= RAYON_ASSISTANCE_M).length,
      reponses: [],
      coursesReprises: [],
    };
    this.alertes.set(a.id, a);
    return this.garder(a);
  }

  get(id: string) {
    return this.find(id);
  }

  /** Appels ouverts autour d'un chauffeur (pas les siens), du plus proche au plus loin. */
  proches(taxiId: string, p: Point) {
    return [...this.alertes.values()]
      .filter((a) => {
        this.expirer(a);
        return a.statut === 'ouverte' && a.taxiId !== taxiId;
      })
      .map((a) => ({ ...a, distanceM: Math.round(haversine(a.position, p)) }))
      .filter((a) => a.distanceM <= RAYON_ASSISTANCE_M)
      .sort((x, y) => x.distanceM - y.distanceM);
  }

  /**
   * Un collègue répond. « reprend » : il prend les passagers (le premier gagne, les suivants reçoivent 409) ;
   * leurs courses passent sur son taxi, il les voit arriver dans son application.
   */
  repondre(id: string, taxiId: string, action: ActionAssistance): { alerte: AlerteAssistance; courses: DemandeCourse[] } {
    const a = this.find(id);
    if (a.statut !== 'ouverte') throw new ConflictException('Le chauffeur a terminé son appel');
    if (a.taxiId === taxiId) throw new ConflictException('Vous ne pouvez pas répondre à votre propre appel');
    const t = this.rides.taxi(taxiId);
    let courses: DemandeCourse[] = [];
    if (action === 'reprend') {
      if (a.reprisePar && a.reprisePar !== taxiId) throw new ConflictException('Un autre chauffeur reprend déjà les passagers');
      if (!a.reprisePar) {
        courses = this.rides.transferer(a.taxiId, taxiId, a.position, a.motif, a.id, a.nom);
        a.reprisePar = taxiId;
        a.coursesReprises = [...a.coursesReprises, ...courses.map((d) => d.id)];
      }
    }
    a.reponses = [
      ...a.reponses.filter((r) => r.taxiId !== taxiId),
      { taxiId, nom: t?.nom, plaque: t?.plaque, type: t?.type, action, le: this.iso() },
    ];
    return { alerte: this.garder(a), courses };
  }

  /** Le collègue annule sa venue (il ne peut plus venir). Les passagers déjà repris restent à lui. */
  retirer(id: string, taxiId: string) {
    const a = this.find(id);
    if (a.reprisePar === taxiId) return a;
    a.reponses = a.reponses.filter((r) => r.taxiId !== taxiId);
    return this.garder(a);
  }

  /** Problème réglé (ou dépanneuse arrivée) : seul le chauffeur qui a appelé peut fermer son appel. */
  terminer(id: string, taxiId: string) {
    const a = this.find(id);
    if (a.taxiId !== taxiId) throw new ForbiddenException("Seul le chauffeur qui a appelé peut fermer l'appel");
    if (a.statut === 'ouverte') {
      a.statut = 'terminee';
      a.termineeLe = this.iso();
    }
    return this.garder(a);
  }

  /** Console d'administration : appels ouverts. */
  ouvertes() {
    return [...this.alertes.values()].filter((a) => {
      this.expirer(a);
      return a.statut === 'ouverte';
    });
  }
}
