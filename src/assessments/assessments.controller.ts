import {
  Body,
  Controller,
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
import { AssessmentsService } from './assessments.service';
import { CreateQuestionDto } from './dto/create-question.dto';
import { StartAssessmentDto } from './dto/start-assessment.dto';
import { SubmitAssessmentDto } from './dto/submit-assessment.dto';

@Controller('assessment-questions')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.ADMIN)
export class AssessmentQuestionsController {
  constructor(private readonly assessmentsService: AssessmentsService) {}

  @Post()
  create(@Body() dto: CreateQuestionDto) {
    return this.assessmentsService.createQuestion(dto);
  }
}

@Controller('students/me/assessments')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.STUDENT)
export class StudentAssessmentsController {
  constructor(private readonly assessmentsService: AssessmentsService) {}

  @Post('start')
  start(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: StartAssessmentDto,
  ) {
    return this.assessmentsService.start(user, dto);
  }

  @Post(':attemptId/submit')
  submit(
    @CurrentUser() user: AuthenticatedUser,
    @Param('attemptId', ParseUUIDPipe) attemptId: string,
    @Body() dto: SubmitAssessmentDto,
  ) {
    return this.assessmentsService.submit(user, attemptId, dto);
  }
}
