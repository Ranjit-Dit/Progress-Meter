import {
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AuthenticatedUser } from '../auth/auth.types';
import { Application } from '../database/entities/application.entity';
import {
  ApplicationStatus,
  OpportunityStatus,
} from '../database/entities/enums';
import { Opportunity } from '../database/entities/opportunity.entity';
import { StudentSkill } from '../database/entities/student-skill.entity';
import { Student } from '../database/entities/student.entity';
import { CreateApplicationDto } from './dto/create-application.dto';
import { UpdateApplicationStatusDto } from './dto/update-application-status.dto';
import { NotificationsService } from '../notifications/notifications.service';
import { AuditService } from '../audit/audit.service';

type OpportunityWithSkills = Opportunity & {
  skillRequirements: NonNullable<Opportunity['skillRequirements']>;
};

@Injectable()
export class ApplicationsService {
  constructor(
    @InjectRepository(Student)
    private readonly studentsRepository: Repository<Student>,
    @InjectRepository(Opportunity)
    private readonly opportunitiesRepository: Repository<Opportunity>,
    @InjectRepository(StudentSkill)
    private readonly studentSkillsRepository: Repository<StudentSkill>,
    @InjectRepository(Application)
    private readonly applicationsRepository: Repository<Application>,
    private readonly notificationsService: NotificationsService,
    private readonly auditService: AuditService,
  ) {}

  async getMatch(user: AuthenticatedUser, opportunityId: string) {
    const student = await this.getStudentOrThrow(user.id);
    const opportunity =
      await this.getPublishedOpportunityOrThrow(opportunityId);
    return this.calculateMatch(student, opportunity);
  }

  async create(
    user: AuthenticatedUser,
    opportunityId: string,
    dto: CreateApplicationDto,
  ) {
    const student = await this.getStudentOrThrow(user.id);
    const opportunity =
      await this.getPublishedOpportunityOrThrow(opportunityId);
    const existingApplication = await this.applicationsRepository.findOne({
      where: {
        student: { id: student.id },
        opportunity: { id: opportunity.id },
      },
    });

    if (existingApplication) {
      throw new ConflictException(
        'You have already applied to this opportunity.',
      );
    }

    const match = await this.calculateMatch(student, opportunity);
    const application = await this.applicationsRepository.save(
      this.applicationsRepository.create({
        student,
        opportunity,
        compatibilityScore: match.compatibilityScore,
        coverNote: dto.coverNote?.trim(),
      }),
    );

    return this.toApplicationResponse(application, match);
  }

  async listMine(user: AuthenticatedUser) {
    const student = await this.getStudentOrThrow(user.id);
    const applications = await this.applicationsRepository.find({
      where: { student: { id: student.id } },
      relations: { opportunity: true },
      order: { appliedAt: 'DESC' },
    });

    return applications.map((application) =>
      this.toApplicationResponse(application),
    );
  }

  async withdraw(user: AuthenticatedUser, applicationId: string) {
    const student = await this.getStudentOrThrow(user.id);
    const application = await this.applicationsRepository.findOne({
      where: { id: applicationId, student: { id: student.id } },
    });

    if (!application) {
      throw new NotFoundException('Application was not found.');
    }
    if (application.status === ApplicationStatus.WITHDRAWN) {
      throw new ConflictException(
        'This application has already been withdrawn.',
      );
    }

    application.status = ApplicationStatus.WITHDRAWN;
    const savedApplication =
      await this.applicationsRepository.save(application);
    return {
      id: savedApplication.id,
      status: savedApplication.status,
      updatedAt: savedApplication.updatedAt,
    };
  }

  async listApplicants(user: AuthenticatedUser, opportunityId: string) {
    await this.getOwnedOpportunityOrThrow(user, opportunityId);
    const applications = await this.applicationsRepository.find({
      where: { opportunity: { id: opportunityId } },
      relations: { student: { user: true } },
      order: { compatibilityScore: 'DESC', appliedAt: 'ASC' },
    });

    return applications.map((application) => ({
      id: application.id,
      status: application.status,
      compatibilityScore: Number(application.compatibilityScore),
      coverNote: application.coverNote,
      appliedAt: application.appliedAt,
      updatedAt: application.updatedAt,
      student: {
        id: application.student.id,
        firstName: application.student.firstName,
        lastName: application.student.lastName,
        institution: application.student.institution,
        department: application.student.department,
        graduationYear: application.student.graduationYear,
        readinessScore: Number(application.student.readinessScore),
        email: application.student.user.email,
      },
    }));
  }

  async updateStatus(
    user: AuthenticatedUser,
    applicationId: string,
    dto: UpdateApplicationStatusDto,
  ) {
    const application = await this.applicationsRepository.findOne({
      where: { id: applicationId },
      relations: { opportunity: { createdBy: true }, student: { user: true } },
    });

    if (!application) {
      throw new NotFoundException('Application was not found.');
    }
    if (application.opportunity.createdBy.id !== user.id) {
      throw new ForbiddenException('You cannot manage this application.');
    }
    if (application.status === ApplicationStatus.WITHDRAWN) {
      throw new ConflictException('A withdrawn application cannot be updated.');
    }
    if (dto.status === ApplicationStatus.WITHDRAWN) {
      throw new ConflictException(
        'Only the student can withdraw an application.',
      );
    }

    const previousStatus = application.status;
    application.status = dto.status;
    const savedApplication =
      await this.applicationsRepository.save(application);
    await this.notificationsService.create(
      application.student.user.id,
      `Application ${dto.status}`,
      `Your application for ${application.opportunity.title} is now ${dto.status}.`,
    );
    await this.auditService.record(
      user.id,
      'application.status_updated',
      'application',
      application.id,
      {
        from: previousStatus,
        to: dto.status,
        opportunityId: application.opportunity.id,
      },
    );
    return {
      id: savedApplication.id,
      status: savedApplication.status,
      updatedAt: savedApplication.updatedAt,
    };
  }

  private async calculateMatch(
    student: Student,
    opportunity: OpportunityWithSkills,
  ) {
    const studentSkills = await this.studentSkillsRepository.find({
      where: { student: { id: student.id } },
      relations: { skill: true },
    });
    const levelBySkillId = new Map(
      studentSkills.map((studentSkill) => [
        studentSkill.skill.id,
        studentSkill.proficiencyLevel,
      ]),
    );
    const requirements = opportunity.skillRequirements;
    const totalWeight = requirements.reduce(
      (sum, requirement) => sum + requirement.priority,
      0,
    );
    const earnedWeight = requirements.reduce((sum, requirement) => {
      const level = levelBySkillId.get(requirement.skill.id) ?? 0;
      const ratio = Math.min(level / requirement.minimumLevel, 1);
      return sum + requirement.priority * ratio;
    }, 0);
    const compatibilityScore = totalWeight
      ? Number(((earnedWeight / totalWeight) * 100).toFixed(2))
      : 100;
    const skillMatches = requirements.map((requirement) => {
      const currentLevel = levelBySkillId.get(requirement.skill.id) ?? 0;
      const gap = Math.max(requirement.minimumLevel - currentLevel, 0);

      return {
        skill: {
          id: requirement.skill.id,
          name: requirement.skill.name,
          slug: requirement.skill.slug,
        },
        currentLevel,
        requiredLevel: requirement.minimumLevel,
        gap,
        priority: requirement.priority,
        isRequired: requirement.isRequired,
        status:
          gap === 0 ? 'matched' : currentLevel === 0 ? 'missing' : 'partial',
      };
    });

    return {
      compatibilityScore,
      summary: {
        totalRequirements: requirements.length,
        matchedSkills: skillMatches.filter(
          (skill) => skill.status === 'matched',
        ).length,
        partialSkills: skillMatches.filter(
          (skill) => skill.status === 'partial',
        ).length,
        missingSkills: skillMatches.filter(
          (skill) => skill.status === 'missing',
        ).length,
      },
      skillMatches,
    };
  }

  private async getStudentOrThrow(userId: string) {
    const student = await this.studentsRepository.findOne({
      where: { user: { id: userId } },
    });
    if (!student) {
      throw new NotFoundException(
        'Student profile has not been completed yet.',
      );
    }
    return student;
  }

  private async getPublishedOpportunityOrThrow(
    id: string,
  ): Promise<OpportunityWithSkills> {
    const opportunity = await this.opportunitiesRepository.findOne({
      where: { id, status: OpportunityStatus.PUBLISHED },
      relations: { skillRequirements: { skill: true } },
    });
    if (!opportunity) {
      throw new NotFoundException('Published opportunity was not found.');
    }
    return opportunity;
  }

  private async getOwnedOpportunityOrThrow(
    user: AuthenticatedUser,
    opportunityId: string,
  ) {
    const opportunity = await this.opportunitiesRepository.findOne({
      where: { id: opportunityId, createdBy: { id: user.id } },
    });
    if (!opportunity) {
      throw new NotFoundException('Opportunity was not found.');
    }
    return opportunity;
  }

  private toApplicationResponse(
    application: Application,
    match?: Awaited<ReturnType<ApplicationsService['calculateMatch']>>,
  ) {
    return {
      id: application.id,
      status: application.status,
      compatibilityScore: Number(application.compatibilityScore),
      coverNote: application.coverNote,
      appliedAt: application.appliedAt,
      updatedAt: application.updatedAt,
      opportunity: application.opportunity
        ? {
            id: application.opportunity.id,
            title: application.opportunity.title,
            companyName: application.opportunity.companyName,
            type: application.opportunity.type,
          }
        : undefined,
      match,
    };
  }
}
