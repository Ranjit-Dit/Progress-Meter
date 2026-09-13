import {
  IsDateString,
  IsOptional,
  IsString,
  IsUrl,
  MaxLength,
} from 'class-validator';
export class CreateInterviewDto {
  @IsDateString() scheduledAt: string;
  @IsOptional() @IsString() @MaxLength(120) mode?: string;
  @IsOptional() @IsUrl() meetingUrl?: string;
  @IsOptional() @IsString() notes?: string;
}
