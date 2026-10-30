import { Injectable, Logger, OnModuleDestroy } from '@nestjs/common';
import { haversine, Point } from '../domain/geo';
import { RidesService, StatutCourse } from '../rides/rides.service';
import { AgentDemo, detecterLangue } from './agent-demo';
import { AgentIA } from './agent-ia';
import { Commande, Conversation, distanceParlee, Langue } from './commande';
import { synthetiser, transcrire, voixActive } from './voix';
import * as wa from './whatsapp-api';

/** Message reçu d'un passager, par WhatsApp ou par le simulateur. */
export interface MessageEntrant {
  de: string;
  nom?: string;
  messageId?: string;
  texte?: string;
  audio?: { donnees: Buffer; type: string };
  position?: Point & { nom?: string };
}

export interface Reponse {
  texte: string;
  audio?: { donnees: Buffer; type: string };
}

/** Une conversation sans message depuis ce délai repart de zéro (s'il n'y a pas de course en cours). */
const OUBLI_MS = 2 * 60 * 60_000;
/** Fréquence de vérification des courses commandées par WhatsApp (chauffeur trouvé, à bord, arrivé). */
const SUIVI_MS = 4000;

const arabe = (t: string) => /[؀-ۿ]/.test(t);

/** Messages envoyés au passager quand sa course change d'état. */
function annonce(statut: StatutCourse, langue: Langue, taxi?: { nom?: string; plaque?: string; distanceM?: number }): string | undefined {
  const d = langue === 'darija' || langue === 'ar';
  switch (statut) {
    case 'acceptee': {
      const nom = taxi?.nom ?? (d ? 'الشيفور' : 'Votre chauffeur');
      const loin = taxi?.distanceM !== undefined ? distanceParlee(taxi.distanceM, langue) : undefined;
      return d
        ? `لقينا ليك طاكسي! ${nom}${taxi?.plaque ? `، النمرة \u2066${taxi.plaque}\u2069` : ''}${loin ? `، بعيد عليك ب${loin}` : ''}. تسنى فبلاصتك.`
        : `Un taxi a accepté ! ${nom}${taxi?.plaque ? `, plaque ${taxi.plaque}` : ''}${loin ? `, à ${loin} de vous` : ''}. Restez à votre point de départ.`;
    }
    case 'a_bord':
      return d ? 'الشيفور بدا الكورسة. طريق السلامة!' : 'Le chauffeur a démarré la course. Bon trajet !';
    case 'terminee':
      return d ? 'وصلتي. شكرا على باب طاكسي، حتى لمرة جاية!' : "Vous êtes arrivé. Merci d'avoir choisi Bab Taxi, à bientôt !";
    case 'expiree':
      return d
        ? 'ما قبل حتى طاكسي دابا. عاود قول ليا فين غادي باش نقلبو مرة أخرى.'
        : "Aucun taxi n'a accepté pour l'instant. Redites-moi votre destination pour relancer la recherche.";
    default:
      return undefined;
  }
}

/**
 * Agent WhatsApp de Bab Taxi : reçoit les messages (vocaux, écrits, position), fait répondre l'agent IA
 * (ou l'agent de démonstration sans clé Claude), répond en vocal à qui parle en vocal, et prévient le passager
 * quand un chauffeur accepte, démarre et termine la course.
 */
@Injectable()
export class WhatsappService implements OnModuleDestroy {
  private readonly log = new Logger('WhatsApp');
  private readonly conversations = new Map<string, Conversation>();
  /** Messages en attente pour le simulateur (en vrai, ils partent directement sur WhatsApp). */
  private readonly boites = new Map<string, Reponse[]>();
  private readonly dejaVus = new Set<string>();
  private readonly files = new Map<string, Promise<unknown>>();
  private readonly demo = new AgentDemo();
  private ia?: AgentIA;
  private readonly minuterie: NodeJS.Timeout;

  constructor(private readonly rides: RidesService) {
    if (process.env.ANTHROPIC_API_KEY) this.ia = new AgentIA();
    this.minuterie = setInterval(() => this.suivreCourses().catch((e) => this.log.error(e)), SUIVI_MS);
    this.minuterie.unref();
  }

  onModuleDestroy() {
    clearInterval(this.minuterie);
  }

  /** Remplace l'agent IA (tests). */
  utiliserAgentIA(agent: AgentIA | undefined) {
    this.ia = agent;
  }

  etat() {
    return {
      agent: this.ia ? 'claude' : 'demo',
      voix: voixActive(),
      whatsapp: wa.whatsappActif(),
      conversations: this.conversations.size,
    };
  }

  conversation(id: string, nom?: string): Conversation {
    let c = this.conversations.get(id);
    const actif = c?.courseId && ['en_attente', 'acceptee', 'a_bord'].includes(c.dernierStatut ?? '');
    if (!c || (!actif && Date.now() - c.majLe > OUBLI_MS)) {
      c = { id, nom: nom ?? c?.nom, langue: c?.langue ?? 'fr', tour: 0, vocal: false, passagers: 1, adresses: [], majLe: Date.now() };
      this.conversations.set(id, c);
      this.ia?.oublier(id);
    }
    if (nom) c.nom = nom;
    c.majLe = Date.now();
    return c;
  }

  /** Les messages d'un même passager sont traités l'un après l'autre. */
  private enFile<T>(id: string, travail: () => Promise<T>): Promise<T> {
    const suite = (this.files.get(id) ?? Promise.resolve()).catch(() => undefined).then(travail);
    this.files.set(id, suite);
    return suite;
  }

  /** Webhook Meta : un appel peut contenir plusieurs messages ; Meta renvoie le même message s'il n'a pas eu de 200 à temps. */
  async webhook(corps: unknown) {
    type Valeur = {
      contacts?: { wa_id: string; profile?: { name?: string } }[];
      messages?: {
        id: string;
        from: string;
        type: string;
        text?: { body: string };
        audio?: { id: string };
        location?: { latitude: number; longitude: number; name?: string; address?: string };
        interactive?: { button_reply?: { title: string } };
        button?: { text: string };
      }[];
    };
    const entrees = (corps as { entry?: { changes?: { value?: Valeur }[] }[] })?.entry ?? [];
    for (const e of entrees) {
      for (const ch of e.changes ?? []) {
        const v = ch.value;
        for (const m of v?.messages ?? []) {
          if (this.dejaVus.has(m.id)) continue;
          this.dejaVus.add(m.id);
          if (this.dejaVus.size > 5000) this.dejaVus.delete(this.dejaVus.values().next().value!);
          const nom = v?.contacts?.find((c) => c.wa_id === m.from)?.profile?.name;
          const entrant: MessageEntrant = { de: m.from, nom, messageId: m.id };
          if (m.type === 'text') entrant.texte = m.text?.body;
          else if (m.type === 'interactive') entrant.texte = m.interactive?.button_reply?.title;
          else if (m.type === 'button') entrant.texte = m.button?.text;
          else if (m.type === 'location' && m.location) {
            entrant.position = { lat: m.location.latitude, lng: m.location.longitude, nom: m.location.name ?? m.location.address };
          } else if (m.type === 'audio' && m.audio) {
            void wa.marquerLu(m.id);
            const id = m.audio.id;
            this.enFile(m.from, async () => {
              try {
                entrant.audio = await wa.telechargerMedia(id);
              } catch (err) {
                this.log.error(err);
              }
              return this.traiterEtEnvoyer(entrant);
            }).catch((err) => this.log.error(err));
            continue;
          }
          void wa.marquerLu(m.id);
          this.enFile(m.from, () => this.traiterEtEnvoyer(entrant)).catch((err) => this.log.error(err));
        }
      }
    }
  }

  private async traiterEtEnvoyer(m: MessageEntrant) {
    const reponses = await this.traiter(m);
    for (const r of reponses) await this.envoyer(m.de, r);
  }

  /** Envoie au passager : sur WhatsApp si c'est un vrai numéro, sinon dans la boîte du simulateur. */
  private async envoyer(a: string, r: Reponse) {
    if (a.startsWith('demo-') || !wa.whatsappActif()) {
      const boite = this.boites.get(a) ?? [];
      boite.push(r);
      this.boites.set(a, boite.slice(-50));
      return;
    }
    if (r.audio) {
      await wa.envoyerAudio(a, r.audio.donnees, r.audio.type).catch((e) => this.log.error(e));
      if (process.env.WHATSAPP_TEXTE_AVEC_VOCAL === 'non') return;
    }
    await wa.envoyerTexte(a, r.texte);
  }

  /** Messages en attente pour le simulateur. */
  relever(id: string): Reponse[] {
    const b = this.boites.get(id) ?? [];
    this.boites.delete(id);
    return b;
  }

  /** Message du simulateur : traité tout de suite, les réponses reviennent dans l'appel. */
  simuler(m: MessageEntrant): Promise<{ transcription?: string; reponses: Reponse[] }> {
    return this.enFile(m.de, async () => {
      const reponses = await this.traiter(m);
      const conv = this.conversations.get(m.de);
      return { transcription: m.audio ? conv?.derniereTranscription : undefined, reponses };
    });
  }

  /** Comprend le message et prépare la réponse (texte, et voix si le passager a parlé). */
  async traiter(m: MessageEntrant): Promise<Reponse[]> {
    const conv = this.conversation(m.de, m.nom);
    const cmd = new Commande(this.rides, conv);
    let texte = (m.texte ?? '').trim();

    if (m.position) {
      cmd.definirPositionGps({ lat: m.position.lat, lng: m.position.lng }, m.position.nom);
      const r = this.ia
        ? await this.repondreIA(cmd, 'Je vous envoie ma position.', true)
        : await this.demo.positionRecue(cmd);
      return [await this.habiller(conv, r)];
    }

    conv.vocal = !!m.audio;
    if (m.audio) {
      try {
        const t = await transcrire(m.audio.donnees, m.audio.type);
        texte = t.texte;
        conv.derniereTranscription = texte;
      } catch (e) {
        this.log.error(e);
        conv.vocal = false;
        return [{ texte: "Je n'ai pas pu écouter votre vocal. Pouvez-vous l'écrire ? / ما قدرتش نسمع الفوكال، كتب ليا عافاك." }];
      }
    }
    if (!texte) return [];
    conv.tour++;
    conv.langue = detecterLangue(texte, conv.langue);

    const r = this.ia ? await this.repondreIA(cmd, texte, false) : await this.demo.repondre(cmd, texte);
    return [await this.habiller(conv, r)];
  }

  private async repondreIA(cmd: Commande, texte: string, position: boolean): Promise<string> {
    const c = cmd.conv;
    const heure = new Intl.DateTimeFormat('fr-FR', { timeZone: 'Africa/Casablanca', hour: '2-digit', minute: '2-digit' }).format(new Date());
    const contexte = [
      position ? 'le passager a envoyé sa position WhatsApp' : c.vocal ? 'message vocal transcrit' : 'message écrit',
      c.depart ? `position de départ connue${c.depart.nom ? ` (${c.depart.nom})` : ''}` : 'position de départ inconnue',
      `heure à Casablanca ${heure}`,
      c.nom ? `nom WhatsApp ${c.nom}` : '',
    ]
      .filter(Boolean)
      .join(' ; ');
    try {
      const r = await this.ia!.repondre(cmd, texte, contexte);
      if (r) return r;
    } catch (e) {
      this.log.error(`Agent IA indisponible, agent de secours : ${(e as Error).message}`);
      return position ? this.demo.positionRecue(cmd) : this.demo.repondre(cmd, texte);
    }
    return c.langue === 'darija' ? 'سمح ليا، عاود عافاك؟' : 'Pardon, pouvez-vous répéter ?';
  }

  /** Ajoute la voix quand le passager a parlé. */
  private async habiller(conv: Conversation, texte: string): Promise<Reponse> {
    if (!conv.vocal || !voixActive()) return { texte };
    try {
      return { texte, audio: await synthetiser(texte, arabe(texte)) };
    } catch (e) {
      this.log.error(e);
      return { texte };
    }
  }

  /** Prévient les passagers WhatsApp quand leur course change d'état. */
  async suivreCourses() {
    for (const c of this.conversations.values()) {
      if (!c.courseId || !['en_attente', 'acceptee', 'a_bord'].includes(c.dernierStatut ?? '')) continue;
      const d = this.rides.getRequest(c.courseId);
      if (d.statut === c.dernierStatut) continue;
      c.dernierStatut = d.statut;
      const distanceM =
        d.taxi && c.depart ? Math.round(haversine(d.taxi.position, c.depart.point)) : undefined;
      const texte = annonce(d.statut, c.langue, d.taxi ? { nom: d.taxi.nom, plaque: d.taxi.plaque, distanceM } : undefined);
      if (d.statut === 'terminee' || d.statut === 'expiree' || d.statut === 'annulee') {
        // Course finie : la prochaine conversation repart de zéro (l'historique n'est pas réécrit, il est oublié).
        Object.assign(c, { destination: undefined, prixAuTour: undefined, etape: undefined, offre: undefined, passagers: 1, depart: undefined });
        this.ia?.oublier(c.id);
      }
      if (texte) await this.enFile(c.id, async () => this.envoyer(c.id, await this.habiller(c, texte)));
    }
  }
}
