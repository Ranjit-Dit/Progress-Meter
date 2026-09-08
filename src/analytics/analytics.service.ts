import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AuthenticatedUser } from '../auth/auth.types';
import { Application } from '../database/entities/application.entity';
import { Opportunity } from '../database/entities/opportunity.entity';
import { StudentSkill } from '../database/entities/student-skill.entity';
import { Student } from '../database/entities/student.entity';

@Injectable()
export class AnalyticsService {
  constructor(
    @InjectRepository(Student) private readonly students: Repository<Student>,
    @InjectRepository(StudentSkill)
    private readonly studentSkills: Repository<StudentSkill>,
    @InjectRepository(Application)
    private readonly applications: Repository<Application>,
    @InjectRepository(Opportunity)
    private readonly opportunities: Repository<Opportunity>,
  ) {}

  async studentDashboard(user: AuthenticatedUser) {
    const student = await this.students.findOne({
      where: { user: { id: user.id } },
      relations: { targetCareerRole: true },
    });
    if (!student)
      throw new NotFoundException(
        'Student profile has not been completed yet.',
      );
    const [skills, applications] = await Promise.all([
      this.studentSkills.find({ where: { student: { id: student.id } } }),
      this.applications.find({ where: { student: { id: student.id } } }),
    ]);
    const applicationCounts = this.countBy(
      applications,
      (application) => application.status,
    );
    return {
      readinessScore: Number(student.readinessScore),
      targetCareerRole: student.targetCareerRole?.name ?? null,
      skills: {
        total: skills.length,
        verified: skills.filter((skill) => skill.isVerified).length,
        averageProficiency: skills.length
          ? Number(
              (
                skills.reduce((sum, skill) => sum + skill.proficiencyLevel, 0) /
                skills.length
              ).toFixed(2),
            )
          : 0,
      },
      applications: { total: applications.length, byStatus: applicationCounts },
    };
  }

  async industryDashboard(user: AuthenticatedUser) {
    const opportunities = await this.opportunities.find({
      where: { createdBy: { id: user.id } },
    });
    const opportunityIds = opportunities.map((opportunity) => opportunity.id);
    const applications = opportunityIds.length
      ? await this.applications
          .createQueryBuilder('application')
          .where('application."opportunityId" IN (:...opportunityIds)', {
            opportunityIds,
          })
          .getMany()
      : [];
    return {
      opportunities: {
        total: opportunities.length,
        byStatus: this.countBy(
          opportunities,
          (opportunity) => opportunity.status,
        ),
      },
      applications: {
        total: applications.length,
        byStatus: this.countBy(
          applications,
          (application) => application.status,
        ),
        averageCompatibilityScore: applications.length
          ? Number(
              (
                applications.reduce(
                  (sum, application) =>
                    sum + Number(application.compatibilityScore ?? 0),
                  0,
                ) / applications.length
              ).toFixed(2),
            )
          : 0,
      },
    };
  }

  private countBy<T>(items: T[], selector: (item: T) => string) {
    return items.reduce<Record<string, number>>((counts, item) => {
      const key = selector(item);
      counts[key] = (counts[key] ?? 0) + 1;
      return counts;
    }, {});
  }
}
