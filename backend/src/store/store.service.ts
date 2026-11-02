import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { Pool } from 'pg';

/**
 * Données à garder d'un redémarrage à l'autre (comptes, plaintes, compteurs de publicité, courses terminées).
 *
 * Tout est lu en mémoire au démarrage, puis chaque écriture part aussi dans PostgreSQL quand la variable
 * DATABASE_URL existe (base Render). Sans base, le serveur fonctionne comme avant, en mémoire seulement.
 * Les lectures restent donc instantanées ; la base ne sert qu'à ne rien perdre.
 */
@Injectable()
export class StoreService implements OnModuleInit, OnModuleDestroy {
  private readonly log = new Logger('Base');
  private readonly data = new Map<string, Map<string, unknown>>();
  private pool?: Pool;
  private ecritures: Promise<unknown> = Promise.resolve();

  /** Base de données branchée (sinon mémoire seulement). */
  get persistante() {
    return !!this.pool;
  }

  async onModuleInit() {
    const url = process.env.DATABASE_URL;
    if (!url) return;
    try {
      const pool = new Pool({
        connectionString: url,
        max: 5,
        // Base Render : connexion chiffrée ; base locale (tests) : sans.
        ssl: /localhost|127\.0\.0\.1/.test(url) ? undefined : { rejectUnauthorized: false },
      });
      await pool.query(
        `CREATE TABLE IF NOT EXISTS bab_donnees (
           collection text NOT NULL,
           id text NOT NULL,
           donnees jsonb NOT NULL,
           maj_le timestamptz NOT NULL DEFAULT now(),
           PRIMARY KEY (collection, id)
         )`,
      );
      const r = await pool.query<{ collection: string; id: string; donnees: unknown }>(
        'SELECT collection, id, donnees FROM bab_donnees',
      );
      for (const row of r.rows) this.coll(row.collection).set(row.id, row.donnees);
      this.pool = pool;
      this.log.log(`PostgreSQL branchée : ${r.rowCount} enregistrements chargés`);
    } catch (e) {
      this.log.error(`PostgreSQL injoignable, données en mémoire seulement : ${(e as Error).message}`);
    }
  }

  async onModuleDestroy() {
    await this.ecritures.catch(() => undefined);
    await this.pool?.end();
  }

  private coll(nom: string) {
    let c = this.data.get(nom);
    if (!c) {
      c = new Map();
      this.data.set(nom, c);
    }
    return c;
  }

  get<T>(collection: string, id: string): T | undefined {
    return this.coll(collection).get(id) as T | undefined;
  }

  list<T>(collection: string): T[] {
    return [...this.coll(collection).values()] as T[];
  }

  put<T>(collection: string, id: string, valeur: T): T {
    this.coll(collection).set(id, valeur);
    const pool = this.pool;
    if (pool) {
      // Les écritures partent dans l'ordre, sans faire attendre la réponse au téléphone.
      this.ecritures = this.ecritures
        .catch(() => undefined)
        .then(() =>
          pool.query(
            `INSERT INTO bab_donnees (collection, id, donnees, maj_le) VALUES ($1, $2, $3, now())
             ON CONFLICT (collection, id) DO UPDATE SET donnees = EXCLUDED.donnees, maj_le = now()`,
            [collection, id, JSON.stringify(valeur)],
          ),
        )
        .catch((e) => this.log.error(`Écriture ${collection}/${id} : ${(e as Error).message}`));
    }
    return valeur;
  }

  /** Attend la fin des écritures en cours (tests). */
  flush() {
    return this.ecritures;
  }
}
