import {
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AuthenticatedUser } from '../auth/auth.types';
import { Application } from '../database/entities/application.entity';
import { InstitutionAdmin } from '../database/entities/institution-admin.entity';
import { Institution } from '../database/entities/institution.entity';
import { StudentSkill } from '../database/entities/student-skill.entity';
import { Student } from '../database/entities/student.entity';
import { UserRole } from '../database/entities/enums';
import { User } from '../database/entities/user.entity';
import { CreateInstitutionDto } from './dto/create-institution.dto';

@Injectable()
export class InstitutionsService {
  constructor(
    @InjectRepository(Institution)
    private readonly institutions: Repository<Institution>,
    @InjectRepository(InstitutionAdmin)
    private readonly admins: Repository<InstitutionAdmin>,
    @InjectRepository(User) private readonly users: Repository<User>,
    @InjectRepository(Student) private readonly students: Repository<Student>,
    @InjectRepository(StudentSkill)
    private readonly skills: Repository<StudentSkill>,
    @InjectRepository(Application)
    private readonly applications: Repository<Application>,
  ) {}
  list() {
    return this.institutions.find({ order: { name: 'ASC' } });
  }
  async create(dto: CreateInstitutionDto) {
    const exists = await this.institutions.findOne({
      where: [
        { name: dto.name.trim() },
        { code: dto.code.trim().toUpperCase() },
      ],
    });
    if (exists)
      throw new ConflictException(
        'An institution with this name or code already exists.',
      );
    const adminUser = await this.users.findOne({
      where: { id: dto.adminUserId },
    });
    if (!adminUser || adminUser.role !== UserRole.INSTITUTION_ADMIN)
      throw new NotFoundException('An institution-admin user is required.');
    if (await this.admins.findOne({ where: { user: { id: adminUser.id } } }))
      throw new ConflictException(
        'This user already administers an institution.',
      );
    const institution = await this.institutions.save(
      this.institutions.create({
        name: dto.name.trim(),
        code: dto.code.trim().toUpperCase(),
        location: dto.location?.trim(),
      }),
    );
    await this.admins.save(
      this.admins.create({ user: adminUser, institution }),
    );
    return institution;
  }
  async dashboard(user: AuthenticatedUser) {
    const membership = await this.admins.findOne({
      where: { user: { id: user.id } },
      relations: { institution: true },
    });
    if (!membership)
      throw new NotFoundException(
        'Institution administrator profile was not found.',
      );
    const students = await this.students.find({
      where: { institutionRecord: { id: membership.institution.id } },
    });
    const ids = students.map((student) => student.id);
    const [skills, applications] = ids.length
      ? await Promise.all([
          this.skills
            .createQueryBuilder('skill')
            .where('skill."studentId" IN (:...ids)', { ids })
            .getMany(),
          this.applications
            .createQueryBuilder('application')
            .where('application."studentId" IN (:...ids)', { ids })
            .getMany(),
        ])
      : [[], []];
    const readiness = students.length
      ? Number(
          (
            students.reduce(
              (sum, student) => sum + Number(student.readinessScore),
              0,
            ) / students.length
          ).toFixed(2),
        )
      : 0;
    const counts = applications.reduce<Record<string, number>>(
      (result, application) => {
        result[application.status] = (result[application.status] ?? 0) + 1;
        return result;
      },
      {},
    );
    return {
      institution: membership.institution,
      students: {
        total: students.length,
        averageReadinessScore: readiness,
        verifiedSkills: skills.filter((skill) => skill.isVerified).length,
      },
      applications: { total: applications.length, byStatus: counts },
    };
  }
}
