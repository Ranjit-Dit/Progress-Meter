import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AuthenticatedUser } from '../auth/auth.types';
import { CareerRole } from '../database/entities/career-role.entity';
import { SkillEvidenceSource } from '../database/entities/enums';
import { Skill } from '../database/entities/skill.entity';
import { Student } from '../database/entities/student.entity';
import { StudentSkill } from '../database/entities/student-skill.entity';
import { Institution } from '../database/entities/institution.entity';
import { UpsertMyProfileDto } from './dto/upsert-my-profile.dto';
import { UpsertMySkillDto } from './dto/upsert-my-skill.dto';

@Injectable()
export class StudentsService {
  constructor(
    @InjectRepository(Student)
    private readonly studentsRepository: Repository<Student>,
    @InjectRepository(CareerRole)
    private readonly careerRolesRepository: Repository<CareerRole>,
    @InjectRepository(Skill)
    private readonly skillsRepository: Repository<Skill>,
    @InjectRepository(StudentSkill)
    private readonly studentSkillsRepository: Repository<StudentSkill>,
    @InjectRepository(Institution)
    private readonly institutionsRepository: Repository<Institution>,
  ) {}

  async getMyProfile(user: AuthenticatedUser) {
    const student = await this.findByUserId(user.id);

    if (!student) {
      throw new NotFoundException(
        'Student profile has not been completed yet.',
      );
    }

    return this.toProfileResponse(student);
  }

  async upsertMyProfile(user: AuthenticatedUser, dto: UpsertMyProfileDto) {
    const targetCareerRole = dto.targetCareerRoleId
      ? await this.findCareerRole(dto.targetCareerRoleId)
      : undefined;
    const existingStudent = await this.findByUserId(user.id);
    const institutionRecord = dto.institutionId
      ? await this.institutionsRepository.findOne({
          where: { id: dto.institutionId },
        })
      : undefined;
    if (dto.institutionId && !institutionRecord)
      throw new NotFoundException('Institution was not found.');

    const student = await this.studentsRepository.save(
      this.studentsRepository.create({
        ...existingStudent,
        firstName: dto.firstName,
        lastName: dto.lastName,
        institution: dto.institution,
        institutionRecord:
          institutionRecord ?? existingStudent?.institutionRecord,
        department: dto.department,
        graduationYear: dto.graduationYear,
        targetCareerRole: targetCareerRole ?? existingStudent?.targetCareerRole,
        user: { id: user.id },
      }),
    );

    return this.toProfileResponse(
      await this.studentsRepository.findOneOrFail({
        where: { id: student.id },
        relations: { targetCareerRole: true, institutionRecord: true },
      }),
    );
  }

  async listMySkills(user: AuthenticatedUser) {
    const student = await this.getStudentOrThrow(user.id);
    const studentSkills = await this.studentSkillsRepository.find({
      where: { student: { id: student.id } },
      relations: { skill: { category: true } },
      order: { skill: { name: 'ASC' } },
    });

    return studentSkills.map((studentSkill) =>
      this.toSkillResponse(studentSkill),
    );
  }

  async upsertMySkill(
    user: AuthenticatedUser,
    skillId: string,
    dto: UpsertMySkillDto,
  ) {
    const student = await this.getStudentOrThrow(user.id);
    const skill = await this.skillsRepository.findOne({
      where: { id: skillId },
    });

    if (!skill) {
      throw new NotFoundException('Skill was not found.');
    }

    const existingStudentSkill = await this.studentSkillsRepository.findOne({
      where: { student: { id: student.id }, skill: { id: skill.id } },
    });
    const studentSkill = await this.studentSkillsRepository.save(
      this.studentSkillsRepository.create({
        ...existingStudentSkill,
        student,
        skill,
        proficiencyLevel: dto.proficiencyLevel,
        source:
          existingStudentSkill?.source ?? SkillEvidenceSource.SELF_DECLARED,
        isVerified: existingStudentSkill?.isVerified ?? false,
      }),
    );

    return this.toSkillResponse(
      await this.studentSkillsRepository.findOneOrFail({
        where: { id: studentSkill.id },
        relations: { skill: { category: true } },
      }),
    );
  }

  async removeMySkill(user: AuthenticatedUser, skillId: string) {
    const student = await this.getStudentOrThrow(user.id);
    const result = await this.studentSkillsRepository
      .createQueryBuilder()
      .delete()
      .where('"studentId" = :studentId AND "skillId" = :skillId', {
        studentId: student.id,
        skillId,
      })
      .execute();

    if (!result.affected) {
      throw new NotFoundException('This skill is not in the student profile.');
    }
  }

  async saveResume(user: AuthenticatedUser, file: Express.Multer.File) {
    const student = await this.getStudentOrThrow(user.id);
    student.resumePath = file.path;
    student.resumeOriginalName = file.originalname;
    student.resumeUploadedAt = new Date();
    await this.studentsRepository.save(student);
    return this.resumeMetadata(student);
  }

  async getResume(user: AuthenticatedUser) {
    const student = await this.getStudentOrThrow(user.id);
    if (!student.resumePath || !student.resumeOriginalName) {
      throw new NotFoundException('No resume has been uploaded.');
    }
    return this.resumeMetadata(student);
  }

  private findByUserId(userId: string) {
    return this.studentsRepository.findOne({
      where: { user: { id: userId } },
      relations: { targetCareerRole: true, institutionRecord: true },
    });
  }

  private async getStudentOrThrow(userId: string) {
    const student = await this.findByUserId(userId);

    if (!student) {
      throw new NotFoundException(
        'Student profile has not been completed yet.',
      );
    }

    return student;
  }

  private async findCareerRole(careerRoleId: string) {
    const careerRole = await this.careerRolesRepository.findOne({
      where: { id: careerRoleId },
    });

    if (!careerRole) {
      throw new NotFoundException('Target career role was not found.');
    }

    return careerRole;
  }

  private toProfileResponse(student: Student) {
    return {
      id: student.id,
      firstName: student.firstName,
      lastName: student.lastName,
      institution: student.institution,
      institutionRecord: student.institutionRecord
        ? {
            id: student.institutionRecord.id,
            name: student.institutionRecord.name,
            code: student.institutionRecord.code,
          }
        : null,
      department: student.department,
      graduationYear: student.graduationYear,
      readinessScore: Number(student.readinessScore),
      targetCareerRole: student.targetCareerRole
        ? {
            id: student.targetCareerRole.id,
            name: student.targetCareerRole.name,
            slug: student.targetCareerRole.slug,
          }
        : null,
    };
  }

  private toSkillResponse(studentSkill: StudentSkill) {
    return {
      id: studentSkill.id,
      proficiencyLevel: studentSkill.proficiencyLevel,
      source: studentSkill.source,
      isVerified: studentSkill.isVerified,
      skill: {
        id: studentSkill.skill.id,
        name: studentSkill.skill.name,
        slug: studentSkill.skill.slug,
        category: {
          id: studentSkill.skill.category.id,
          name: studentSkill.skill.category.name,
        },
      },
    };
  }

  private resumeMetadata(student: Student) {
    return {
      fileName: student.resumeOriginalName,
      uploadedAt: student.resumeUploadedAt,
      available: Boolean(student.resumePath),
    };
  }
}
