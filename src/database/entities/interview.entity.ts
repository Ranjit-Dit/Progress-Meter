import { Column, Entity, ManyToOne, PrimaryGeneratedColumn } from 'typeorm';
import { Application } from './application.entity';

@Entity('interviews')
export class Interview {
  @PrimaryGeneratedColumn('uuid') id: string;
  @ManyToOne(() => Application, { nullable: false, onDelete: 'CASCADE' })
  application: Application;
  @Column({ name: 'scheduled_at', type: 'timestamptz' }) scheduledAt: Date;
  @Column({ length: 120, nullable: true }) mode?: string;
  @Column({ name: 'meeting_url', type: 'text', nullable: true })
  meetingUrl?: string;
  @Column({ type: 'text', nullable: true }) notes?: string;
  @Column({ length: 30, default: 'scheduled' }) status: string;
  @Column({
    name: 'created_at',
    type: 'timestamptz',
    default: () => 'CURRENT_TIMESTAMP',
  })
  createdAt: Date;
}
