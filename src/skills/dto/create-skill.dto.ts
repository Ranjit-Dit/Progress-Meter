import { IsOptional, IsString, IsUUID, MaxLength } from 'class-validator';

export class CreateSkillDto {
  @IsString()
  @MaxLength(100)
  name: string;

  @IsString()
  @MaxLength(120)
  slug: string;

  @IsUUID()
  categoryId: string;

  @IsOptional()
  @IsString()
  description?: string;
}
