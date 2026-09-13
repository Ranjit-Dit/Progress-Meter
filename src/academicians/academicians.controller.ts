import { Body, Controller, Get, Put, UseGuards } from '@nestjs/common';
import { AuthenticatedUser } from '../auth/auth.types';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { UserRole } from '../database/entities/enums';
import { AcademiciansService } from './academicians.service';
import { UpsertAcademicianProfileDto } from './dto/upsert-my-profile.dto';
@Controller('academicians/me')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.ACADEMICIAN)
export class AcademiciansController {
  constructor(private readonly academicians: AcademiciansService) {}
  @Get() getMine(@CurrentUser() user: AuthenticatedUser) {
    return this.academicians.getMine(user);
  }
  @Put() upsertMine(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: UpsertAcademicianProfileDto,
  ) {
    return this.academicians.upsertMine(user, dto);
  }
}
