import {
  Column,
  Entity,
  Index,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { CareerRole } from './career-role.entity';
import { Skill } from './skill.entity';

@Entity('career_role_skills')
@Index(['careerRole', 'skill'], { unique: true })
export class CareerRoleSkill {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @ManyToOne(() => CareerRole, (careerRole) => careerRole.skillRequirements, {
    onDelete: 'CASCADE',
  })
  careerRole: CareerRole;

  @ManyToOne(() => Skill, (skill) => skill.careerRoleRequirements, {
    onDelete: 'CASCADE',
  })
  skill: Skill;

  @Column({ name: 'required_level', type: 'smallint' })
  requiredLevel: number;

  @Column({ type: 'smallint', default: 3 })
  priority: number;

  @Column({ type: 'decimal', precision: 5, scale: 2, default: 1 })
  weight: number;
}
