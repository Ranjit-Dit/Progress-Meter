import { Type } from 'class-transformer';
import {
  ArrayNotEmpty,
  IsArray,
  IsInt,
  IsOptional,
  IsString,
  IsUrl,
  IsUUID,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';

class CourseSkillDto {
  @IsUUID()
  skillId: string;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  priority: number;
}

export class CreateCourseDto {
  @IsString()
  @MaxLength(180)
  title: string;

  @IsString()
  @MaxLength(120)
  provider: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsOptional()
  @IsUrl()
  url?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  estimatedHours?: number;

  @IsArray()
  @ArrayNotEmpty()
  @ValidateNested({ each: true })
  @Type(() => CourseSkillDto)
  skillMappings: CourseSkillDto[];
}
