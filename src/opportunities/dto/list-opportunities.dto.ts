import { Type } from 'class-transformer';
import { IsEnum, IsOptional, IsString, Max, Min } from 'class-validator';
import { OpportunityType } from '../../database/entities/enums';
export class ListOpportunitiesDto {
  @IsOptional() @IsString() search?: string;
  @IsOptional() @IsString() location?: string;
  @IsOptional() @IsEnum(OpportunityType) type?: OpportunityType;
  @IsOptional() @Type(() => Number) @Min(1) page?: number;
  @IsOptional() @Type(() => Number) @Min(1) @Max(50) limit?: number;
}
