import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module';
import { Academician } from '../database/entities/academician.entity';
import { AcademiciansController } from './academicians.controller';
import { AcademiciansService } from './academicians.service';
@Module({
  imports: [AuthModule, TypeOrmModule.forFeature([Academician])],
  controllers: [AcademiciansController],
  providers: [AcademiciansService],
})
export class AcademiciansModule {}
