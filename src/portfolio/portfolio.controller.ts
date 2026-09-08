import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Post,
  Put,
  UseGuards,
} from '@nestjs/common';
import {
  IsDateString,
  IsOptional,
  IsString,
  IsUrl,
  MaxLength,
} from 'class-validator';
import { AuthenticatedUser } from '../auth/auth.types';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { UserRole } from '../database/entities/enums';
import { PortfolioService } from './portfolio.service';
import { SetPortfolioVisibilityDto } from './dto/set-portfolio-visibility.dto';

class ProjectDto {
  @IsString() @MaxLength(180) title: string;
  @IsString() description: string;
  @IsOptional() @IsUrl() projectUrl?: string;
}
class CertificationDto {
  @IsString() @MaxLength(180) name: string;
  @IsString() @MaxLength(140) issuer: string;
  @IsOptional() @IsUrl() credentialUrl?: string;
  @IsOptional() @IsDateString() issuedOn?: string;
}
class AchievementDto {
  @IsString() @MaxLength(180) title: string;
  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsUrl() achievementUrl?: string;
}

@Controller('students/me/portfolio')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.STUDENT)
export class PortfolioController {
  constructor(private readonly portfolio: PortfolioService) {}
  @Get() getMine(@CurrentUser() user: AuthenticatedUser) {
    return this.portfolio.getMine(user);
  }
  @Post('projects') addProject(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: ProjectDto,
  ) {
    return this.portfolio.addProject(user, dto);
  }
  @Post('certifications') addCertification(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: CertificationDto,
  ) {
    return this.portfolio.addCertification(user, dto);
  }
  @Post('achievements') addAchievement(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: AchievementDto,
  ) {
    return this.portfolio.addAchievement(user, dto);
  }
  @Put('visibility') setVisibility(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: SetPortfolioVisibilityDto,
  ) {
    return this.portfolio.setVisibility(user, dto.isPublic);
  }
  @Delete('projects/:id') @HttpCode(204) deleteProject(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.portfolio.deleteProject(user, id);
  }
  @Delete('certifications/:id') @HttpCode(204) deleteCertification(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.portfolio.deleteCertification(user, id);
  }
  @Delete('achievements/:id') @HttpCode(204) deleteAchievement(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.portfolio.deleteAchievement(user, id);
  }
}

@Controller('portfolios')
export class PublicPortfolioController {
  constructor(private readonly portfolio: PortfolioService) {}
  @Get(':slug') get(@Param('slug') slug: string) {
    return this.portfolio.getPublic(slug);
  }
}
