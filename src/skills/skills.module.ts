import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module';
import { CareerRole } from '../database/entities/career-role.entity';
import { SkillCategory } from '../database/entities/skill-category.entity';
import { Skill } from '../database/entities/skill.entity';
import { SkillsController } from './skills.controller';
import { SkillsService } from './skills.service';

@Module({
  imports: [
    AuthModule,
    TypeOrmModule.forFeature([SkillCategory, Skill, CareerRole]),
  ],
  controllers: [SkillsController],
  providers: [SkillsService],
  exports: [SkillsService],
})
export class SkillsModule {}
