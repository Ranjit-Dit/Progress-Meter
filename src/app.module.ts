import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { APP_GUARD } from '@nestjs/core';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { AuthModule } from './auth/auth.module';
import { StudentsModule } from './students/students.module';
import { SkillsModule } from './skills/skills.module';
import { SkillGapModule } from './skill-gap/skill-gap.module';
import { OpportunitiesModule } from './opportunities/opportunities.module';
import { ApplicationsModule } from './applications/applications.module';
import { LearningModule } from './learning/learning.module';
import { AssessmentsModule } from './assessments/assessments.module';
import { PortfolioModule } from './portfolio/portfolio.module';
import { NotificationsModule } from './notifications/notifications.module';
import { AnalyticsModule } from './analytics/analytics.module';
import { AuditModule } from './audit/audit.module';
import { InstitutionsModule } from './institutions/institutions.module';
import { AcademiciansModule } from './academicians/academicians.module';
import { InterviewsModule } from './interviews/interviews.module';
import { Application } from './database/entities/application.entity';
import { AssessmentAnswer } from './database/entities/assessment-answer.entity';
import { AssessmentAttempt } from './database/entities/assessment-attempt.entity';
import { AssessmentQuestion } from './database/entities/assessment-question.entity';
import { Course } from './database/entities/course.entity';
import { CourseSkill } from './database/entities/course-skill.entity';
import { CareerRole } from './database/entities/career-role.entity';
import { CareerRoleSkill } from './database/entities/career-role-skill.entity';
import { Opportunity } from './database/entities/opportunity.entity';
import { OpportunitySkill } from './database/entities/opportunity-skill.entity';
import { SkillCategory } from './database/entities/skill-category.entity';
import { Skill } from './database/entities/skill.entity';
import { StudentSkill } from './database/entities/student-skill.entity';
import { Student } from './database/entities/student.entity';
import { StudentAchievement } from './database/entities/student-achievement.entity';
import { StudentCertification } from './database/entities/student-certification.entity';
import { StudentProject } from './database/entities/student-project.entity';
import { Notification } from './database/entities/notification.entity';
import { AuditLog } from './database/entities/audit-log.entity';
import { Institution } from './database/entities/institution.entity';
import { InstitutionAdmin } from './database/entities/institution-admin.entity';
import { Academician } from './database/entities/academician.entity';
import { Interview } from './database/entities/interview.entity';
import { User } from './database/entities/user.entity';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
    }),
    ThrottlerModule.forRoot([{ ttl: 60000, limit: 100 }]),
    TypeOrmModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => ({
        type: 'postgres',
        host: configService.get<string>('DB_HOST', 'localhost'),
        port: Number(configService.get<string>('DB_PORT', '5432')),
        username: configService.get<string>('DB_USERNAME', 'progress'),
        password: configService.get<string>('DB_PASSWORD', 'progress'),
        database: configService.get<string>('DB_DATABASE', 'progress_meter'),
        entities: [
          User,
          Student,
          SkillCategory,
          Skill,
          CareerRole,
          CareerRoleSkill,
          StudentSkill,
          Opportunity,
          OpportunitySkill,
          Application,
          Course,
          CourseSkill,
          AssessmentQuestion,
          AssessmentAttempt,
          AssessmentAnswer,
          StudentProject,
          StudentCertification,
          StudentAchievement,
          Notification,
          AuditLog,
          Institution,
          InstitutionAdmin,
          Academician,
          Interview,
        ],
        synchronize:
          configService.get<string>('DB_SYNCHRONIZE', 'false') === 'true',
      }),
    }),
    AuthModule,
    StudentsModule,
    SkillsModule,
    SkillGapModule,
    OpportunitiesModule,
    ApplicationsModule,
    LearningModule,
    AssessmentsModule,
    PortfolioModule,
    NotificationsModule,
    AnalyticsModule,
    AuditModule,
    InstitutionsModule,
    AcademiciansModule,
    InterviewsModule,
  ],
  controllers: [AppController],
  providers: [AppService, { provide: APP_GUARD, useClass: ThrottlerGuard }],
})
export class AppModule {}
