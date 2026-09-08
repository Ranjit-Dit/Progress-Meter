import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module';
import { AssessmentAnswer } from '../database/entities/assessment-answer.entity';
import { AssessmentAttempt } from '../database/entities/assessment-attempt.entity';
import { AssessmentQuestion } from '../database/entities/assessment-question.entity';
import { Student } from '../database/entities/student.entity';
import {
  AssessmentQuestionsController,
  StudentAssessmentsController,
} from './assessments.controller';
import { AssessmentsService } from './assessments.service';

@Module({
  imports: [
    AuthModule,
    TypeOrmModule.forFeature([
      AssessmentQuestion,
      AssessmentAttempt,
      AssessmentAnswer,
      Student,
    ]),
  ],
  controllers: [AssessmentQuestionsController, StudentAssessmentsController],
  providers: [AssessmentsService],
})
export class AssessmentsModule {}
