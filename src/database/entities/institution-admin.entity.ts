import {
  Entity,
  JoinColumn,
  ManyToOne,
  OneToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { Institution } from './institution.entity';
import { User } from './user.entity';
@Entity('institution_admins')
export class InstitutionAdmin {
  @PrimaryGeneratedColumn('uuid') id: string;
  @OneToOne(() => User, { nullable: false, onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;
  @ManyToOne(() => Institution, (institution) => institution.admins, {
    nullable: false,
    onDelete: 'CASCADE',
  })
  institution: Institution;
}
