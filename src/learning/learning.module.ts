import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module';
import { Course } from '../database/entities/course.entity';
import { SkillGapModule } from '../skill-gap/skill-gap.module';
import { LearningController } from './learning.controller';
import { LearningService } from './learning.service';

@Module({
  imports: [AuthModule, SkillGapModule, TypeOrmModule.forFeature([Course])],
  controllers: [LearningController],
  providers: [LearningService],
})
export class LearningModule {}
