import { Type } from 'class-transformer';
import {
  ArrayMinSize,
  IsArray,
  IsString,
  IsUUID,
  ValidateNested,
} from 'class-validator';

class SubmittedAnswerDto {
  @IsUUID()
  questionId: string;

  @IsString()
  selectedAnswer: string;
}

export class SubmitAssessmentDto {
  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => SubmittedAnswerDto)
  answers: SubmittedAnswerDto[];
}
