import {
  Column,
  Entity,
  Index,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { Course } from './course.entity';
import { Skill } from './skill.entity';

@Entity('course_skills')
@Index(['course', 'skill'], { unique: true })
export class CourseSkill {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @ManyToOne(() => Course, (course) => course.skillMappings, {
    onDelete: 'CASCADE',
  })
  course: Course;

  @ManyToOne(() => Skill, { onDelete: 'CASCADE' })
  skill: Skill;

  @Column({ type: 'smallint', default: 3 })
  priority: number;
}
