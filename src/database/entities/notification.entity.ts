import { Column, Entity, ManyToOne, PrimaryGeneratedColumn } from 'typeorm';
import { User } from './user.entity';

@Entity('notifications')
export class Notification {
  @PrimaryGeneratedColumn('uuid') id: string;
  @ManyToOne(() => User, { nullable: false, onDelete: 'CASCADE' }) user: User;
  @Column({ length: 180 }) title: string;
  @Column({ type: 'text' }) message: string;
  @Column({ name: 'is_read', default: false }) isRead: boolean;
  @Column({
    name: 'created_at',
    type: 'timestamptz',
    default: () => 'CURRENT_TIMESTAMP',
  })
  createdAt: Date;
}
