import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module';
import { Application } from '../database/entities/application.entity';
import { InstitutionAdmin } from '../database/entities/institution-admin.entity';
import { Institution } from '../database/entities/institution.entity';
import { StudentSkill } from '../database/entities/student-skill.entity';
import { Student } from '../database/entities/student.entity';
import { User } from '../database/entities/user.entity';
import { InstitutionsController } from './institutions.controller';
import { InstitutionsService } from './institutions.service';
@Module({
  imports: [
    AuthModule,
    TypeOrmModule.forFeature([
      Institution,
      InstitutionAdmin,
      User,
      Student,
      StudentSkill,
      Application,
    ]),
  ],
  controllers: [InstitutionsController],
  providers: [InstitutionsService],
})
export class InstitutionsModule {}
