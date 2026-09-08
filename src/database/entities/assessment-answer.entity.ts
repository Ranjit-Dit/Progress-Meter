import { Column, Entity, ManyToOne, PrimaryGeneratedColumn } from 'typeorm';
import { AssessmentAttempt } from './assessment-attempt.entity';
import { AssessmentQuestion } from './assessment-question.entity';

@Entity('assessment_answers')
export class AssessmentAnswer {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @ManyToOne(() => AssessmentAttempt, { nullable: false, onDelete: 'CASCADE' })
  attempt: AssessmentAttempt;

  @ManyToOne(() => AssessmentQuestion, { nullable: false, onDelete: 'CASCADE' })
  question: AssessmentQuestion;

  @Column({ name: 'selected_answer' })
  selectedAnswer: string;

  @Column({ name: 'is_correct' })
  isCorrect: boolean;
}
