import { IsOptional, IsString, MaxLength } from 'class-validator';
export class UpsertAcademicianProfileDto {
  @IsString() @MaxLength(100) firstName: string;
  @IsString() @MaxLength(100) lastName: string;
  @IsOptional() @IsString() @MaxLength(180) institution?: string;
  @IsOptional() @IsString() @MaxLength(120) department?: string;
  @IsOptional() @IsString() expertise?: string;
  @IsOptional() @IsString() bio?: string;
}
