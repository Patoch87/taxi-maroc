import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { randomBytes } from 'crypto';
import { StoreService } from '../store/store.service';
import { EMPLACEMENTS, Emplacement, PUBLICITES, Publicite } from './ads';

/** Publicité gérée depuis la console d'administration (module « Publicités »). */
export interface PubliciteGeree {
  id: string;
  emplacement: Emplacement;
  annonceur: string;
  titre: string;
  texte: string;
  /** Clés de traduction des pubs d'exemple : effacées dès que le texte est modifié dans la console. */
  titreCle?: string;
  texteCle?: string;
  /** Bon de réduction avec QR code (sinon simple lien vers l'offre). */
  bon: boolean;
  adresse?: string;
  /** Lien ouvert quand le passager touche la publicité (sans bon). */
  lien?: string;
  /** Lieu mis en avant / destination sponsorisée. */
  position?: { lat: number; lng: number };
  /** Couleur du badge (#RRGGBB). */
  couleur?: string;
  /** Logo de l'annonceur (fichier en base). */
  imageId?: string;
  /** Période de diffusion (AAAA-MM-JJ, incluses) ; vide = sans limite. */
  debut?: string;
  fin?: string;
  /** Mise en pause sans supprimer. */
  actif: boolean;
  /** Ordre d'affichage dans un même emplacement (petit = d'abord). */
  priorite: number;
  /** Annonceur d'exemple (« exemple fictif » affiché dans l'application). */
  exempleFictif: boolean;
  supprime?: boolean;
  creeLe: string;
  majLe: string;
}

const COLLECTION = 'publicites';
const INIT = 'publicites_init';
const MAX_IMAGE = 1_000_000;
const TYPES_IMAGE = ['image/png', 'image/jpeg', 'image/webp'];

/** Ce que la console peut envoyer pour créer ou modifier une publicité. */
export type SaisiePublicite = Partial<
  Pick<
    PubliciteGeree,
    'emplacement' | 'annonceur' | 'titre' | 'texte' | 'bon' | 'adresse' | 'lien' | 'position' | 'couleur' | 'debut' | 'fin' | 'actif' | 'priorite' | 'exempleFictif'
  >
>;

const jour = (s?: string) => (s && /^\d{4}-\d{2}-\d{2}$/.test(s) ? s : undefined);

@Injectable()
export class AdsService {
  constructor(private readonly store: StoreService) {}

  /** Horloge remplaçable dans les tests. */
  now = () => Date.now();

  /** Au premier lancement, les publicités d'exemple deviennent des publicités modifiables. */
  private initialiser() {
    if (this.store.get(INIT, 'fait')) return;
    if (!this.store.list<PubliciteGeree>(COLLECTION).length) {
      const t = new Date(this.now()).toISOString();
      PUBLICITES.forEach((p: Publicite, i) =>
        this.store.put<PubliciteGeree>(COLLECTION, p.id, { ...p, actif: true, priorite: i, exempleFictif: true, creeLe: t, majLe: t }),
      );
    }
    this.store.put(INIT, 'fait', { le: new Date(this.now()).toISOString() });
  }

  /** Toutes les publicités (console), sans les supprimées. */
  toutes(): PubliciteGeree[] {
    this.initialiser();
    return this.store
      .list<PubliciteGeree>(COLLECTION)
      .filter((p) => !p.supprime)
      .sort(
        (a, b) =>
          EMPLACEMENTS.indexOf(a.emplacement) - EMPLACEMENTS.indexOf(b.emplacement) ||
          a.priorite - b.priorite ||
          // À priorité égale, la plus récente d'abord.
          b.creeLe.localeCompare(a.creeLe),
      );
  }

  get(id: string): PubliciteGeree {
    this.initialiser();
    const p = this.store.get<PubliciteGeree>(COLLECTION, id);
    if (!p || p.supprime) throw new NotFoundException('Publicité inconnue');
    return p;
  }

  existe(id: string): boolean {
    this.initialiser();
    const p = this.store.get<PubliciteGeree>(COLLECTION, id);
    return !!p && !p.supprime;
  }

  /** Diffusée maintenant : active et dans sa période (dates à l'heure du Maroc, UTC+1). */
  diffusee(p: PubliciteGeree): boolean {
    if (!p.actif || p.supprime) return false;
    const aujourdhui = new Date(this.now() + 3600_000).toISOString().slice(0, 10);
    if (p.debut && aujourdhui < p.debut) return false;
    if (p.fin && aujourdhui > p.fin) return false;
    return true;
  }

  /** Publicités envoyées à l'application (GET /ads). */
  actives(emplacement?: string) {
    return this.toutes()
      .filter((p) => this.diffusee(p) && (!emplacement || p.emplacement === emplacement))
      .map((p) => ({
        id: p.id,
        emplacement: p.emplacement,
        annonceur: p.annonceur,
        titre: p.titre,
        texte: p.texte,
        titreCle: p.titreCle,
        texteCle: p.texteCle,
        bon: p.bon,
        adresse: p.adresse,
        lien: p.lien,
        position: p.position,
        couleur: p.couleur,
        image: p.imageId ? `/ads/${encodeURIComponent(p.id)}/image?v=${encodeURIComponent(p.imageId.slice(-8))}` : undefined,
        exempleFictif: p.exempleFictif,
      }));
  }

  private valider(s: SaisiePublicite, avant?: PubliciteGeree): Omit<PubliciteGeree, 'id' | 'creeLe' | 'majLe'> {
    const emplacement = (s.emplacement ?? avant?.emplacement) as Emplacement;
    if (!EMPLACEMENTS.includes(emplacement)) throw new BadRequestException(`emplacement : ${EMPLACEMENTS.join(', ')}`);
    const texte = (v: unknown, max: number) => (typeof v === 'string' ? v.trim().slice(0, max) : undefined);
    const annonceur = texte(s.annonceur, 60) ?? avant?.annonceur ?? '';
    const titre = texte(s.titre, 60) ?? avant?.titre ?? '';
    const corps = texte(s.texte, 120) ?? avant?.texte ?? '';
    if (!annonceur || !titre) throw new BadRequestException('annonceur et titre sont obligatoires');
    let lien = s.lien === undefined ? avant?.lien : texte(s.lien, 300) || undefined;
    if (lien && !/^https:\/\//i.test(lien)) throw new BadRequestException('le lien doit commencer par https://');
    const couleur = s.couleur === undefined ? avant?.couleur : /^#[0-9a-f]{6}$/i.test(s.couleur ?? '') ? s.couleur : undefined;
    let position = s.position === undefined ? avant?.position : s.position;
    if (position && !(Number.isFinite(position.lat) && Number.isFinite(position.lng))) position = undefined;
    if ((emplacement === 'lieu' || emplacement === 'destination') && !position) {
      throw new BadRequestException('un lieu mis en avant ou une destination sponsorisée a besoin d\'une position (latitude, longitude)');
    }
    const debut = s.debut === undefined ? avant?.debut : jour(s.debut);
    const fin = s.fin === undefined ? avant?.fin : jour(s.fin);
    if (debut && fin && fin < debut) throw new BadRequestException('la date de fin est avant la date de début');
    // Texte modifié : la traduction automatique des pubs d'exemple ne correspond plus.
    const texteChange = !avant || titre !== avant.titre || corps !== avant.texte;
    return {
      emplacement,
      annonceur,
      titre,
      texte: corps,
      titreCle: texteChange ? undefined : avant?.titreCle,
      texteCle: texteChange ? undefined : avant?.texteCle,
      bon: s.bon ?? avant?.bon ?? false,
      adresse: s.adresse === undefined ? avant?.adresse : texte(s.adresse, 120) || undefined,
      lien,
      position: position ? { lat: position.lat, lng: position.lng } : undefined,
      couleur,
      imageId: avant?.imageId,
      debut,
      fin,
      actif: s.actif ?? avant?.actif ?? true,
      priorite: Number.isFinite(s.priorite) ? Number(s.priorite) : (avant?.priorite ?? 50),
      exempleFictif: s.exempleFictif ?? avant?.exempleFictif ?? false,
    };
  }

  creer(s: SaisiePublicite): PubliciteGeree {
    this.initialiser();
    const t = new Date(this.now()).toISOString();
    const id = 'P' + randomBytes(4).toString('hex').toUpperCase();
    return this.store.put<PubliciteGeree>(COLLECTION, id, { id, ...this.valider(s), creeLe: t, majLe: t });
  }

  modifier(id: string, s: SaisiePublicite): PubliciteGeree {
    const avant = this.get(id);
    return this.store.put<PubliciteGeree>(COLLECTION, id, { ...avant, ...this.valider(s, avant), majLe: new Date(this.now()).toISOString() });
  }

  supprimer(id: string) {
    const avant = this.get(id);
    this.store.put<PubliciteGeree>(COLLECTION, id, { ...avant, supprime: true, actif: false, majLe: new Date(this.now()).toISOString() });
    return { ok: true };
  }

  async mettreImage(id: string, type: string, donnees: Buffer): Promise<PubliciteGeree> {
    const avant = this.get(id);
    if (!TYPES_IMAGE.includes(type)) throw new BadRequestException('image PNG, JPEG ou WebP');
    if (!donnees.length || donnees.length > MAX_IMAGE) throw new BadRequestException('image vide ou trop lourde (1 Mo au plus)');
    const fid = `pub-${id}-${randomBytes(6).toString('hex')}`;
    await this.store.putFichier(fid, type, donnees);
    return this.store.put<PubliciteGeree>(COLLECTION, id, { ...avant, imageId: fid, majLe: new Date(this.now()).toISOString() });
  }

  retirerImage(id: string): PubliciteGeree {
    const avant = this.get(id);
    return this.store.put<PubliciteGeree>(COLLECTION, id, { ...avant, imageId: undefined, majLe: new Date(this.now()).toISOString() });
  }

  async image(id: string) {
    const p = this.get(id);
    return p.imageId ? this.store.getFichier(p.imageId) : undefined;
  }

  compter(id: string, type: 'vue' | 'clic' | 'bon') {
    const s = { ...this.stats(id) };
    s[type] += 1;
    this.store.put('pub_stats', id, s);
  }

  stats(id: string) {
    return this.store.get<{ vue: number; clic: number; bon: number }>('pub_stats', id) ?? { vue: 0, clic: 0, bon: 0 };
  }

  /** Console : chaque publicité avec ses chiffres et si elle est diffusée en ce moment. */
  pourConsole() {
    return this.toutes().map((p) => {
      const s = this.stats(p.id);
      return {
        ...p,
        image: p.imageId ? `/ads/${encodeURIComponent(p.id)}/image?v=${encodeURIComponent(p.imageId.slice(-8))}` : undefined,
        diffusee: this.diffusee(p),
        // « bon » est déjà la case « bon de réduction » : les bons distribués s'appellent « bons ».
        vue: s.vue,
        clic: s.clic,
        bons: s.bon,
        ctr: s.vue ? Math.round((s.clic / s.vue) * 1000) / 10 : 0,
      };
    });
  }
}
