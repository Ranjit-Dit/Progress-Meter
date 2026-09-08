import {
  Column,
  Entity,
  Index,
  OneToMany,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { CareerRoleSkill } from './career-role-skill.entity';
import { Student } from './student.entity';

@Entity('career_roles')
export class CareerRole {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index({ unique: true })
  @Column({ length: 120 })
  name: string;

  @Index({ unique: true })
  @Column({ length: 140 })
  slug: string;

  @Column({ type: 'text', nullable: true })
  description?: string;

  @OneToMany(() => CareerRoleSkill, (roleSkill) => roleSkill.careerRole)
  skillRequirements: CareerRoleSkill[];

  @OneToMany(() => Student, (student) => student.targetCareerRole)
  students: Student[];
}
