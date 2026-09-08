import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { randomUUID } from 'crypto';
import { AuthenticatedUser } from '../auth/auth.types';
import { StudentAchievement } from '../database/entities/student-achievement.entity';
import { StudentCertification } from '../database/entities/student-certification.entity';
import { StudentProject } from '../database/entities/student-project.entity';
import { Student } from '../database/entities/student.entity';

@Injectable()
export class PortfolioService {
  constructor(
    @InjectRepository(Student) private readonly students: Repository<Student>,
    @InjectRepository(StudentProject)
    private readonly projects: Repository<StudentProject>,
    @InjectRepository(StudentCertification)
    private readonly certifications: Repository<StudentCertification>,
    @InjectRepository(StudentAchievement)
    private readonly achievements: Repository<StudentAchievement>,
  ) {}

  async getMine(user: AuthenticatedUser) {
    const student = await this.student(user.id);
    const [projects, certifications, achievements] = await Promise.all([
      this.projects.find({ where: { student: { id: student.id } } }),
      this.certifications.find({ where: { student: { id: student.id } } }),
      this.achievements.find({ where: { student: { id: student.id } } }),
    ]);
    return {
      student: {
        id: student.id,
        firstName: student.firstName,
        lastName: student.lastName,
        readinessScore: Number(student.readinessScore),
      },
      projects,
      certifications,
      achievements,
    };
  }

  async setVisibility(user: AuthenticatedUser, isPublic: boolean) {
    const student = await this.student(user.id);
    if (isPublic && !student.portfolioSlug)
      student.portfolioSlug = randomUUID();
    student.isPortfolioPublic = isPublic;
    await this.students.save(student);
    return {
      isPublic: student.isPortfolioPublic,
      portfolioSlug: student.portfolioSlug,
      publicPath: student.isPortfolioPublic
        ? `/portfolios/${student.portfolioSlug}`
        : null,
    };
  }

  async getPublic(slug: string) {
    const student = await this.students.findOne({
      where: { portfolioSlug: slug, isPortfolioPublic: true },
      relations: { targetCareerRole: true, skills: { skill: true } },
    });
    if (!student)
      throw new NotFoundException('Public portfolio was not found.');
    const [projects, certifications, achievements] = await Promise.all([
      this.projects.find({ where: { student: { id: student.id } } }),
      this.certifications.find({ where: { student: { id: student.id } } }),
      this.achievements.find({ where: { student: { id: student.id } } }),
    ]);
    return {
      name: `${student.firstName} ${student.lastName}`,
      institution: student.institution,
      department: student.department,
      graduationYear: student.graduationYear,
      readinessScore: Number(student.readinessScore),
      targetCareerRole: student.targetCareerRole?.name ?? null,
      skills: student.skills.map((item) => ({
        name: item.skill.name,
        proficiencyLevel: item.proficiencyLevel,
        verified: item.isVerified,
      })),
      projects,
      certifications,
      achievements,
    };
  }

  async addProject(
    user: AuthenticatedUser,
    input: { title: string; description: string; projectUrl?: string },
  ) {
    const student = await this.student(user.id);
    return this.projects.save(
      this.projects.create({
        student,
        title: input.title.trim(),
        description: input.description.trim(),
        projectUrl: input.projectUrl,
      }),
    );
  }

  async addCertification(
    user: AuthenticatedUser,
    input: {
      name: string;
      issuer: string;
      credentialUrl?: string;
      issuedOn?: string;
    },
  ) {
    const student = await this.student(user.id);
    return this.certifications.save(
      this.certifications.create({
        student,
        name: input.name.trim(),
        issuer: input.issuer.trim(),
        credentialUrl: input.credentialUrl,
        issuedOn: input.issuedOn,
      }),
    );
  }

  async addAchievement(
    user: AuthenticatedUser,
    input: { title: string; description?: string; achievementUrl?: string },
  ) {
    const student = await this.student(user.id);
    return this.achievements.save(
      this.achievements.create({
        student,
        title: input.title.trim(),
        description: input.description?.trim(),
        achievementUrl: input.achievementUrl,
      }),
    );
  }

  async deleteProject(user: AuthenticatedUser, id: string) {
    await this.remove(this.projects, user.id, id, 'Project');
  }

  async deleteCertification(user: AuthenticatedUser, id: string) {
    await this.remove(this.certifications, user.id, id, 'Certification');
  }

  async deleteAchievement(user: AuthenticatedUser, id: string) {
    await this.remove(this.achievements, user.id, id, 'Achievement');
  }

  private async student(userId: string) {
    const student = await this.students.findOne({
      where: { user: { id: userId } },
    });
    if (!student)
      throw new NotFoundException(
        'Student profile has not been completed yet.',
      );
    return student;
  }

  private async remove<T extends { id: string }>(
    repository: Repository<T>,
    userId: string,
    id: string,
    label: string,
  ) {
    const student = await this.student(userId);
    const result = await repository
      .createQueryBuilder()
      .delete()
      .where('id = :id AND "studentId" = :studentId', {
        id,
        studentId: student.id,
      })
      .execute();
    if (!result.affected)
      throw new NotFoundException(`${label} was not found.`);
  }
}
