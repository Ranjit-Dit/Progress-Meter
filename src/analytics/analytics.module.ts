import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module';
import { Application } from '../database/entities/application.entity';
import { Opportunity } from '../database/entities/opportunity.entity';
import { StudentSkill } from '../database/entities/student-skill.entity';
import { Student } from '../database/entities/student.entity';
import { AnalyticsController } from './analytics.controller';
import { AnalyticsService } from './analytics.service';
@Module({
  imports: [
    AuthModule,
    TypeOrmModule.forFeature([Student, StudentSkill, Application, Opportunity]),
  ],
  controllers: [AnalyticsController],
  providers: [AnalyticsService],
})
export class AnalyticsModule {}
