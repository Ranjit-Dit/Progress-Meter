import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { AuthenticatedUser } from '../auth/auth.types';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { UserRole } from '../database/entities/enums';
import { CreateCourseDto } from './dto/create-course.dto';
import { LearningService } from './learning.service';

@Controller()
export class LearningController {
  constructor(private readonly learningService: LearningService) {}

  @Get('courses')
  listCourses() {
    return this.learningService.listCourses();
  }

  @Post('courses')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  createCourse(@Body() dto: CreateCourseDto) {
    return this.learningService.createCourse(dto);
  }

  @Get('students/me/learning-recommendations')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.STUDENT)
  getRecommendations(@CurrentUser() user: AuthenticatedUser) {
    return this.learningService.getRecommendations(user);
  }
}
