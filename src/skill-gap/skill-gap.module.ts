import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module';
import { CareerRoleSkill } from '../database/entities/career-role-skill.entity';
import { StudentSkill } from '../database/entities/student-skill.entity';
import { Student } from '../database/entities/student.entity';
import { SkillGapController } from './skill-gap.controller';
import { SkillGapService } from './skill-gap.service';

@Module({
  imports: [
    AuthModule,
    TypeOrmModule.forFeature([Student, StudentSkill, CareerRoleSkill]),
  ],
  controllers: [SkillGapController],
  providers: [SkillGapService],
  exports: [SkillGapService],
})
export class SkillGapModule {}
