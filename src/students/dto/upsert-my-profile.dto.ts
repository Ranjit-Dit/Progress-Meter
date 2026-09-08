import {
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

export class UpsertMyProfileDto {
  @IsString()
  @MaxLength(100)
  firstName: string;

  @IsString()
  @MaxLength(100)
  lastName: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  institution?: string;

  @IsOptional()
  @IsUUID()
  institutionId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  department?: string;

  @IsOptional()
  @Min(2000)
  @Max(2100)
  graduationYear?: number;

  @IsOptional()
  @IsUUID()
  targetCareerRoleId?: string;
}
