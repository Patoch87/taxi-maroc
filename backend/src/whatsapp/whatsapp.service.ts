import { Injectable, Logger, OnModuleDestroy } from '@nestjs/common';
import { lienApplication } from '../accounts/accounts.controller';
import { AccountsService } from '../accounts/accounts.service';
import { haversine, Point } from '../domain/geo';
import { RidesService, StatutCourse } from '../rides/rides.service';
import { AgentDemo, detecterLangue } from './agent-demo';
import { AgentIA } from './agent-ia';
import { Commande, Conversation, distanceParlee, Langue, prixOffres } from './commande';
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
  /** Bouton de réponse touché (identifiant, ex. « offre:partage »). */
  bouton?: string;
}

export interface Reponse {
  texte: string;
  audio?: { donnees: Buffer; type: string };
  /** Boutons de réponse sous le texte (3 au plus). */
  boutons?: { id: string; titre: string }[];
  /** Bouton « Envoyer ma position ». */
  demandePosition?: boolean;
  /** Bouton qui ouvre l'application Bab Taxi (suivi de la course, avec ses publicités). */
  lien?: { libelle: string; url: string };
}

/** Adresse publique du serveur (Render la donne dans RENDER_EXTERNAL_URL). */
const urlPublique = () =>
  (process.env.BAB_URL_PUBLIQUE || process.env.RENDER_EXTERNAL_URL || 'https://bab-taxi-eu.onrender.com').replace(/\/$/, '');

/** Lien qui ouvre l'application sur la course (page /ouvrir : application si installée, sinon téléchargement). */
export const lienOuvrirApp = (courseId?: string) => `${urlPublique()}/ouvrir${courseId ? `?c=${encodeURIComponent(courseId)}` : ''}`;

const darijaOuArabe = (l: Langue) => l === 'darija' || l === 'ar';

/** Titres des boutons d'offre (20 caractères au plus). */
function titreOffre(offre: string, langue: Langue): string {
  const d = darijaOuArabe(langue);
  switch (offre) {
    case 'partage':
      return d ? 'مشارك' : 'Partagé';
    case 'seul':
      return d ? 'بوحدي' : 'Seul';
    case 'premium':
      return d ? 'بريميوم' : 'Premium';
    default:
      return d ? 'طاكسي كبير' : 'Grand taxi';
  }
}

const libelleOuvrir = (l: Langue) => (darijaOuArabe(l) ? 'حل باب طاكسي' : 'Suivre mon taxi');

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

/** Réponse à un numéro qui n'a pas encore de compte dans l'application. */
export function sansCompte(texte?: string): string {
  const lien = lienApplication();
  const fr =
    `Bonjour ! Pour commander un taxi sur WhatsApp, installez d'abord l'application Bab Taxi et créez votre compte avec ce même numéro : ${lien}\n` +
    'Ensuite, envoyez-moi simplement votre destination, par écrit ou en vocal.';
  const dr =
    `السلام! باش تطلب طاكسي فواتساب، خاصك تيليشارجي التطبيق ديال باب طاكسي وتصاوب الحساب بهاد النمرة: ${lien}\n` +
    'من بعد، صيفط ليا غير فين غادي، بالكتابة ولا بالفوكال.';
  return texte && arabe(texte) ? `${dr}\n\n${fr}` : `${fr}\n\n${dr}`;
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

  constructor(
    private readonly rides: RidesService,
    private readonly comptes: AccountsService,
  ) {
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
        interactive?: { button_reply?: { id?: string; title: string } };
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
          else if (m.type === 'interactive') {
            entrant.texte = m.interactive?.button_reply?.title;
            entrant.bouton = m.interactive?.button_reply?.id;
          }
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
    // Le vocal part d'abord, puis le texte avec ses boutons (position, offres, « Suivre mon taxi ») en dernier,
    // pour que les boutons restent en bas de la conversation.
    const reponses = await this.traiter(m, true);
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
      if (process.env.WHATSAPP_TEXTE_AVEC_VOCAL === 'non' && !r.lien && !r.boutons && !r.demandePosition) return;
    }
    // Boutons WhatsApp : en cas de refus de Meta (ancienne version de WhatsApp…), le texte part seul.
    try {
      if (r.lien) return await wa.envoyerLien(a, r.texte, r.lien.libelle, r.lien.url);
      if (r.demandePosition) return await wa.envoyerDemandePosition(a, r.texte);
      if (r.boutons?.length) return await wa.envoyerBoutons(a, r.texte, r.boutons);
    } catch (e) {
      this.log.error(e);
      if (r.lien) return wa.envoyerTexte(a, `${r.texte}\n${r.lien.url}`);
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
  async traiter(m: MessageEntrant, voix = true): Promise<Reponse[]> {
    // Commande WhatsApp réservée aux passagers qui ont l'application : le numéro WhatsApp doit être celui du compte.
    // Le simulateur (numéros « demo-… ») et BAB_WHATSAPP_OUVERT=oui (essais) laissent passer tout le monde.
    const compte = m.de.startsWith('demo-') ? undefined : this.comptes.parNumero(m.de);
    if (!compte && !m.de.startsWith('demo-') && process.env.BAB_WHATSAPP_OUVERT !== 'oui') {
      return [{ texte: sansCompte(m.texte) }];
    }
    if (compte?.bloque) {
      return [{ texte: 'Votre compte Bab Taxi est suspendu. Contactez Bab Taxi. / الحساب ديالك موقوف، تواصل مع باب طاكسي.' }];
    }
    const conv = this.conversation(m.de, compte?.prenom || m.nom);
    const cmd = new Commande(this.rides, conv);
    let texte = (m.texte ?? '').trim();
    const avant = { course: conv.courseId, prix: conv.prixAuTour };

    // Bouton Partagé / Seul / Premium : la course part tout de suite, sans repasser par l'agent.
    if (m.bouton?.startsWith('offre:')) {
      const direct = this.commanderParBouton(cmd, m.bouton.slice(6), texte);
      if (direct) return [voix ? await this.habiller(conv, direct.texte, direct) : direct];
    }

    if (m.position) {
      cmd.definirPositionGps({ lat: m.position.lat, lng: m.position.lng }, m.position.nom);
      const r = this.ia
        ? await this.repondreIA(cmd, 'Je vous envoie ma position.', true)
        : await this.demo.positionRecue(cmd);
      const plus = this.boutonsApres(conv, avant, true);
      return [voix ? await this.habiller(conv, r, plus) : { texte: r, ...plus }];
    }

    conv.vocal = !!m.audio;
    if (m.audio) {
      try {
        const debut = Date.now();
        const t = await transcrire(m.audio.donnees, m.audio.type);
        texte = t.texte;
        this.log.log(`Vocal transcrit en ${Date.now() - debut} ms (langue ${t.langue ?? '?'}, ${texte.length} caractères)`);
        // Vocal très court, bruit, ou langue improbable au Maroc (un « oui » d'une seconde reconnu comme du
        // russe) : on ne change pas de langue, et on redemande si rien d'utile n'a été compris.
        conv.langueVocal = langueFiable(t.langue, texte) ? t.langue : undefined;
        if (!conv.langueVocal && texte.replace(/[^\p{L}\p{N}]/gu, '').length < 2) {
          conv.vocal = true;
          return [await this.habiller(conv, conv.langue === 'fr' ? "Je n'ai pas bien entendu, pouvez-vous répéter ?" : 'ما سمعتكش مزيان، عاود عافاك؟')];
        }
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

    const debut = Date.now();
    const r = this.ia ? await this.repondreIA(cmd, texte, false) : await this.demo.repondre(cmd, texte);
    this.log.log(`Réponse de l'agent en ${Date.now() - debut} ms`);
    const plus = this.boutonsApres(conv, avant, false);
    return [voix ? await this.habiller(conv, r, plus) : { texte: r, ...plus }];
  }

  /**
   * Boutons ajoutés sous la réponse, pour aller vite et finir dans l'application :
   * course lancée -> « Suivre mon taxi » (ouvre l'application) ; départ inconnu -> « Envoyer ma position » ;
   * prix annoncés -> Partagé / Seul / Premium.
   */
  private boutonsApres(conv: Conversation, avant: { course?: string; prix?: number }, positionRecue: boolean): Omit<Reponse, 'texte'> {
    if (conv.courseId && conv.courseId !== avant.course) {
      return { lien: { libelle: libelleOuvrir(conv.langue), url: lienOuvrirApp(conv.courseId) } };
    }
    const enCours = conv.courseId && ['en_attente', 'acceptee', 'a_bord'].includes(conv.dernierStatut ?? '');
    if (enCours) return { lien: { libelle: libelleOuvrir(conv.langue), url: lienOuvrirApp(conv.courseId) } };
    // Départ inconnu : bouton « Envoyer ma position » à chaque réponse (en français comme en darija),
    // même avant la destination, pour que la course puisse partir dès le choix de l'offre.
    if (!conv.depart) return { demandePosition: true };
    if (!conv.destination) return {};
    const prixNouveaux = conv.prixAuTour !== undefined && (conv.prixAuTour !== avant.prix || positionRecue);
    if (!prixNouveaux) return {};
    return { boutons: prixOffres(conv).map((o) => ({ id: `offre:${o.offre}`, titre: titreOffre(o.offre, conv.langue) })) };
  }

  /** Commande lancée par un bouton d'offre ; undefined si elle ne peut pas partir (l'agent prend le relais). */
  private commanderParBouton(cmd: Commande, offre: string, titre: string): Reponse | undefined {
    const c = cmd.conv;
    if (!['partage', 'seul', 'premium', 'grand_taxi'].includes(offre)) return undefined;
    c.tour++;
    try {
      const r = cmd.commander(offre as 'partage', 'especes') as { fourchette_mad?: { min: number; max: number }; prix_fixe_mad?: number };
      const d = darijaOuArabe(c.langue);
      const dest = d ? c.destination?.lieu.ar || c.destination?.lieu.nom : c.destination?.lieu.nom;
      const prix = r.prix_fixe_mad !== undefined
        ? `${r.prix_fixe_mad} ${d ? 'درهم' : 'dirhams'}`
        : r.fourchette_mad
          ? d ? `بين ${r.fourchette_mad.min} و ${r.fourchette_mad.max} درهم` : `entre ${r.fourchette_mad.min} et ${r.fourchette_mad.max} dirhams`
          : '';
      const texte = d
        ? `صافي! ${titreOffre(offre, c.langue)} ل${dest}، ${prix}. كنقلب ليك على طاكسي فطريقك. تبع الطاكسي ديالك فالتطبيق.`
        : `C'est parti : ${titreOffre(offre, c.langue).toLowerCase()} vers ${dest}, ${prix}. Je cherche un taxi sur votre route. Suivez votre taxi dans l'application.`;
      this.ia?.noter(c.id, `[bouton touché] ${titre}`, texte);
      return { texte, lien: { libelle: libelleOuvrir(c.langue), url: lienOuvrirApp(c.courseId) } };
    } catch (e) {
      this.log.warn(`Bouton ${offre} : ${(e as Error).message}`);
      c.tour--;
      return undefined;
    }
  }

  private async repondreIA(cmd: Commande, texte: string, position: boolean): Promise<string> {
    const c = cmd.conv;
    const heure = new Intl.DateTimeFormat('fr-FR', { timeZone: 'Africa/Casablanca', hour: '2-digit', minute: '2-digit' }).format(new Date());
    const contexte = [
      position ? 'le passager a envoyé sa position WhatsApp' : c.vocal ? 'message vocal transcrit' : 'message écrit',
      // Langue de la conversation : la transcription d'un vocal court se trompe parfois de langue.
      `langue de la conversation jusqu'ici : ${c.langue === 'darija' ? 'darija marocaine' : c.langue === 'fr' ? 'français' : c.langue}`,
      c.vocal && !c.langueVocal ? 'transcription incertaine : garde la langue de la conversation' : '',
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
  private async habiller(conv: Conversation, texte: string, plus: Omit<Reponse, 'texte'> = {}): Promise<Reponse> {
    const boutons = { boutons: plus.boutons, demandePosition: plus.demandePosition, lien: plus.lien };
    if (!conv.vocal || !voixActive()) return { texte, ...boutons };
    try {
      return { texte, ...boutons, audio: await synthetiser(texte, arabe(texte)) };
    } catch (e) {
      this.log.error(e);
      return { texte, ...boutons };
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
      // Après la commande, le suivi se fait dans l'application : WhatsApp ne prévient plus que du taxi trouvé
      // (plaque, pour la sécurité) et de l'absence de taxi.
      const utile = d.statut === 'acceptee' || d.statut === 'expiree';
      const texte = utile ? annonce(d.statut, c.langue, d.taxi ? { nom: d.taxi.nom, plaque: d.taxi.plaque, distanceM } : undefined) : undefined;
      const lien = d.statut === 'acceptee' ? { lien: { libelle: libelleOuvrir(c.langue), url: lienOuvrirApp(d.id) } } : {};
      if (d.statut === 'terminee' || d.statut === 'expiree' || d.statut === 'annulee') {
        // Course finie : la prochaine conversation repart de zéro (l'historique n'est pas réécrit, il est oublié).
        Object.assign(c, { destination: undefined, prixAuTour: undefined, etape: undefined, offre: undefined, passagers: 1, depart: undefined });
        this.ia?.oublier(c.id);
      }
      if (texte) await this.enFile(c.id, async () => this.envoyer(c.id, await this.habiller(c, texte, lien)));
    }
  }
}

/** Langues attendues des passagers (codes ISO 639-3 donnés par ElevenLabs Scribe). */
const LANGUES_ATTENDUES = new Set(['ara', 'ary', 'fra', 'eng', 'spa', 'deu', 'ita', 'por', 'nld', 'zgh', 'ber', 'tzm', 'kab']);

/** Langue détectée crédible : attendue au Maroc, et vocal assez long pour être sûr. */
export function langueFiable(langue: string | undefined, texte: string): boolean {
  return !!langue && LANGUES_ATTENDUES.has(langue) && texte.trim().length >= 4;
}
