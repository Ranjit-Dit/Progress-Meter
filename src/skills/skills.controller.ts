import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Put,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { UserRole } from '../database/entities/enums';
import { CreateCareerRoleDto } from './dto/create-career-role.dto';
import { CreateSkillCategoryDto } from './dto/create-skill-category.dto';
import { CreateSkillDto } from './dto/create-skill.dto';
import { ReplaceCareerRoleRequirementsDto } from './dto/replace-career-role-requirements.dto';
import { SkillsService } from './skills.service';

@Controller()
export class SkillsController {
  constructor(private readonly skillsService: SkillsService) {}

  @Get('skill-categories')
  listCategories() {
    return this.skillsService.listCategories();
  }

  @Get('skills')
  listSkills() {
    return this.skillsService.listSkills();
  }

  @Get('career-roles')
  listCareerRoles() {
    return this.skillsService.listCareerRoles();
  }

  @Get('career-roles/:id')
  getCareerRole(@Param('id') id: string) {
    return this.skillsService.getCareerRole(id);
  }

  @Post('skill-categories')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  createCategory(@Body() dto: CreateSkillCategoryDto) {
    return this.skillsService.createCategory(dto);
  }

  @Post('skills')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  createSkill(@Body() dto: CreateSkillDto) {
    return this.skillsService.createSkill(dto);
  }

  @Post('career-roles')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  createCareerRole(@Body() dto: CreateCareerRoleDto) {
    return this.skillsService.createCareerRole(dto);
  }

  @Put('career-roles/:id/requirements')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  replaceCareerRoleRequirements(
    @Param('id') id: string,
    @Body() dto: ReplaceCareerRoleRequirementsDto,
  ) {
    return this.skillsService.replaceCareerRoleRequirements(id, dto);
  }
}
