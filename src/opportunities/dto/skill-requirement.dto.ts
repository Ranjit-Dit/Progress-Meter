import { Type } from 'class-transformer';
import { IsBoolean, IsInt, IsUUID, Max, Min } from 'class-validator';

export class SkillRequirementDto {
  @IsUUID()
  skillId: string;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(5)
  minimumLevel: number;

  @IsBoolean()
  isRequired: boolean;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(5)
  priority: number;
}
