import { Controller, Get, Module } from '@nestjs/common';
import { AdsController } from './ads/ads.controller';
import { ComplaintsController } from './complaints/complaints.controller';
import { FaresController } from './fares/fares.controller';
import { RidesController } from './rides/rides.controller';
import { RidesService } from './rides/rides.service';
import { SosController } from './sos/sos.controller';
import { WhatsappController } from './whatsapp/whatsapp.controller';
import { WhatsappService } from './whatsapp/whatsapp.service';

@Controller()
class HealthController {
  /** Page d'accueil du serveur : utile pour vérifier qu'il est réveillé (offre gratuite Render). */
  @Get()
  root() {
    return {
      service: 'Bab Taxi',
      status: 'ok',
      routes: [
        'GET /health',
        'POST /fares/petit-taxi',
        'POST /fares/grand-taxi',
        'PUT|DELETE /taxis/:id/route',
        'GET /taxis/nearby',
        'GET /taxis/:id/offers',
        'POST /rides/match',
        'POST /rides/requests',
        'GET /rides/requests/:id',
        'POST /rides/requests/:id/(cancel|accept|decline|pickup|dropoff)',
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
    return { status: 'ok', heure: new Date().toISOString() };
  }
}

@Module({
  controllers: [HealthController, FaresController, RidesController, ComplaintsController, AdsController, SosController, WhatsappController],
  providers: [RidesService, WhatsappService],
})
export class AppModule {}
