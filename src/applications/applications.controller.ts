import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Post,
  Put,
  UseGuards,
} from '@nestjs/common';
import { AuthenticatedUser } from '../auth/auth.types';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { UserRole } from '../database/entities/enums';
import { ApplicationsService } from './applications.service';
import { CreateApplicationDto } from './dto/create-application.dto';
import { UpdateApplicationStatusDto } from './dto/update-application-status.dto';

@Controller('students/me')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.STUDENT)
export class ApplicationsController {
  constructor(private readonly applicationsService: ApplicationsService) {}

  @Get('opportunity-matches/:opportunityId')
  getMatch(
    @CurrentUser() user: AuthenticatedUser,
    @Param('opportunityId', ParseUUIDPipe) opportunityId: string,
  ) {
    return this.applicationsService.getMatch(user, opportunityId);
  }

  @Post('opportunities/:opportunityId/applications')
  create(
    @CurrentUser() user: AuthenticatedUser,
    @Param('opportunityId', ParseUUIDPipe) opportunityId: string,
    @Body() dto: CreateApplicationDto,
  ) {
    return this.applicationsService.create(user, opportunityId, dto);
  }

  @Get('applications')
  listMine(@CurrentUser() user: AuthenticatedUser) {
    return this.applicationsService.listMine(user);
  }

  @Put('applications/:applicationId/withdraw')
  withdraw(
    @CurrentUser() user: AuthenticatedUser,
    @Param('applicationId', ParseUUIDPipe) applicationId: string,
  ) {
    return this.applicationsService.withdraw(user, applicationId);
  }
}

@Controller('industry')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.INDUSTRY)
export class IndustryApplicationsController {
  constructor(private readonly applicationsService: ApplicationsService) {}

  @Get('opportunities/:opportunityId/applications')
  listApplicants(
    @CurrentUser() user: AuthenticatedUser,
    @Param('opportunityId', ParseUUIDPipe) opportunityId: string,
  ) {
    return this.applicationsService.listApplicants(user, opportunityId);
  }

  @Put('applications/:applicationId/status')
  updateStatus(
    @CurrentUser() user: AuthenticatedUser,
    @Param('applicationId', ParseUUIDPipe) applicationId: string,
    @Body() dto: UpdateApplicationStatusDto,
  ) {
    return this.applicationsService.updateStatus(user, applicationId, dto);
  }
}
