import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module';
import { StudentAchievement } from '../database/entities/student-achievement.entity';
import { StudentCertification } from '../database/entities/student-certification.entity';
import { StudentProject } from '../database/entities/student-project.entity';
import { Student } from '../database/entities/student.entity';
import {
  PortfolioController,
  PublicPortfolioController,
} from './portfolio.controller';
import { PortfolioService } from './portfolio.service';

@Module({
  imports: [
    AuthModule,
    TypeOrmModule.forFeature([
      Student,
      StudentProject,
      StudentCertification,
      StudentAchievement,
    ]),
  ],
  controllers: [PortfolioController, PublicPortfolioController],
  providers: [PortfolioService],
})
export class PortfolioModule {}
