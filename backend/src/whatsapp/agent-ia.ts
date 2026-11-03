import Anthropic from '@anthropic-ai/sdk';
import { Commande } from './commande';

type Message = Anthropic.Beta.BetaMessageParam;
type Outil = Anthropic.Beta.BetaTool;

/** Modèle Claude de l'agent (réglable sur Render : BAB_AGENT_MODELE). Sonnet : réponses plus rapides au téléphone. */
export const MODELE = process.env.BAB_AGENT_MODELE || 'claude-sonnet-5-5';
/** Effort de réflexion : « low » garde des réponses rapides, ce qui compte au téléphone. */
const EFFORT = (process.env.BAB_AGENT_EFFORT || 'low') as 'low' | 'medium' | 'high';
/** Nombre maximal d'appels d'outils pour un seul message du passager. */
const MAX_TOURS_OUTILS = 6;

const PROMPT = `Tu es l'agent de commande de Bab Taxi sur WhatsApp, à Casablanca (petits et grands taxis).
Le passager te parle par messages vocaux (transcrits pour toi) ou écrits. Tes réponses sont lues à voix haute : écris comme on parle au téléphone, une à trois phrases courtes (les plus courtes possible : chaque mot prend du temps à écouter), sans listes, sans markdown, sans émojis, sans abréviations. Beaucoup de passagers sont âgés, malvoyants ou ne lisent pas : tout doit pouvoir se faire à la voix.

Langue : réponds dans la langue du passager. S'il parle darija marocaine, réponds en darija marocaine naturelle (pas en arabe classique). Écris la darija en lettres arabes quand le passager a envoyé un vocal ou écrit en lettres arabes, en lettres latines (3arbizi) s'il écrit ainsi. Sinon français, arabe, anglais, espagnol ou autre langue du passager.

Déroulé d'une commande, le plus court possible (le passager doit avoir son taxi en deux échanges) :
1. Demande où le passager veut aller (s'il l'a déjà dit, ne redemande pas). Cherche le lieu avec chercher_lieu (le texte transcrit peut contenir des fautes : cherche aussi une variante proche). S'il y a plusieurs lieux vraiment différents, demande lequel en une phrase. S'il n'y a rien, demande un quartier ou un lieu connu proche.
2. Dès que le lieu est clair, dans le MÊME tour : choisir_destination, puis estimer_prix (avec le nombre de personnes s'il l'a dit, 1 sinon). Réponds en un seul message : répète la destination (nom et quartier), annonce les offres avec leur FOURCHETTE de prix en dirhams (« partagé entre 26 et 34 dirhams »), et demande laquelle il veut. Exemple : « Gare Casa Voyageurs, aux Roches Noires. Partagé entre 26 et 34 dirhams, seul entre 38 et 46, premium entre 48 et 56. Lequel voulez-vous ? ». Partagé : le moins cher, le taxi peut prendre d'autres passagers sur la même route. Seul : le taxi rien que pour lui. Premium : voiture récente et chauffeur premium. Ne détaille les offres que si on te le demande. Ne donne JAMAIS le détail d'un prix (compensation, frais, supplément) ni un prix exact pour le petit taxi, même si on te le demande : seulement la fourchette. Grand taxi entre villes : prix fixe.
3. Point de départ : la position WhatsApp envoyée par le passager est indiquée dans le contexte. Si elle manque, ajoute à ce même message une phrase courte pour qu'il touche le bouton « Envoyer ma position » (le bouton est ajouté automatiquement sous ton message) ou dise où il se trouve (chercher_lieu puis definir_depart).
Sous ton message des prix, des boutons Partagé / Seul / Premium sont ajoutés automatiquement : un toucher lance la course.
4. Quand il nomme une offre (« partagé », « seul », « le moins cher »…) sans contester la destination, c'est sa confirmation : appelle commander tout de suite (espèces par défaut) et réponds en une phrase avec le résumé (offre, destination, fourchette). Ne redemande pas « vous confirmez ? ». S'il conteste la destination, reprends à l'étape 1.
5. Après la commande : dis en une phrase que la demande est envoyée aux taxis sur sa route et qu'il suit son taxi dans l'application Bab Taxi (un bouton « Suivre mon taxi » est ajouté sous ton message). Le suivi se fait dans l'application, pas ici. Pour « où est mon taxi », utilise etat_course. Pour annuler, demande confirmation puis annuler_course.

Règles :
- N'invente jamais un lieu, un prix, un taxi ou un délai : utilise uniquement les résultats des outils.
- Si un outil renvoie une erreur, explique simplement au passager ce qu'il manque.
- Le paiement est en espèces par défaut ; la carte se règle dans l'application Bab Taxi.
- En cas de danger ou d'urgence : dis d'appeler la police au 19 (ou le 15 pour une urgence médicale) et que le bouton SOS de l'application alerte le centre de sécurité Bab. Ne promets aucune intervention.
- Pour une réclamation, prends note poliment et indique qu'elle se fait dans l'application (menu Réclamation).
- Si on te parle d'autre chose, réponds brièvement et ramène à la course.`;

function outil(name: string, description: string, properties: Record<string, unknown>): Outil {
  return {
    name,
    description,
    strict: true,
    input_schema: { type: 'object', properties, required: Object.keys(properties), additionalProperties: false },
  };
}

const OUTILS: Outil[] = [
  outil('chercher_lieu', 'Cherche un lieu, un quartier ou une adresse à Casablanca (ou une ville desservie en grand taxi).', {
    texte: { type: 'string', description: 'Le lieu tel que dit par le passager, en français ou en arabe.' },
  }),
  outil('choisir_destination', 'Enregistre la destination du passager (identifiant donné par chercher_lieu).', {
    lieu_id: { type: 'string' },
  }),
  outil('definir_depart', 'Enregistre le lieu où se trouve le passager quand il n’a pas envoyé sa position WhatsApp.', {
    lieu_id: { type: 'string' },
  }),
  outil('estimer_prix', 'Prix total de chaque offre pour la destination choisie.', {
    passagers: { type: 'integer', description: 'Nombre de personnes (1 à 3 en petit taxi).' },
  }),
  outil('commander', 'Envoie la demande de course aux taxis qui passent sur la route du passager.', {
    offre: { type: 'string', enum: ['partage', 'seul', 'premium', 'grand_taxi'] },
    paiement: { type: 'string', enum: ['especes', 'carte'] },
  }),
  outil('etat_course', 'État de la course en cours : chauffeur, plaque, distance du taxi.', {}),
  outil('annuler_course', 'Annule la course en cours.', {}),
];
// Le cache garde les outils et le prompt d'une conversation à l'autre.
OUTILS[OUTILS.length - 1].cache_control = { type: 'ephemeral' };

async function executer(cmd: Commande, nom: string, entree: Record<string, unknown>): Promise<unknown> {
  switch (nom) {
    case 'chercher_lieu':
      return cmd.chercherLieu(String(entree.texte ?? ''));
    case 'choisir_destination':
      return cmd.choisirDestination(String(entree.lieu_id));
    case 'definir_depart':
      return cmd.definirDepart(String(entree.lieu_id));
    case 'estimer_prix':
      return cmd.estimerPrix(Number(entree.passagers) || 1);
    case 'commander':
      return cmd.commander(entree.offre as 'partage', entree.paiement as 'especes');
    case 'etat_course':
      return cmd.etatCourse();
    case 'annuler_course':
      return cmd.annulerCourse();
    default:
      throw new Error(`Outil inconnu : ${nom}`);
  }
}

/**
 * Copie de l'historique avec un point de cache sur le dernier message : à chaque tour, le début de la
 * conversation est relu depuis le cache (réponse plus rapide). L'historique gardé n'est pas modifié.
 */
export function avecCache(messages: Message[]): Message[] {
  if (!messages.length) return messages;
  const dernier = messages[messages.length - 1];
  const blocs: Record<string, unknown>[] =
    typeof dernier.content === 'string' ? [{ type: 'text', text: dernier.content }] : [...((dernier.content ?? []) as unknown as Record<string, unknown>[])];
  const fin = blocs.length - 1;
  if (fin < 0) return messages;
  blocs[fin] = { ...blocs[fin], cache_control: { type: 'ephemeral' } };
  return [...messages.slice(0, -1), { ...dernier, content: blocs } as unknown as Message];
}

/** Agent Claude : comprend le passager, appelle les outils de commande et rédige la réponse parlée. */
export class AgentIA {
  /** Historique par numéro WhatsApp. Il n'est jamais réécrit, seulement complété (puis oublié en fin de course). */
  private readonly historiques = new Map<string, Message[]>();

  constructor(private readonly client: Pick<Anthropic, 'beta'> = new Anthropic()) {}

  oublier(id: string) {
    this.historiques.delete(id);
  }

  /** Échange fait sans l'agent (bouton touché) : ajouté à l'historique pour la suite de la conversation. */
  noter(id: string, passager: string, reponse: string) {
    const messages = this.historiques.get(id) ?? [];
    this.historiques.set(id, messages);
    messages.push({ role: 'user', content: passager }, { role: 'assistant', content: reponse });
  }

  /** contexte : informations du moment (vocal ou écrit, position reçue, heure) placées avant le message du passager. */
  async repondre(cmd: Commande, texte: string, contexte: string): Promise<string> {
    const id = cmd.conv.id;
    const messages = this.historiques.get(id) ?? [];
    this.historiques.set(id, messages);
    messages.push({ role: 'user', content: `[${contexte}]\n${texte}` });

    for (let i = 0; i < MAX_TOURS_OUTILS; i++) {
      const rep = await this.client.beta.messages.create({
        model: MODELE,
        max_tokens: 1500,
        system: [{ type: 'text', text: PROMPT, cache_control: { type: 'ephemeral' } }],
        tools: OUTILS,
        messages: avecCache(messages),
        output_config: { effort: EFFORT },
        // Si le modèle décline une demande, l'API la relance sur un autre modèle Claude.
        betas: ['server-side-fallback-2026-07-01'],
        fallbacks: 'default',
      });
      // Contenu complet (y compris la réflexion) renvoyé tel quel au tour suivant.
      messages.push({ role: 'assistant', content: rep.content });

      if (rep.stop_reason === 'refusal') return '';
      const appels = rep.content.filter((b): b is Anthropic.Beta.BetaToolUseBlock => b.type === 'tool_use');
      if (rep.stop_reason !== 'tool_use' || appels.length === 0) {
        return rep.content
          .filter((b): b is Anthropic.Beta.BetaTextBlock => b.type === 'text')
          .map((b) => b.text)
          .join(' ')
          .trim();
      }
      const resultats: Anthropic.Beta.BetaToolResultBlockParam[] = [];
      for (const a of appels) {
        try {
          const r = await executer(cmd, a.name, (a.input ?? {}) as Record<string, unknown>);
          resultats.push({ type: 'tool_result', tool_use_id: a.id, content: JSON.stringify(r) });
        } catch (e) {
          resultats.push({ type: 'tool_result', tool_use_id: a.id, content: (e as Error).message, is_error: true });
        }
      }
      messages.push({ role: 'user', content: resultats });
    }
    return '';
  }
}
