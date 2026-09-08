import { Column, Entity, ManyToOne, PrimaryGeneratedColumn } from 'typeorm';
import { Student } from './student.entity';

@Entity('student_achievements')
export class StudentAchievement {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @ManyToOne(() => Student, { nullable: false, onDelete: 'CASCADE' })
  student: Student;

  @Column({ length: 180 })
  title: string;

  @Column({ type: 'text', nullable: true })
  description?: string;

  @Column({ name: 'achievement_url', type: 'text', nullable: true })
  achievementUrl?: string;
}
