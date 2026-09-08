import { Column, Entity, OneToMany, PrimaryGeneratedColumn } from 'typeorm';
import { InstitutionAdmin } from './institution-admin.entity';
import { Student } from './student.entity';

@Entity('institutions')
export class Institution {
  @PrimaryGeneratedColumn('uuid') id: string;
  @Column({ length: 180, unique: true }) name: string;
  @Column({ length: 40, unique: true }) code: string;
  @Column({ length: 120, nullable: true }) location?: string;
  @OneToMany(() => Student, (student) => student.institutionRecord)
  students: Student[];
  @OneToMany(() => InstitutionAdmin, (admin) => admin.institution)
  admins: InstitutionAdmin[];
}
