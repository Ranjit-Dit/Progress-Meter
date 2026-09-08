import {
  Column,
  Entity,
  JoinColumn,
  ManyToOne,
  OneToMany,
  OneToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { Application } from './application.entity';
import { CareerRole } from './career-role.entity';
import { Institution } from './institution.entity';
import { StudentSkill } from './student-skill.entity';
import { User } from './user.entity';

@Entity('students')
export class Student {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @OneToOne(() => User, (user) => user.student, {
    nullable: false,
    onDelete: 'CASCADE',
  })
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({ name: 'first_name', length: 100 })
  firstName: string;

  @Column({ name: 'last_name', length: 100 })
  lastName: string;

  @Column({ length: 100, nullable: true })
  institution?: string;

  @ManyToOne(() => Institution, (institution) => institution.students, {
    nullable: true,
  })
  @JoinColumn({ name: 'institution_id' })
  institutionRecord?: Institution;

  @Column({ length: 100, nullable: true })
  department?: string;

  @Column({ name: 'graduation_year', type: 'smallint', nullable: true })
  graduationYear?: number;

  @ManyToOne(() => CareerRole, (careerRole) => careerRole.students, {
    nullable: true,
  })
  @JoinColumn({ name: 'target_career_role_id' })
  targetCareerRole?: CareerRole;

  @Column({
    name: 'readiness_score',
    type: 'decimal',
    precision: 5,
    scale: 2,
    default: 0,
  })
  readinessScore: number;

  @Column({ name: 'is_portfolio_public', default: false })
  isPortfolioPublic: boolean;

  @Column({ name: 'portfolio_slug', length: 80, nullable: true, unique: true })
  portfolioSlug?: string | null;

  @OneToMany(() => StudentSkill, (studentSkill) => studentSkill.student)
  skills: StudentSkill[];

  @OneToMany(() => Application, (application) => application.student)
  applications: Application[];
}
