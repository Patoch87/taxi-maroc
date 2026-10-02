import { BadRequestException, Body, Controller, Post } from '@nestjs/common';
import { estimateGrandTaxi, estimatePetitTaxi } from '../domain/fare';
import { haversine, Point } from '../domain/geo';
import { RideMode, TaxiCategory } from '../domain/tariffs';

/** Facteur entre distance à vol d'oiseau et distance réelle par la route (en attendant l'API d'itinéraires). */
const FACTEUR_ROUTE = 1.3;

@Controller('fares')
export class FaresController {
  @Post('petit-taxi')
  petitTaxi(
    @Body() body: { depart: Point; destination: Point; mode?: RideMode; categorie?: TaxiCategory; date?: string },
  ) {
    if (!body?.depart || !body?.destination) throw new BadRequestException('depart et destination sont requis');
    const distanceM = haversine(body.depart, body.destination) * FACTEUR_ROUTE;
    return estimatePetitTaxi({
      distanceM,
      mode: body.mode ?? 'partage',
      categorie: body.categorie ?? 'standard',
      date: body.date ? new Date(body.date) : new Date(),
    });
  }

  @Post('grand-taxi')
  grandTaxi(@Body() body: { ligne: string; places?: number; taxiEntier?: boolean }) {
    try {
      return estimateGrandTaxi({ ligne: body.ligne, places: body.places ?? 1, taxiEntier: !!body.taxiEntier });
    } catch (e) {
      throw new BadRequestException((e as Error).message);
    }
  }
}
