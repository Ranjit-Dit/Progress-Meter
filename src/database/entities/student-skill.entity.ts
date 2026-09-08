import {
  Column,
  Entity,
  Index,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { SkillEvidenceSource } from './enums';
import { Skill } from './skill.entity';
import { Student } from './student.entity';

@Entity('student_skills')
@Index(['student', 'skill'], { unique: true })
export class StudentSkill {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @ManyToOne(() => Student, (student) => student.skills, {
    onDelete: 'CASCADE',
  })
  student: Student;

  @ManyToOne(() => Skill, (skill) => skill.studentSkills, {
    onDelete: 'CASCADE',
  })
  skill: Skill;

  @Column({ name: 'proficiency_level', type: 'smallint' })
  proficiencyLevel: number;

  @Column({
    type: 'enum',
    enum: SkillEvidenceSource,
    enumName: 'skill_evidence_source_enum',
    default: SkillEvidenceSource.SELF_DECLARED,
  })
  source: SkillEvidenceSource;

  @Column({ name: 'is_verified', default: false })
  isVerified: boolean;
}
