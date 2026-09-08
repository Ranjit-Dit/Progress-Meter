import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Put,
  UseGuards,
} from '@nestjs/common';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { AuthenticatedUser } from '../auth/auth.types';
import { UserRole } from '../database/entities/enums';
import { UpsertMyProfileDto } from './dto/upsert-my-profile.dto';
import { UpsertMySkillDto } from './dto/upsert-my-skill.dto';
import { StudentsService } from './students.service';

@Controller('students/me')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.STUDENT)
export class StudentsController {
  constructor(private readonly studentsService: StudentsService) {}

  @Get()
  getMyProfile(@CurrentUser() user: AuthenticatedUser) {
    return this.studentsService.getMyProfile(user);
  }

  @Put()
  upsertMyProfile(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: UpsertMyProfileDto,
  ) {
    return this.studentsService.upsertMyProfile(user, dto);
  }

  @Get('skills')
  listMySkills(@CurrentUser() user: AuthenticatedUser) {
    return this.studentsService.listMySkills(user);
  }

  @Put('skills/:skillId')
  upsertMySkill(
    @CurrentUser() user: AuthenticatedUser,
    @Param('skillId', ParseUUIDPipe) skillId: string,
    @Body() dto: UpsertMySkillDto,
  ) {
    return this.studentsService.upsertMySkill(user, skillId, dto);
  }

  @Delete('skills/:skillId')
  @HttpCode(204)
  removeMySkill(
    @CurrentUser() user: AuthenticatedUser,
    @Param('skillId', ParseUUIDPipe) skillId: string,
  ) {
    return this.studentsService.removeMySkill(user, skillId);
  }
}
