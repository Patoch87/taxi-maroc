import { BadRequestException, HttpException, HttpStatus, Injectable, Logger } from '@nestjs/common';
import { StoreService } from '../store/store.service';

/** Compte créé dans l'application (passager ou chauffeur). Le numéro relie le compte à WhatsApp. */
export interface Compte {
  id: string;
  telephone: string;
  prenom: string;
  nom: string;
  email?: string;
  nationalite?: string;
  langue?: string;
  /** Numéro confirmé par un code SMS (envoyé par Twilio, ou code de test sans Twilio). */
  verifie: boolean;
  /** Compte bloqué par Bab Taxi (console d'administration) : plus de commandes. */
  bloque?: boolean;
  motifBlocage?: string;
  creeLe: string;
  majLe: string;
}

/**
 * Numéro réduit à ses chiffres, avec l'indicatif : « +212 6 12 34 56 78 », « 0612345678 » et « 00212612345678 »
 * donnent tous « 212612345678 », la forme utilisée par WhatsApp.
 */
/** Numéro plausible : 8 à 15 chiffres ; au Maroc (212), exactement 9 chiffres après l'indicatif (5, 6 ou 7). */
export function telephoneValide(t: string): boolean {
  if (t.startsWith('212')) return /^212[5-7]\d{8}$/.test(t);
  return /^\d{8,15}$/.test(t);
}

export function normaliserTelephone(v: string | undefined): string {
  let d = (v ?? '').replace(/\D/g, '');
  if (d.startsWith('00')) d = d.slice(2);
  // Numéro marocain écrit sans indicatif : 06…, 07…, 05….
  if (/^0[5-7]\d{8}$/.test(d)) d = `212${d.slice(1)}`;
  // « +212 0612… » : le 0 en trop après l'indicatif.
  if (/^2120\d{9}$/.test(d)) d = `212${d.slice(4)}`;
  return d;
}

const COMPTES = 'comptes';
const ESSAIS_MAX = 5;
const FENETRE_MS = 60 * 60_000;

/** Comptes et vérification du numéro par SMS (Twilio Verify, sinon code de test). */
@Injectable()
export class AccountsService {
  private readonly log = new Logger('Comptes');
  /** Numéro -> identifiant du compte. */
  private readonly parTelephone = new Map<string, string>();
  private readonly envois = new Map<string, number[]>();
  /** Numéros dont le code vient d'être confirmé. */
  private readonly verifies = new Set<string>();
  private indexe = false;

  constructor(private readonly store: StoreService) {}

  private index() {
    if (this.indexe) return;
    for (const c of this.store.list<Compte>(COMPTES)) this.parTelephone.set(c.telephone, c.id);
    this.indexe = true;
  }

  /** Crée ou met à jour le compte envoyé par le téléphone (à chaque inscription, modification ou lancement). */
  enregistrer(corps: {
    id?: string;
    phone?: string;
    firstName?: string;
    lastName?: string;
    email?: string;
    nationality?: string;
    lang?: string;
  }): Compte {
    this.index();
    const id = (corps?.id ?? '').trim();
    const telephone = normaliserTelephone(corps?.phone);
    if (!/^[A-Za-z0-9_-]{3,40}$/.test(id)) throw new BadRequestException('id invalide');
    if (!telephoneValide(telephone)) throw new BadRequestException('numéro de téléphone invalide');
    const ancien = this.store.get<Compte>(COMPTES, id);
    const maintenant = new Date().toISOString();
    const compte: Compte = {
      id,
      telephone,
      prenom: (corps.firstName ?? ancien?.prenom ?? '').slice(0, 60),
      nom: (corps.lastName ?? ancien?.nom ?? '').slice(0, 60),
      email: corps.email?.slice(0, 120) || ancien?.email,
      nationalite: corps.nationality ?? ancien?.nationalite,
      langue: corps.lang ?? ancien?.langue,
      verifie: (ancien?.verifie && ancien.telephone === telephone) || this.verifies.has(telephone),
      bloque: ancien?.bloque,
      motifBlocage: ancien?.motifBlocage,
      creeLe: ancien?.creeLe ?? maintenant,
      majLe: maintenant,
    };
    if (ancien && ancien.telephone !== telephone && this.parTelephone.get(ancien.telephone) === id) {
      this.parTelephone.delete(ancien.telephone);
    }
    // Un numéro ne désigne qu'un compte : le dernier enregistré.
    this.parTelephone.set(telephone, id);
    return this.store.put(COMPTES, id, compte);
  }

  get(id: string): Compte | undefined {
    return this.store.get<Compte>(COMPTES, id);
  }

  /** Compte de l'application lié à ce numéro (WhatsApp donne le numéro sans « + »). */
  parNumero(telephone: string): Compte | undefined {
    this.index();
    const id = this.parTelephone.get(normaliserTelephone(telephone));
    return id ? this.get(id) : undefined;
  }

  liste(): Compte[] {
    return this.store.list<Compte>(COMPTES);
  }

  /** Bloque ou débloque un compte (console d'administration). */
  bloquer(id: string, bloque: boolean, motif?: string): Compte {
    const c = this.get(id);
    if (!c) throw new BadRequestException('compte inconnu');
    return this.store.put(COMPTES, id, { ...c, bloque, motifBlocage: bloque ? (motif ?? '').slice(0, 300) : undefined });
  }

  nombre() {
    return this.store.list<Compte>(COMPTES).length;
  }

  // ---------- Vérification du numéro ----------

  private get twilio() {
    const sid = process.env.TWILIO_ACCOUNT_SID;
    const jeton = process.env.TWILIO_AUTH_TOKEN;
    const service = process.env.TWILIO_VERIFY_SID;
    return sid && jeton && service ? { sid, jeton, service } : undefined;
  }

  /** Code de test (sans Twilio) : affiché dans l'application, comme dans la démo. */
  private get codeTest() {
    return process.env.BAB_CODE_TEST || '1234';
  }

  modeSms(): 'sms' | 'test' {
    return this.twilio ? 'sms' : 'test';
  }

  private async twilioPost(chemin: string, champs: Record<string, string>) {
    const t = this.twilio!;
    const r = await fetch(`https://verify.twilio.com/v2/Services/${t.service}/${chemin}`, {
      method: 'POST',
      headers: {
        Authorization: `Basic ${Buffer.from(`${t.sid}:${t.jeton}`).toString('base64')}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams(champs).toString(),
    });
    const corps = (await r.json().catch(() => ({}))) as { status?: string; message?: string };
    if (!r.ok) throw new Error(`Twilio ${r.status} : ${corps.message ?? ''}`);
    return corps;
  }

  /** Envoie un code au numéro. Sans Twilio, renvoie le code de test à afficher. */
  async envoyerCode(phone: string): Promise<{ mode: 'sms' | 'test'; longueur: number; codeTest?: string }> {
    const telephone = normaliserTelephone(phone);
    if (!telephoneValide(telephone)) throw new BadRequestException('numéro de téléphone invalide');
    const t = Date.now();
    const recents = (this.envois.get(telephone) ?? []).filter((x) => t - x < FENETRE_MS);
    if (recents.length >= ESSAIS_MAX) {
      throw new HttpException('Trop de codes demandés, réessayez dans une heure.', HttpStatus.TOO_MANY_REQUESTS);
    }
    this.envois.set(telephone, [...recents, t]);
    if (!this.twilio) return { mode: 'test', longueur: this.codeTest.length, codeTest: this.codeTest };
    try {
      await this.twilioPost('Verifications', { To: `+${telephone}`, Channel: 'sms' });
    } catch (e) {
      this.log.error((e as Error).message);
      throw new HttpException("Le SMS n'a pas pu partir. Réessayez dans un instant.", HttpStatus.BAD_GATEWAY);
    }
    return { mode: 'sms', longueur: Number(process.env.TWILIO_CODE_LONGUEUR ?? 6) };
  }

  /** Vérifie le code saisi. */
  async verifierCode(phone: string, code: string): Promise<boolean> {
    const telephone = normaliserTelephone(phone);
    const saisi = (code ?? '').trim();
    if (!saisi) return false;
    let ok = false;
    if (!this.twilio) ok = saisi === this.codeTest;
    else {
      try {
        const r = await this.twilioPost('VerificationCheck', { To: `+${telephone}`, Code: saisi });
        ok = r.status === 'approved';
      } catch (e) {
        this.log.error((e as Error).message);
      }
    }
    if (ok) {
      this.verifies.add(telephone);
      const c = this.parNumero(telephone);
      if (c && !c.verifie) this.store.put(COMPTES, c.id, { ...c, verifie: true });
    }
    return ok;
  }
}
