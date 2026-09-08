import { Column, Entity, ManyToOne, PrimaryGeneratedColumn } from 'typeorm';
import { Skill } from './skill.entity';

@Entity('assessment_questions')
export class AssessmentQuestion {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @ManyToOne(() => Skill, { nullable: false, onDelete: 'CASCADE' })
  skill: Skill;

  @Column({ type: 'text' })
  prompt: string;

  @Column({ type: 'jsonb' })
  options: string[];

  @Column({ name: 'correct_answer', select: false })
  correctAnswer: string;

  @Column({ type: 'smallint', default: 1 })
  difficulty: number;

  @Column({ name: 'is_active', default: true })
  isActive: boolean;
}
