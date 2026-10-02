import { BadRequestException, Body, Controller, Delete, Param, Post, Put } from '@nestjs/common';
import { DemandePassager, TaxiEnRoute } from '../domain/matching';
import { RidesService } from './rides.service';

@Controller()
export class RidesController {
  constructor(private readonly rides: RidesService) {}

  /** Le chauffeur envoie sa position et son itinéraire (taxi disponible). */
  @Put('taxis/:id/route')
  updateRoute(@Param('id') id: string, @Body() body: Omit<TaxiEnRoute, 'id'>) {
    if (!Array.isArray(body?.itineraire) || body.itineraire.length < 2) {
      throw new BadRequestException('itineraire doit contenir au moins 2 points');
    }
    this.rides.updateTaxi({ ...body, id });
    return { ok: true };
  }

  /** Le chauffeur passe en « occupé » ou termine son service. */
  @Delete('taxis/:id/route')
  remove(@Param('id') id: string) {
    this.rides.removeTaxi(id);
    return { ok: true };
  }

  /** Le passager indique sa destination finale : liste des taxis qui passent sur sa route. */
  @Post('rides/match')
  match(@Body() body: DemandePassager) {
    if (!body?.depart || !body?.destination) throw new BadRequestException('depart et destination sont requis');
    return this.rides.match({ ...body, mode: body.mode ?? 'partage', passagers: body.passagers ?? 1 });
  }
}
