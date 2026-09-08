import { Type } from 'class-transformer';
import {
  IsArray,
  IsBoolean,
  IsDateString,
  IsEnum,
  IsNotEmpty,
  IsObject,
  IsOptional,
  IsString,
  MaxLength,
  ValidateNested,
} from 'class-validator';
import {
  OpportunityStatus,
  OpportunityType,
} from '../../database/entities/enums';
import { SkillRequirementDto } from './skill-requirement.dto';

export class CreateOpportunityDto {
  @IsString()
  @MaxLength(160)
  title: string;

  @IsEnum(OpportunityType)
  type: OpportunityType;

  @IsString()
  @MaxLength(160)
  companyName: string;

  @IsString()
  @IsNotEmpty()
  description: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  location?: string;

  @IsOptional()
  @IsBoolean()
  isRemote?: boolean;

  @IsOptional()
  @IsObject()
  eligibilityCriteria?: Record<string, unknown>;

  @IsOptional()
  @IsDateString()
  deadline?: string;

  @IsOptional()
  @IsEnum(OpportunityStatus)
  status?: OpportunityStatus;

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => SkillRequirementDto)
  skillRequirements: SkillRequirementDto[];
}
