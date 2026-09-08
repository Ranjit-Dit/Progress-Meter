import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AuthenticatedUser } from '../auth/auth.types';
import { CareerRoleSkill } from '../database/entities/career-role-skill.entity';
import { StudentSkill } from '../database/entities/student-skill.entity';
import { Student } from '../database/entities/student.entity';

@Injectable()
export class SkillGapService {
  constructor(
    @InjectRepository(Student)
    private readonly studentsRepository: Repository<Student>,
    @InjectRepository(CareerRoleSkill)
    private readonly careerRoleSkillsRepository: Repository<CareerRoleSkill>,
    @InjectRepository(StudentSkill)
    private readonly studentSkillsRepository: Repository<StudentSkill>,
  ) {}

  async analyzeMySkillGap(user: AuthenticatedUser) {
    const student = await this.studentsRepository.findOne({
      where: { user: { id: user.id } },
      relations: { targetCareerRole: true },
    });

    if (!student) {
      throw new NotFoundException(
        'Student profile has not been completed yet.',
      );
    }

    if (!student.targetCareerRole) {
      throw new BadRequestException(
        'Select a target career role before analyzing a skill gap.',
      );
    }

    const requirements = await this.careerRoleSkillsRepository.find({
      where: { careerRole: { id: student.targetCareerRole.id } },
      relations: { skill: { category: true } },
      order: { priority: 'DESC', weight: 'DESC' },
    });

    if (!requirements.length) {
      throw new BadRequestException(
        'The selected career role has no skill requirements yet.',
      );
    }

    const studentSkills = await this.studentSkillsRepository.find({
      where: { student: { id: student.id } },
      relations: { skill: true },
    });
    const skillLevelById = new Map(
      studentSkills.map((studentSkill) => [
        studentSkill.skill.id,
        studentSkill.proficiencyLevel,
      ]),
    );

    const totalWeight = requirements.reduce(
      (sum, requirement) => sum + Number(requirement.weight),
      0,
    );
    const completedWeight = requirements.reduce((sum, requirement) => {
      const studentLevel = skillLevelById.get(requirement.skill.id) ?? 0;
      const completionRatio = Math.min(
        studentLevel / requirement.requiredLevel,
        1,
      );
      return sum + Number(requirement.weight) * completionRatio;
    }, 0);
    const readinessScore = Number(
      ((completedWeight / totalWeight) * 100).toFixed(2),
    );

    student.readinessScore = readinessScore;
    await this.studentsRepository.save(student);

    const gaps = requirements.map((requirement) => {
      const currentLevel = skillLevelById.get(requirement.skill.id) ?? 0;
      const gap = Math.max(requirement.requiredLevel - currentLevel, 0);

      return {
        skill: {
          id: requirement.skill.id,
          name: requirement.skill.name,
          slug: requirement.skill.slug,
          category: requirement.skill.category.name,
        },
        currentLevel,
        requiredLevel: requirement.requiredLevel,
        gap,
        priority: requirement.priority,
        weight: Number(requirement.weight),
        status: gap === 0 ? 'met' : currentLevel === 0 ? 'missing' : 'partial',
      };
    });

    return {
      careerRole: {
        id: student.targetCareerRole.id,
        name: student.targetCareerRole.name,
        slug: student.targetCareerRole.slug,
      },
      readinessScore,
      summary: {
        requiredSkills: requirements.length,
        metSkills: gaps.filter((gap) => gap.status === 'met').length,
        partialSkills: gaps.filter((gap) => gap.status === 'partial').length,
        missingSkills: gaps.filter((gap) => gap.status === 'missing').length,
      },
      gaps,
    };
  }
}
