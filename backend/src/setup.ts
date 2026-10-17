import { INestApplication } from '@nestjs/common';

/** Réglages communs au serveur et aux tests : CORS ouvert pour la version web (iPhone, Safari). */
export function configureApp(app: INestApplication) {
  app.enableCors({ origin: true, methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'] });
}
