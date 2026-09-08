import { IsOptional, IsString, MaxLength } from 'class-validator';

export class CreateCareerRoleDto {
  @IsString()
  @MaxLength(120)
  name: string;

  @IsString()
  @MaxLength(140)
  slug: string;

  @IsOptional()
  @IsString()
  description?: string;
}
