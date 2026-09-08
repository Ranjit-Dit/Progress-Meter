import {
  Column,
  Entity,
  Index,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { Opportunity } from './opportunity.entity';
import { Skill } from './skill.entity';

@Entity('opportunity_skills')
@Index(['opportunity', 'skill'], { unique: true })
export class OpportunitySkill {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @ManyToOne(
    () => Opportunity,
    (opportunity) => opportunity.skillRequirements,
    {
      onDelete: 'CASCADE',
    },
  )
  opportunity: Opportunity;

  @ManyToOne(() => Skill, (skill) => skill.opportunityRequirements, {
    onDelete: 'CASCADE',
  })
  skill: Skill;

  @Column({ name: 'minimum_level', type: 'smallint', default: 1 })
  minimumLevel: number;

  @Column({ name: 'is_required', default: true })
  isRequired: boolean;

  @Column({ type: 'smallint', default: 3 })
  priority: number;
}
