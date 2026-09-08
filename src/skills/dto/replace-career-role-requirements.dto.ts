import { Type } from 'class-transformer';
import {
  ArrayNotEmpty,
  IsArray,
  IsInt,
  IsNumber,
  IsUUID,
  Max,
  Min,
  ValidateNested,
} from 'class-validator';

class CareerRoleSkillRequirementDto {
  @IsUUID()
  skillId: string;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(5)
  requiredLevel: number;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(5)
  priority: number;

  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.01)
  weight: number;
}

export class ReplaceCareerRoleRequirementsDto {
  @IsArray()
  @ArrayNotEmpty()
  @ValidateNested({ each: true })
  @Type(() => CareerRoleSkillRequirementDto)
  requirements: CareerRoleSkillRequirementDto[];
}
