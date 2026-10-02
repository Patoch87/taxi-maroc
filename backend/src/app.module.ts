import { Controller, Get, Module } from '@nestjs/common';
import { ComplaintsController } from './complaints/complaints.controller';
import { FaresController } from './fares/fares.controller';
import { RidesController } from './rides/rides.controller';
import { RidesService } from './rides/rides.service';

@Controller()
class HealthController {
  @Get('health')
  health() {
    return { status: 'ok' };
  }
}

@Module({
  controllers: [HealthController, FaresController, RidesController, ComplaintsController],
  providers: [RidesService],
})
export class AppModule {}
