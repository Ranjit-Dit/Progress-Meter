import { Column, Entity, ManyToOne, PrimaryGeneratedColumn } from 'typeorm';
import { Student } from './student.entity';

@Entity('student_certifications')
export class StudentCertification {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @ManyToOne(() => Student, { nullable: false, onDelete: 'CASCADE' })
  student: Student;

  @Column({ length: 180 })
  name: string;

  @Column({ length: 140 })
  issuer: string;

  @Column({ name: 'credential_url', type: 'text', nullable: true })
  credentialUrl?: string;

  @Column({ name: 'issued_on', type: 'date', nullable: true })
  issuedOn?: string;

  @Column({ name: 'is_verified', default: false })
  isVerified: boolean;
}
