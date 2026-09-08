import {
  Column,
  Entity,
  Index,
  ManyToOne,
  OneToMany,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { CareerRoleSkill } from './career-role-skill.entity';
import { CourseSkill } from './course-skill.entity';
import { OpportunitySkill } from './opportunity-skill.entity';
import { SkillCategory } from './skill-category.entity';
import { StudentSkill } from './student-skill.entity';

@Entity('skills')
export class Skill {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index({ unique: true })
  @Column({ length: 100 })
  name: string;

  @Index({ unique: true })
  @Column({ length: 120 })
  slug: string;

  @Column({ type: 'text', nullable: true })
  description?: string;

  @ManyToOne(() => SkillCategory, (category) => category.skills, {
    nullable: false,
  })
  category: SkillCategory;

  @OneToMany(() => StudentSkill, (studentSkill) => studentSkill.skill)
  studentSkills: StudentSkill[];

  @OneToMany(() => CareerRoleSkill, (roleSkill) => roleSkill.skill)
  careerRoleRequirements: CareerRoleSkill[];

  @OneToMany(
    () => OpportunitySkill,
    (opportunitySkill) => opportunitySkill.skill,
  )
  opportunityRequirements: OpportunitySkill[];

  @OneToMany(() => CourseSkill, (courseSkill) => courseSkill.skill)
  courseMappings: CourseSkill[];
}
