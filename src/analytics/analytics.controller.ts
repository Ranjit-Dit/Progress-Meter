import { Controller, Get, UseGuards } from '@nestjs/common';
import { AuthenticatedUser } from '../auth/auth.types';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { UserRole } from '../database/entities/enums';
import { AnalyticsService } from './analytics.service';

@Controller('analytics')
@UseGuards(JwtAuthGuard, RolesGuard)
export class AnalyticsController {
  constructor(private readonly analytics: AnalyticsService) {}
  @Get('students/me') @Roles(UserRole.STUDENT) student(
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.analytics.studentDashboard(user);
  }
  @Get('industry/me') @Roles(UserRole.INDUSTRY) industry(
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.analytics.industryDashboard(user);
  }
}
