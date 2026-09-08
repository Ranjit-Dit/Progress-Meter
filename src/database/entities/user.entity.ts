import {
  Column,
  Entity,
  Index,
  OneToMany,
  OneToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { Opportunity } from './opportunity.entity';
import { Student } from './student.entity';
import { UserRole } from './enums';

@Entity('users')
export class User {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index({ unique: true })
  @Column({ length: 255 })
  email: string;

  @Column({ name: 'password_hash', select: false })
  passwordHash: string;

  @Column({ type: 'enum', enum: UserRole, enumName: 'user_role_enum' })
  role: UserRole;

  @Column({ name: 'is_email_verified', default: false })
  isEmailVerified: boolean;

  @Column({ name: 'is_active', default: true })
  isActive: boolean;

  @Column({
    name: 'refresh_token_hash',
    type: 'varchar',
    nullable: true,
    select: false,
  })
  refreshTokenHash?: string | null;

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

  @OneToOne(() => Student, (student) => student.user)
  student?: Student;

  @OneToMany(() => Opportunity, (opportunity) => opportunity.createdBy)
  opportunities: Opportunity[];
}
