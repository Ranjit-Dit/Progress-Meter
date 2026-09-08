import { IsUUID } from 'class-validator';

export class StartAssessmentDto {
  @IsUUID()
  skillId: string;
}
