import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Post,
  UseGuards,
} from '@nestjs/common';
import { AuthenticatedUser } from '../auth/auth.types';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { UserRole } from '../database/entities/enums';
import { CreateInterviewDto } from './dto/create-interview.dto';
import { InterviewsService } from './interviews.service';
@Controller()
@UseGuards(JwtAuthGuard, RolesGuard)
export class InterviewsController {
  constructor(private readonly interviews: InterviewsService) {}
  @Post('industry/applications/:applicationId/interviews')
  @Roles(UserRole.INDUSTRY)
  create(
    @CurrentUser() user: AuthenticatedUser,
    @Param('applicationId', ParseUUIDPipe) applicationId: string,
    @Body() dto: CreateInterviewDto,
  ) {
    return this.interviews.create(user, applicationId, dto);
  }
  @Get('students/me/interviews') @Roles(UserRole.STUDENT) listMine(
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.interviews.listMine(user);
  }
}
