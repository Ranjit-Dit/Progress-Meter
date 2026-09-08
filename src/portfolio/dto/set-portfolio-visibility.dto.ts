import { IsBoolean } from 'class-validator';
export class SetPortfolioVisibilityDto {
  @IsBoolean() isPublic: boolean;
}
