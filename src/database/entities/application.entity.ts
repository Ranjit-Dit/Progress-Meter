import {
  Column,
  Entity,
  Index,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { ApplicationStatus } from './enums';
import { Opportunity } from './opportunity.entity';
import { Student } from './student.entity';

@Entity('applications')
@Index(['student', 'opportunity'], { unique: true })
export class Application {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @ManyToOne(() => Student, (student) => student.applications, {
    onDelete: 'CASCADE',
  })
  student: Student;

  @ManyToOne(() => Opportunity, (opportunity) => opportunity.applications, {
    onDelete: 'CASCADE',
  })
  opportunity: Opportunity;

  @Column({
    type: 'enum',
    enum: ApplicationStatus,
    enumName: 'application_status_enum',
    default: ApplicationStatus.SUBMITTED,
  })
  status: ApplicationStatus;

  @Column({
    name: 'compatibility_score',
    type: 'decimal',
    precision: 5,
    scale: 2,
    nullable: true,
  })
  compatibilityScore?: number;

  @Column({ name: 'cover_note', type: 'text', nullable: true })
  coverNote?: string;

  @Column({
    name: 'applied_at',
    type: 'timestamptz',
    default: () => 'CURRENT_TIMESTAMP',
  })
  appliedAt: Date;

  @Column({
    name: 'updated_at',
    type: 'timestamptz',
    default: () => 'CURRENT_TIMESTAMP',
  })
  updatedAt: Date;
}
