import {
  Column,
  Entity,
  JoinColumn,
  OneToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { User } from './user.entity';

@Entity('academicians')
export class Academician {
  @PrimaryGeneratedColumn('uuid') id: string;
  @OneToOne(() => User, { nullable: false, onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;
  @Column({ name: 'first_name', length: 100 }) firstName: string;
  @Column({ name: 'last_name', length: 100 }) lastName: string;
  @Column({ length: 180, nullable: true }) institution?: string;
  @Column({ length: 120, nullable: true }) department?: string;
  @Column({ type: 'text', nullable: true }) expertise?: string;
  @Column({ type: 'text', nullable: true }) bio?: string;
}
