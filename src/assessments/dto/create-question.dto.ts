import {
  ArrayMinSize,
  IsArray,
  IsInt,
  IsString,
  IsUUID,
  Max,
  Min,
} from 'class-validator';

export class CreateQuestionDto {
  @IsUUID()
  skillId: string;

  @IsString()
  prompt: string;

  @IsArray()
  @ArrayMinSize(2)
  @IsString({ each: true })
  options: string[];

  @IsString()
  correctAnswer: string;

  @IsInt()
  @Min(1)
  @Max(5)
  difficulty: number;
}
