import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { AuthenticatedUser } from '../auth/auth.types';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { UserRole } from '../database/entities/enums';
import { CreateInstitutionDto } from './dto/create-institution.dto';
import { InstitutionsService } from './institutions.service';
@Controller('institutions')
export class InstitutionsController {
  constructor(private readonly institutions: InstitutionsService) {}
  @Get() list() {
    return this.institutions.list();
  }
  @Post() @UseGuards(JwtAuthGuard, RolesGuard) @Roles(UserRole.ADMIN) create(
    @Body() dto: CreateInstitutionDto,
  ) {
    return this.institutions.create(dto);
  }
  @Get('me/dashboard')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.INSTITUTION_ADMIN)
  dashboard(@CurrentUser() user: AuthenticatedUser) {
    return this.institutions.dashboard(user);
  }
}
