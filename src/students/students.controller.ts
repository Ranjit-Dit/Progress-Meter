import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Put,
  MaxFileSizeValidator,
  ParseFilePipe,
  UseGuards,
  UseInterceptors,
  UploadedFile,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import { extname, join } from 'path';
import { mkdirSync } from 'fs';
import { randomUUID } from 'crypto';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { AuthenticatedUser } from '../auth/auth.types';
import { UserRole } from '../database/entities/enums';
import { UpsertMyProfileDto } from './dto/upsert-my-profile.dto';
import { UpsertMySkillDto } from './dto/upsert-my-skill.dto';
import { StudentsService } from './students.service';

@Controller('students/me')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.STUDENT)
export class StudentsController {
  constructor(private readonly studentsService: StudentsService) {}

  @Get()
  getMyProfile(@CurrentUser() user: AuthenticatedUser) {
    return this.studentsService.getMyProfile(user);
  }

  @Put()
  upsertMyProfile(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: UpsertMyProfileDto,
  ) {
    return this.studentsService.upsertMyProfile(user, dto);
  }

  @Get('skills')
  listMySkills(@CurrentUser() user: AuthenticatedUser) {
    return this.studentsService.listMySkills(user);
  }

  @Put('skills/:skillId')
  upsertMySkill(
    @CurrentUser() user: AuthenticatedUser,
    @Param('skillId', ParseUUIDPipe) skillId: string,
    @Body() dto: UpsertMySkillDto,
  ) {
    return this.studentsService.upsertMySkill(user, skillId, dto);
  }

  @Delete('skills/:skillId')
  @HttpCode(204)
  removeMySkill(
    @CurrentUser() user: AuthenticatedUser,
    @Param('skillId', ParseUUIDPipe) skillId: string,
  ) {
    return this.studentsService.removeMySkill(user, skillId);
  }

  @Get('resume')
  getResume(@CurrentUser() user: AuthenticatedUser) {
    return this.studentsService.getResume(user);
  }

  @Put('resume')
  @UseInterceptors(
    FileInterceptor('file', {
      storage: diskStorage({
        destination: (_request, _file, callback) => {
          const destination = join(process.cwd(), 'uploads', 'resumes');
          mkdirSync(destination, { recursive: true });
          callback(null, destination);
        },
        filename: (_request, file, callback) =>
          callback(
            null,
            `${randomUUID()}${extname(file.originalname).toLowerCase()}`,
          ),
      }),
      fileFilter: (_request, file, callback) =>
        callback(null, file.mimetype === 'application/pdf'),
    }),
  )
  uploadResume(
    @CurrentUser() user: AuthenticatedUser,
    @UploadedFile(
      new ParseFilePipe({
        validators: [
          new MaxFileSizeValidator({ maxSize: 5 * 1024 * 1024 }),
        ],
      }),
    )
    file: Express.Multer.File,
  ) {
    return this.studentsService.saveResume(user, file);
  }
}
