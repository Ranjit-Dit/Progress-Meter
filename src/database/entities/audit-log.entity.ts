import { Column, Entity, ManyToOne, PrimaryGeneratedColumn } from 'typeorm';
import { User } from './user.entity';

@Entity('audit_logs')
export class AuditLog {
  @PrimaryGeneratedColumn('uuid') id: string;
  @ManyToOne(() => User, { nullable: true, onDelete: 'SET NULL' }) actor?: User;
  @Column({ length: 120 }) action: string;
  @Column({ name: 'resource_type', length: 80 }) resourceType: string;
  @Column({ name: 'resource_id', type: 'uuid', nullable: true })
  resourceId?: string;
  @Column({ type: 'jsonb', nullable: true }) metadata?: Record<string, unknown>;
  @Column({
    name: 'created_at',
    type: 'timestamptz',
    default: () => 'CURRENT_TIMESTAMP',
  })
  createdAt: Date;
}
