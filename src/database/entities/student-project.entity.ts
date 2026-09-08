import { Column, Entity, ManyToOne, PrimaryGeneratedColumn } from 'typeorm';
import { Student } from './student.entity';

@Entity('student_projects')
export class StudentProject {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @ManyToOne(() => Student, { nullable: false, onDelete: 'CASCADE' })
  student: Student;

  @Column({ length: 180 })
  title: string;

  @Column({ type: 'text' })
  description: string;

  @Column({ name: 'project_url', type: 'text', nullable: true })
  projectUrl?: string;

  @Column({ name: 'is_verified', default: false })
  isVerified: boolean;
}
