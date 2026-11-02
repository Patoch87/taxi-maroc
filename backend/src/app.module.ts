import { Controller, Get, Module } from '@nestjs/common';
import { AccountsController } from './accounts/accounts.controller';
import { AccountsService } from './accounts/accounts.service';
import { AdminController } from './admin/admin.controller';
import { AdminService } from './admin/admin.service';
import { AdsController } from './ads/ads.controller';
import { StoreService } from './store/store.service';
import { DriversController } from './drivers/drivers.controller';
import { DriversService } from './drivers/drivers.service';
import { ComplaintsController } from './complaints/complaints.controller';
import { FaresController } from './fares/fares.controller';
import { RidesController } from './rides/rides.controller';
import { RidesService } from './rides/rides.service';
import { SosController } from './sos/sos.controller';
import { WhatsappController } from './whatsapp/whatsapp.controller';
import { WhatsappService } from './whatsapp/whatsapp.service';

@Controller()
class HealthController {
  constructor(private readonly store: StoreService) {}

  /** Page d'accueil du serveur : utile pour vérifier qu'il est réveillé (offre gratuite Render). */
  @Get()
  root() {
    return {
      service: 'Bab Taxi',
      status: 'ok',
      routes: [
        'GET /health',
        'GET /config',
        'POST /accounts',
        'POST /auth/(code|verify)',
        'POST /fares/petit-taxi',
        'POST /fares/grand-taxi',
        'PUT|DELETE /taxis/:id/route',
        'GET /taxis/nearby',
        'GET /taxis/:id/offers',
        'POST /rides/match',
        'POST /rides/requests',
        'GET /rides/requests/:id',
        'POST /rides/requests/:id/(cancel|accept|decline|pickup|dropoff)',
        'POST /chauffeurs/:id/(pieces/:piece|dossier)',
        'GET /chauffeurs/:id(/photo)',
        'GET /admin (console)',
        'GET /admin/chauffeurs?cle=…',
        'POST /complaints',
        'GET /ads',
        'POST /ads/:id/events',
        'POST /sos',
        'POST /sos/:id/(position|segments|end)',
        'GET /sos/centre?cle=…',
        'GET|POST /whatsapp/webhook',
        'GET /whatsapp/etat',
        'GET /whatsapp/demo',
      ],
    };
  }


  @Get('health')
  health() {
    // « base » : postgresql quand DATABASE_URL est branchée, sinon memoire (données perdues au redémarrage).
    return { status: 'ok', heure: new Date().toISOString(), base: this.store.persistante ? 'postgresql' : 'memoire' };
  }
}

@Module({
  controllers: [HealthController, AccountsController, FaresController, RidesController, ComplaintsController, AdsController, SosController, WhatsappController, DriversController, AdminController],
  providers: [StoreService, AccountsService, DriversService, RidesService, WhatsappService, AdminService],
})
export class AppModule {}
