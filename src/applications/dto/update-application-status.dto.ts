import { IsEnum } from 'class-validator';
import { ApplicationStatus } from '../../database/entities/enums';

export class UpdateApplicationStatusDto {
  @IsEnum(ApplicationStatus)
  status: ApplicationStatus;
}
