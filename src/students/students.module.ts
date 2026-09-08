import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module';
import { CareerRole } from '../database/entities/career-role.entity';
import { Skill } from '../database/entities/skill.entity';
import { Student } from '../database/entities/student.entity';
import { StudentSkill } from '../database/entities/student-skill.entity';
import { Institution } from '../database/entities/institution.entity';
import { StudentsController } from './students.controller';
import { StudentsService } from './students.service';

@Module({
  imports: [
    AuthModule,
    TypeOrmModule.forFeature([
      Student,
      CareerRole,
      Skill,
      StudentSkill,
      Institution,
    ]),
  ],
  controllers: [StudentsController],
  providers: [StudentsService],
})
export class StudentsModule {}
