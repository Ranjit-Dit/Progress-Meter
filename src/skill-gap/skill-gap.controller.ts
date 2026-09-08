import { Controller, Get, UseGuards } from '@nestjs/common';
import { AuthenticatedUser } from '../auth/auth.types';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { UserRole } from '../database/entities/enums';
import { SkillGapService } from './skill-gap.service';

@Controller('students/me/skill-gap')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.STUDENT)
export class SkillGapController {
  constructor(private readonly skillGapService: SkillGapService) {}

  @Get()
  analyzeMySkillGap(@CurrentUser() user: AuthenticatedUser) {
    return this.skillGapService.analyzeMySkillGap(user);
  }
}
