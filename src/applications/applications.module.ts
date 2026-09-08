import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { AuditModule } from '../audit/audit.module';
import { Application } from '../database/entities/application.entity';
import { Opportunity } from '../database/entities/opportunity.entity';
import { StudentSkill } from '../database/entities/student-skill.entity';
import { Student } from '../database/entities/student.entity';
import {
  ApplicationsController,
  IndustryApplicationsController,
} from './applications.controller';
import { ApplicationsService } from './applications.service';

@Module({
  imports: [
    AuthModule,
    NotificationsModule,
    AuditModule,
    TypeOrmModule.forFeature([Student, StudentSkill, Opportunity, Application]),
  ],
  controllers: [ApplicationsController, IndustryApplicationsController],
  providers: [ApplicationsService],
})
export class ApplicationsModule {}
