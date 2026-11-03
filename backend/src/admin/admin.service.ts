import { BadRequestException, Injectable, NotFoundException, Optional } from '@nestjs/common';
import { AccountsService, Compte } from '../accounts/accounts.service';
import { AdsService } from '../ads/ads.service';
import { haversine } from '../domain/geo';
import { DossierChauffeur, DriversService } from '../drivers/drivers.service';
import { DemandeCourse, RidesService } from '../rides/rides.service';
import { alertesSos } from '../sos/sos.controller';
import { StoreService } from '../store/store.service';

interface Plainte {
  id: string;
  courseId?: string;
  taxiId?: string;
  motif: string;
  message?: string;
  statut: 'recue' | 'en_cours' | 'traitee';
  creeLe: string;
  reponse?: string;
  traiteeLe?: string;
}

const JOUR = 86_400_000;
const FUSEAU = 'Africa/Casablanca';
const jourDe = (iso: string) => new Intl.DateTimeFormat('fr-CA', { timeZone: FUSEAU }).format(new Date(iso));
const heureDe = (iso: string) =>
  Number(new Intl.DateTimeFormat('en-GB', { timeZone: FUSEAU, hour: 'numeric', hourCycle: 'h23' }).format(new Date(iso))) % 24;
const enCours = (d: DemandeCourse) => d.statut === 'en_attente' || d.statut === 'acceptee' || d.statut === 'a_bord';
const minutes = (a?: string, b?: string) => (a && b ? (Date.parse(b) - Date.parse(a)) / 60_000 : undefined);
const moyenne = (v: (number | undefined)[]) => {
  const n = v.filter((x): x is number => x !== undefined && Number.isFinite(x));
  return n.length ? Math.round((n.reduce((s, x) => s + x, 0) / n.length) * 10) / 10 : null;
};
const arrondi = (v: number) => Math.round(v * 100) / 100;

/**
 * Console d'administration Bab Taxi : chiffres, chauffeurs, passagers, courses, carte en temps réel.
 * Tout est calculé à la demande à partir des données du serveur (rien n'est inventé).
 */
@Injectable()
export class AdminService {
  constructor(
    private readonly store: StoreService,
    private readonly comptes: AccountsService,
    private readonly drivers: DriversService,
    private readonly rides: RidesService,
    @Optional() private readonly ads?: AdsService,
  ) {}

  now = () => Date.now();

  private plaintes(): Plainte[] {
    return this.store.list<Plainte>('plaintes').sort((a, b) => b.creeLe.localeCompare(a.creeLe));
  }

  /** Un passager : ses courses par compte de l'application ou par numéro WhatsApp. */
  private coursesDe(c: Compte, courses: DemandeCourse[]) {
    return courses.filter((d) => d.demande.passager?.id === c.id || (!!c.telephone && d.demande.passager?.telephone === c.telephone));
  }

  // ---------- Tableau de bord ----------

  resume() {
    const t = this.now();
    const courses = this.rides.toutes();
    const aujourdhui = jourDe(new Date(t).toISOString());
    const duJour = courses.filter((d) => jourDe(d.creeLe) === aujourdhui);
    const taxis = this.rides.taxisEnLigne();
    const dossiers = this.drivers.liste();
    const comptes = this.comptes.liste();
    const chauffeurs = new Set(dossiers.map((d) => d.id));
    const passagers = comptes.filter((c) => !chauffeurs.has(c.id));
    const terminees = (l: DemandeCourse[]) => l.filter((d) => d.statut === 'terminee');
    const ca = (l: DemandeCourse[]) => arrondi(terminees(l).reduce((s, d) => s + (d.demande.prixMad ?? 0), 0));
    const sur = (jours: number) => courses.filter((d) => t - Date.parse(d.creeLe) <= jours * JOUR);
    const decides = sur(30).filter((d) => d.statut !== 'en_attente' && d.statut !== 'annulee');
    return {
      heure: new Date(t).toISOString(),
      taxis: {
        enLigne: taxis.length,
        libres: taxis.filter((x) => x.passagersABord === 0).length,
        occupes: taxis.filter((x) => x.passagersABord > 0).length,
        petits: taxis.filter((x) => x.type === 'petit').length,
        grands: taxis.filter((x) => x.type === 'grand').length,
      },
      courses: {
        enCours: courses.filter(enCours).length,
        aujourdhui: duJour.length,
        termineesAujourdhui: terminees(duJour).length,
        annuleesAujourdhui: duJour.filter((d) => d.statut === 'annulee').length,
        sansTaxiAujourdhui: duJour.filter((d) => d.statut === 'expiree').length,
        total: courses.length,
        whatsapp30j: sur(30).filter((d) => d.demande.source === 'whatsapp').length,
        // Courses acceptées par un chauffeur parmi celles qui ont eu une réponse (hors annulées par le passager).
        tauxAcceptation30j: decides.length ? Math.round((decides.filter((d) => d.accepteePar).length / decides.length) * 100) : null,
        delaiAcceptationMin: moyenne(sur(30).map((d) => minutes(d.creeLe, d.accepteeLe))),
        dureeCourseMin: moyenne(sur(30).map((d) => minutes(d.aBordLe, d.termineeLe))),
      },
      montants: {
        aujourdhui: ca(duJour),
        sept: ca(sur(7)),
        trente: ca(sur(30)),
        note: 'Estimation : prix annoncés des courses terminées (le prix réel est celui du compteur).',
      },
      chauffeurs: {
        total: dossiers.length,
        aVerifier: dossiers.filter((d) => d.statut === 'en_attente').length,
        valides: dossiers.filter((d) => d.statut === 'valide').length,
        refuses: dossiers.filter((d) => d.statut === 'refuse').length,
        suspendus: dossiers.filter((d) => d.statut === 'suspendu').length,
      },
      passagers: {
        total: passagers.length,
        nouveaux7j: passagers.filter((c) => t - Date.parse(c.creeLe) <= 7 * JOUR).length,
        bloques: passagers.filter((c) => c.bloque).length,
      },
      plaintesOuvertes: this.plaintes().filter((p) => p.statut !== 'traitee').length,
      sosEnDirect: [...alertesSos.values()].filter((a) => a.statut === 'en_direct').length,
    };
  }

  // ---------- Carte en temps réel ----------

  tempsReel() {
    const t = this.now();
    const courses = this.rides.toutes().filter(enCours);
    const parTaxi = new Map<string, DemandeCourse[]>();
    for (const d of courses) if (d.accepteePar) parTaxi.set(d.accepteePar, [...(parTaxi.get(d.accepteePar) ?? []), d]);
    return {
      heure: new Date(t).toISOString(),
      taxis: this.rides.taxisEnLigne().map((x) => {
        const dossier = this.drivers.get(x.id);
        const siennes = parTaxi.get(x.id) ?? [];
        const pos = x.position ?? x.itineraire[0];
        return {
          id: x.id,
          nom: dossier ? `${dossier.prenom} ${dossier.nom}` : (x.nom ?? 'Chauffeur'),
          plaque: x.plaque ?? dossier?.plaque ?? '',
          numero: dossier?.taxiNumero ?? '',
          type: x.type,
          position: pos,
          passagers: x.passagersABord,
          etat: siennes.some((d) => d.statut === 'a_bord') ? 'en_course' : siennes.length ? 'vers_client' : 'libre',
          vuIlYaS: Math.round((t - x.majLe) / 1000),
          // Itinéraire allégé (au plus 60 points) pour la carte.
          itineraire: x.itineraire.filter((_, i, a) => a.length <= 60 || i % Math.ceil(a.length / 60) === 0),
          courses: siennes.map((d) => ({ id: d.id, statut: d.statut, destination: d.demande.destinationNom })),
        };
      }),
      demandes: courses
        .filter((d) => d.statut === 'en_attente')
        .map((d) => ({
          id: d.id,
          depart: d.demande.depart,
          destination: d.demande.destination,
          destinationNom: d.demande.destinationNom,
          source: d.demande.source ?? 'app',
          depuisS: Math.round((t - Date.parse(d.creeLe)) / 1000),
          taxisPrevenus: d.proposeeA.length,
        })),
      nonValides: this.rides.nonValidesEnLigne().map((x) => {
        const dossier = this.drivers.get(x.id);
        return {
          id: x.id,
          nom: dossier ? `${dossier.prenom} ${dossier.nom}` : (x.nom ?? 'Chauffeur'),
          statut: dossier?.statut ?? 'sans_dossier',
          type: x.type ?? dossier?.taxiType ?? 'petit',
          position: x.position,
          vuIlYaS: Math.round((t - x.majLe) / 1000),
        };
      }),
      sos: [...alertesSos.values()]
        .filter((a) => a.statut === 'en_direct')
        .map((a) => ({ id: a.id, nom: a.nom, taxiId: a.taxiId, position: a.positions.at(-1), depuis: a.creeLe })),
    };
  }

  // ---------- Chauffeurs ----------

  chauffeurs() {
    const courses = this.rides.toutes();
    const enLigne = new Map(this.rides.taxisEnLigne().map((x) => [x.id, x]));
    const plaintes = this.plaintes();
    return this.drivers.liste().map((d: DossierChauffeur) => {
      const siennes = courses.filter((c) => c.accepteePar === d.id);
      const terminees = siennes.filter((c) => c.statut === 'terminee');
      const proposees = courses.filter((c) => c.proposeeA.some((p) => p.taxiId === d.id) || c.refuseePar.includes(d.id));
      return {
        id: d.id,
        prenom: d.prenom,
        nom: d.nom,
        telephone: d.telephone,
        ville: d.ville,
        cin: d.cin,
        permis: d.permis,
        cartePro: d.cartePro,
        taxiType: d.taxiType,
        taxiNumero: d.taxiNumero,
        plaque: d.plaque,
        langues: d.langues,
        statut: d.statut,
        motif: d.motif,
        envoyeLe: d.envoyeLe,
        decideLe: d.decideLe,
        pieces: Object.entries(d.pieces),
        enLigne: enLigne.has(d.id),
        position: enLigne.get(d.id)?.position,
        courses: terminees.length,
        refus: proposees.filter((c) => c.refuseePar.includes(d.id)).length,
        montant: arrondi(terminees.reduce((s, c) => s + (c.demande.prixMad ?? 0), 0)),
        derniereCourse: siennes[0]?.creeLe,
        plaintes: plaintes.filter((p) => p.taxiId === d.id || siennes.some((c) => c.id === p.courseId)).length,
      };
    });
  }

  // ---------- Passagers ----------

  passagers() {
    const courses = this.rides.toutes();
    const chauffeurs = new Set(this.drivers.liste().map((d) => d.id));
    return this.comptes
      .liste()
      .filter((c) => !chauffeurs.has(c.id))
      .sort((a, b) => b.creeLe.localeCompare(a.creeLe))
      .map((c) => {
        const siennes = this.coursesDe(c, courses);
        return {
          id: c.id,
          prenom: c.prenom,
          nom: c.nom,
          telephone: c.telephone,
          email: c.email,
          nationalite: c.nationalite,
          langue: c.langue,
          verifie: c.verifie,
          bloque: !!c.bloque,
          motifBlocage: c.motifBlocage,
          creeLe: c.creeLe,
          courses: siennes.length,
          terminees: siennes.filter((d) => d.statut === 'terminee').length,
          annulees: siennes.filter((d) => d.statut === 'annulee').length,
          whatsapp: siennes.filter((d) => d.demande.source === 'whatsapp').length,
          derniereCourse: siennes[0]?.creeLe,
        };
      });
  }

  bloquerPassager(id: string, bloque: boolean, motif?: string) {
    if (bloque && !(motif ?? '').trim()) throw new BadRequestException('motif obligatoire');
    const c = this.comptes.bloquer(id, bloque, motif);
    return { id: c.id, bloque: !!c.bloque };
  }

  // ---------- Courses ----------

  /** Annule toutes les courses en cours (bouton de la console). */
  annulerCoursesEnCours() {
    return this.rides.annulerToutesEnCours();
  }

  courses(limite = 300) {
    const dossiers = new Map(this.drivers.liste().map((d) => [d.id, d]));
    return this.rides
      .toutes()
      .slice(0, limite)
      .map((d) => {
        const ch = d.accepteePar ? dossiers.get(d.accepteePar) : undefined;
        return {
          id: d.id,
          creeLe: d.creeLe,
          statut: d.statut,
          source: d.demande.source ?? 'app',
          passager: d.demande.passager?.nom ?? '',
          destination: d.demande.destinationNom ?? '',
          mode: d.demande.categorie === 'premium' ? 'premium' : d.demande.mode,
          personnes: d.demande.passagers,
          prixMad: d.demande.prixMad ?? null,
          distanceKm: Math.round(haversine(d.demande.depart, d.demande.destination) / 100) / 10,
          chauffeur: ch ? `${ch.prenom} ${ch.nom}` : d.accepteePar ?? '',
          plaque: ch?.plaque ?? '',
          taxisPrevenus: d.proposeeA.length,
          delaiAcceptationMin: minutes(d.creeLe, d.accepteeLe),
          dureeMin: minutes(d.aBordLe, d.termineeLe),
        };
      });
  }

  /** Export pour tableur (séparateur « ; », lisible par Excel en français). */
  coursesCsv() {
    const lignes = this.courses(100_000);
    const cols = ['creeLe', 'statut', 'source', 'mode', 'personnes', 'destination', 'distanceKm', 'prixMad', 'chauffeur', 'plaque', 'taxisPrevenus', 'delaiAcceptationMin', 'dureeMin'] as const;
    const cel = (v: unknown) => {
      const s = v === null || v === undefined ? '' : typeof v === 'number' ? String(Math.round(v * 10) / 10).replace('.', ',') : String(v);
      return /[;"\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
    };
    return '﻿' + [cols.join(';'), ...lignes.map((l) => cols.map((c) => cel(l[c])).join(';'))].join('\n');
  }

  // ---------- Reporting ----------

  reporting(jours = 30) {
    const t = this.now();
    const j = Math.min(Math.max(Math.round(jours) || 30, 1), 365);
    const courses = this.rides.toutes().filter((d) => t - Date.parse(d.creeLe) <= j * JOUR);
    const jourList: string[] = [];
    for (let i = j - 1; i >= 0; i--) jourList.push(jourDe(new Date(t - i * JOUR).toISOString()));
    const parJour = new Map(jourList.map((x) => [x, { jour: x, demandes: 0, terminees: 0, annulees: 0, sansTaxi: 0, montant: 0 }]));
    const heures = Array.from({ length: 24 }, (_, h) => ({ heure: h, demandes: 0 }));
    const modes: Record<string, number> = { partage: 0, seul: 0, premium: 0 };
    const sources: Record<string, number> = { app: 0, whatsapp: 0 };
    const destinations = new Map<string, number>();
    for (const d of courses) {
      const p = parJour.get(jourDe(d.creeLe));
      if (p) {
        p.demandes++;
        if (d.statut === 'terminee') {
          p.terminees++;
          p.montant = arrondi(p.montant + (d.demande.prixMad ?? 0));
        }
        if (d.statut === 'annulee') p.annulees++;
        if (d.statut === 'expiree') p.sansTaxi++;
      }
      heures[heureDe(d.creeLe)].demandes++;
      modes[d.demande.categorie === 'premium' ? 'premium' : d.demande.mode]++;
      sources[d.demande.source ?? 'app']++;
      if (d.demande.destinationNom) destinations.set(d.demande.destinationNom, (destinations.get(d.demande.destinationNom) ?? 0) + 1);
    }
    const plaintes = this.plaintes().filter((p) => t - Date.parse(p.creeLe) <= j * JOUR);
    const motifs: Record<string, number> = {};
    for (const p of plaintes) motifs[p.motif] = (motifs[p.motif] ?? 0) + 1;
    return {
      jours: j,
      parJour: [...parJour.values()],
      parHeure: heures,
      modes,
      sources,
      topDestinations: [...destinations.entries()].sort((a, b) => b[1] - a[1]).slice(0, 10).map(([nom, n]) => ({ nom, n })),
      plaintes: { total: plaintes.length, motifs },
      publicites: (this.ads?.pourConsole() ?? []).map((p) => ({
        id: p.id, annonceur: p.annonceur, titre: p.titre, emplacement: p.emplacement, vue: p.vue, clic: p.clic, bon: p.bons, ctr: p.ctr,
      })),
    };
  }

  // ---------- Plaintes ----------

  listePlaintes() {
    return this.plaintes();
  }

  traiterPlainte(id: string, statut: string, reponse?: string) {
    const p = this.store.get<Plainte>('plaintes', id);
    if (!p) throw new NotFoundException('plainte inconnue');
    if (!['recue', 'en_cours', 'traitee'].includes(statut)) throw new BadRequestException('statut invalide');
    return this.store.put('plaintes', id, {
      ...p,
      statut: statut as Plainte['statut'],
      reponse: reponse?.slice(0, 1000) ?? p.reponse,
      traiteeLe: statut === 'traitee' ? new Date(this.now()).toISOString() : p.traiteeLe,
    });
  }
}
