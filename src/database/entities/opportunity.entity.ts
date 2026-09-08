import {
  Column,
  Entity,
  JoinColumn,
  ManyToOne,
  OneToMany,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { Application } from './application.entity';
import { OpportunityStatus, OpportunityType } from './enums';
import { OpportunitySkill } from './opportunity-skill.entity';
import { User } from './user.entity';

@Entity('opportunities')
export class Opportunity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @ManyToOne(() => User, (user) => user.opportunities, { nullable: false })
  @JoinColumn({ name: 'created_by_user_id' })
  createdBy: User;

  @Column({ length: 160 })
  title: string;

  @Column({
    type: 'enum',
    enum: OpportunityType,
    enumName: 'opportunity_type_enum',
  })
  type: OpportunityType;

  @Column({ name: 'company_name', length: 160 })
  companyName: string;

  @Column({ type: 'text' })
  description: string;

  @Column({ length: 120, nullable: true })
  location?: string;

  @Column({ name: 'is_remote', default: false })
  isRemote: boolean;

  @Column({ name: 'eligibility_criteria', type: 'jsonb', nullable: true })
  eligibilityCriteria?: Record<string, unknown>;

  @Column({
    type: 'enum',
    enum: OpportunityStatus,
    enumName: 'opportunity_status_enum',
    default: OpportunityStatus.DRAFT,
  })
  status: OpportunityStatus;

  @Column({ type: 'timestamptz', nullable: true })
  deadline?: Date;

  @Column({
    name: 'created_at',
    type: 'timestamptz',
    default: () => 'CURRENT_TIMESTAMP',
  })
  createdAt: Date;

  @Column({
    name: 'updated_at',
    type: 'timestamptz',
    default: () => 'CURRENT_TIMESTAMP',
  })
  updatedAt: Date;

  @OneToMany(
    () => OpportunitySkill,
    (opportunitySkill) => opportunitySkill.opportunity,
  )
  skillRequirements: OpportunitySkill[];

  @OneToMany(() => Application, (application) => application.opportunity)
  applications: Application[];
}
