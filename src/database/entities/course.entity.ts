import {
  Column,
  Entity,
  Index,
  OneToMany,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { CourseSkill } from './course-skill.entity';

@Entity('courses')
export class Course {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index({ unique: true })
  @Column({ length: 180 })
  title: string;

  @Column({ length: 120 })
  provider: string;

  @Column({ type: 'text', nullable: true })
  description?: string;

  @Column({ name: 'url', type: 'text', nullable: true })
  url?: string;

  @Column({ name: 'estimated_hours', type: 'integer', nullable: true })
  estimatedHours?: number;

  @Column({ name: 'is_active', default: true })
  isActive: boolean;

  @OneToMany(() => CourseSkill, (courseSkill) => courseSkill.course)
  skillMappings: CourseSkill[];
}
