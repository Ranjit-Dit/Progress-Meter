import { IsOptional, IsString, IsUUID, MaxLength } from 'class-validator';
export class CreateInstitutionDto {
  @IsString() @MaxLength(180) name: string;
  @IsString() @MaxLength(40) code: string;
  @IsOptional() @IsString() @MaxLength(120) location?: string;
  @IsUUID() adminUserId: string;
}
