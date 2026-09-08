import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Post,
  Put,
  Query,
  UseGuards,
} from '@nestjs/common';
import { AuthenticatedUser } from '../auth/auth.types';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { UserRole } from '../database/entities/enums';
import { CreateOpportunityDto } from './dto/create-opportunity.dto';
import { UpdateOpportunityDto } from './dto/update-opportunity.dto';
import { ListOpportunitiesDto } from './dto/list-opportunities.dto';
import { OpportunitiesService } from './opportunities.service';

@Controller('opportunities')
export class OpportunitiesController {
  constructor(private readonly opportunitiesService: OpportunitiesService) {}

  @Get()
  listPublished(@Query() query: ListOpportunitiesDto) {
    return this.opportunitiesService.listPublished(query);
  }

  @Get('mine')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.INDUSTRY)
  listMine(@CurrentUser() user: AuthenticatedUser) {
    return this.opportunitiesService.listMine(user);
  }

  @Get(':id')
  getPublished(@Param('id', ParseUUIDPipe) id: string) {
    return this.opportunitiesService.getPublished(id);
  }

  @Post()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.INDUSTRY)
  create(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: CreateOpportunityDto,
  ) {
    return this.opportunitiesService.create(user, dto);
  }

  @Put(':id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.INDUSTRY)
  update(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateOpportunityDto,
  ) {
    return this.opportunitiesService.update(user, id, dto);
  }
}
