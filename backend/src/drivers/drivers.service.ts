import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { randomBytes } from 'crypto';
import { AccountsService, normaliserTelephone } from '../accounts/accounts.service';
import { StoreService } from '../store/store.service';

/** Pièces du dossier chauffeur, toutes obligatoires (photos prises avec le téléphone). */
export const PIECES = ['photo', 'cinRecto', 'cinVerso', 'permis', 'cartePro', 'casier', 'vehicule'] as const;
export type Piece = (typeof PIECES)[number];

export type StatutDossier = 'en_attente' | 'valide' | 'refuse' | 'suspendu';

/** Dossier d'inscription d'un chauffeur, vérifié par Bab Taxi avant la première course. */
export interface DossierChauffeur {
  /** Identifiant du compte de l'application chauffeur (aussi l'identifiant du taxi en ligne). */
  id: string;
  prenom: string;
  nom: string;
  telephone: string;
  ville: string;
  /** Numéro de la carte nationale (CIN). */
  cin: string;
  permis: string;
  /** Carte professionnelle de conducteur de taxi (« permis de confiance »). */
  cartePro: string;
  taxiType: 'petit' | 'grand';
  /** Numéro du taxi (peint sur la portière). */
  taxiNumero: string;
  plaque: string;
  langues: string[];
  /** Pièce -> identifiant du fichier enregistré. */
  pieces: Record<Piece, string>;
  statut: StatutDossier;
  motif?: string;
  envoyeLe: string;
  decideLe?: string;
}

const DOSSIERS = 'chauffeurs';
const MAX_PIECE = 4 * 1024 * 1024;
const TYPES_IMAGE = ['image/jpeg', 'image/png', 'image/webp', 'image/heic'];

/** Les chauffeurs doivent être validés par Bab Taxi avant de recevoir des courses (BAB_CHAUFFEUR_VALIDATION=non pour l'enlever). */
export const validationRequise = () => process.env.BAB_CHAUFFEUR_VALIDATION !== 'non';

const texte = (v: unknown, max = 60) => (typeof v === 'string' ? v.trim().slice(0, max) : '');

@Injectable()
export class DriversService {
  constructor(
    private readonly store: StoreService,
    private readonly comptes: AccountsService,
  ) {}

  private verifierId(id: string) {
    if (!/^[A-Za-z0-9_-]{3,40}$/.test(id ?? '')) throw new BadRequestException('id invalide');
  }

  /** Photo ou document envoyé par l'application ; renvoie l'identifiant à mettre dans le dossier. */
  async ajouterPiece(id: string, piece: string, type: string, donnees: Buffer): Promise<string> {
    this.verifierId(id);
    if (!(PIECES as readonly string[]).includes(piece)) throw new BadRequestException('pièce inconnue');
    if (!TYPES_IMAGE.includes(type)) throw new BadRequestException('photo attendue (jpeg ou png)');
    if (donnees.length < 1000) throw new BadRequestException('photo vide');
    if (donnees.length > MAX_PIECE) throw new BadRequestException('photo trop lourde');
    const fid = `chauffeur-${id}-${piece}-${randomBytes(8).toString('hex')}`;
    await this.store.putFichier(fid, type, donnees);
    return fid;
  }

  get(id: string): DossierChauffeur | undefined {
    return this.store.get<DossierChauffeur>(DOSSIERS, id);
  }

  liste(): DossierChauffeur[] {
    return this.store
      .list<DossierChauffeur>(DOSSIERS)
      .sort((a, b) => (a.statut === 'en_attente' ? -1 : 0) - (b.statut === 'en_attente' ? -1 : 0) || b.envoyeLe.localeCompare(a.envoyeLe));
  }

  valide(id: string) {
    return this.get(id)?.statut === 'valide';
  }

  /** Dossier complet envoyé par le chauffeur : en attente de vérification. */
  async envoyer(id: string, corps: Record<string, unknown>): Promise<DossierChauffeur> {
    this.verifierId(id);
    const compte = this.comptes.get(id);
    const pieces = (corps.pieces ?? {}) as Record<string, unknown>;
    const d: DossierChauffeur = {
      id,
      prenom: texte(corps.prenom) || compte?.prenom || '',
      nom: texte(corps.nom) || compte?.nom || '',
      telephone: compte?.telephone || normaliserTelephone(texte(corps.telephone, 30)),
      ville: texte(corps.ville) || 'Casablanca',
      cin: texte(corps.cin, 20).toUpperCase(),
      permis: texte(corps.permis, 30).toUpperCase(),
      cartePro: texte(corps.cartePro, 30).toUpperCase(),
      taxiType: corps.taxiType === 'grand' ? 'grand' : 'petit',
      taxiNumero: texte(corps.taxiNumero, 10),
      plaque: texte(corps.plaque, 30),
      langues: Array.isArray(corps.langues) ? corps.langues.filter((l) => typeof l === 'string').slice(0, 8) : [],
      pieces: {} as Record<Piece, string>,
      statut: 'en_attente',
      envoyeLe: new Date().toISOString(),
    };
    const manque: string[] = [];
    for (const [k, v] of Object.entries({ prenom: d.prenom, nom: d.nom, cin: d.cin, permis: d.permis, cartePro: d.cartePro, taxiNumero: d.taxiNumero, plaque: d.plaque })) {
      if (!v) manque.push(k);
    }
    for (const p of PIECES) {
      const fid = pieces[p];
      if (typeof fid !== 'string' || !fid.startsWith(`chauffeur-${id}-${p}-`) || !(await this.store.getFichier(fid))) manque.push(p);
      else d.pieces[p] = fid;
    }
    if (manque.length) throw new BadRequestException(`Dossier incomplet : ${manque.join(', ')}`);
    return this.store.put(DOSSIERS, id, d);
  }

  /** Décision de Bab Taxi (page des dossiers). */
  decider(id: string, decision: string, motif?: string): DossierChauffeur {
    const d = this.get(id);
    if (!d) throw new NotFoundException('dossier inconnu');
    if (decision !== 'valide' && decision !== 'refuse' && decision !== 'suspendu') throw new BadRequestException('décision invalide');
    if (decision !== 'valide' && !texte(motif, 300)) throw new BadRequestException('motif obligatoire');
    return this.store.put(DOSSIERS, id, {
      ...d,
      statut: decision,
      motif: decision !== 'valide' ? texte(motif, 300) : undefined,
      decideLe: new Date().toISOString(),
    });
  }

  /** Ce que l'application chauffeur affiche (sans les documents). */
  vue(d: DossierChauffeur) {
    return {
      statut: d.statut,
      motif: d.motif,
      prenom: d.prenom,
      nom: d.nom,
      ville: d.ville,
      taxiType: d.taxiType,
      taxiNumero: d.taxiNumero,
      plaque: d.plaque,
      langues: d.langues,
      envoyeLe: d.envoyeLe,
    };
  }

  /** Nom montré au passager : prénom et initiale du nom. */
  nomPublic(d: DossierChauffeur) {
    return `${d.prenom} ${d.nom ? `${d.nom[0]}.` : ''}`.trim();
  }

  fichier(fid: string) {
    return this.store.getFichier(fid);
  }
}
