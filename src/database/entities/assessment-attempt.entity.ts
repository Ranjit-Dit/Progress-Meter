import { Column, Entity, ManyToOne, PrimaryGeneratedColumn } from 'typeorm';
import { Skill } from './skill.entity';
import { Student } from './student.entity';

@Entity('assessment_attempts')
export class AssessmentAttempt {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @ManyToOne(() => Student, { nullable: false, onDelete: 'CASCADE' })
  student: Student;

  @ManyToOne(() => Skill, { nullable: false, onDelete: 'CASCADE' })
  skill: Skill;

  @Column({ default: 'in_progress' })
  status: string;

  @Column({ type: 'decimal', precision: 5, scale: 2, nullable: true })
  score?: number;

  @Column({
    name: 'started_at',
    type: 'timestamptz',
    default: () => 'CURRENT_TIMESTAMP',
  })
  startedAt: Date;

  @Column({ name: 'submitted_at', type: 'timestamptz', nullable: true })
  submittedAt?: Date;
}
