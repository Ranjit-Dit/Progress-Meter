import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, In, Repository } from 'typeorm';
import { AuthenticatedUser } from '../auth/auth.types';
import { Course } from '../database/entities/course.entity';
import { CourseSkill } from '../database/entities/course-skill.entity';
import { Skill } from '../database/entities/skill.entity';
import { SkillGapService } from '../skill-gap/skill-gap.service';
import { CreateCourseDto } from './dto/create-course.dto';

@Injectable()
export class LearningService {
  constructor(
    private readonly dataSource: DataSource,
    private readonly skillGapService: SkillGapService,
    @InjectRepository(Course)
    private readonly coursesRepository: Repository<Course>,
  ) {}

  async listCourses() {
    const courses = await this.coursesRepository.find({
      where: { isActive: true },
      relations: { skillMappings: { skill: true } },
      order: { title: 'ASC' },
    });
    return courses.map((course) => this.toCourseResponse(course));
  }

  async createCourse(dto: CreateCourseDto) {
    const skillIds = dto.skillMappings.map((mapping) => mapping.skillId);
    if (new Set(skillIds).size !== skillIds.length) {
      throw new BadRequestException(
        'A skill can appear only once in a course.',
      );
    }
    const existing = await this.coursesRepository.findOne({
      where: { title: dto.title.trim() },
    });
    if (existing) {
      throw new ConflictException('A course with this title already exists.');
    }

    const courseId = await this.dataSource.transaction(async (manager) => {
      const skills = await manager.findBy(Skill, { id: In(skillIds) });
      if (skills.length !== skillIds.length) {
        throw new NotFoundException('One or more skills were not found.');
      }
      const course = await manager.save(
        Course,
        manager.create(Course, {
          title: dto.title.trim(),
          provider: dto.provider.trim(),
          description: dto.description?.trim(),
          url: dto.url,
          estimatedHours: dto.estimatedHours,
        }),
      );
      await manager.save(
        CourseSkill,
        dto.skillMappings.map((mapping) =>
          manager.create(CourseSkill, {
            course,
            skill: skills.find((skill) => skill.id === mapping.skillId),
            priority: mapping.priority,
          }),
        ),
      );
      return course.id;
    });
    return this.getCourseOrThrow(courseId);
  }

  async getRecommendations(user: AuthenticatedUser) {
    const gapAnalysis = await this.skillGapService.analyzeMySkillGap(user);
    const gaps = gapAnalysis.gaps.filter((gap) => gap.status !== 'met');
    const gapBySkillId = new Map(gaps.map((gap) => [gap.skill.id, gap]));
    const courses = await this.coursesRepository.find({
      where: { isActive: true },
      relations: { skillMappings: { skill: true } },
    });
    const recommendations = courses
      .map((course) => {
        const supportedGaps = course.skillMappings
          .map((mapping) => ({
            mapping,
            gap: gapBySkillId.get(mapping.skill.id),
          }))
          .filter(
            (item): item is typeof item & { gap: (typeof gaps)[number] } =>
              Boolean(item.gap),
          );
        const score = supportedGaps.reduce(
          (sum, item) =>
            sum + item.gap.priority * item.gap.gap * item.mapping.priority,
          0,
        );
        return {
          ...this.toCourseResponse(course),
          recommendationScore: score,
          addresses: supportedGaps.map((item) => ({
            skill: item.mapping.skill.name,
            gap: item.gap.gap,
            priority: item.gap.priority,
          })),
        };
      })
      .filter((course) => course.recommendationScore > 0)
      .sort((a, b) => b.recommendationScore - a.recommendationScore);

    return {
      careerRole: gapAnalysis.careerRole,
      readinessScore: gapAnalysis.readinessScore,
      recommendations,
    };
  }

  private async getCourseOrThrow(id: string) {
    const course = await this.coursesRepository.findOne({
      where: { id },
      relations: { skillMappings: { skill: true } },
    });
    if (!course) throw new NotFoundException('Course was not found.');
    return this.toCourseResponse(course);
  }

  private toCourseResponse(course: Course) {
    return {
      id: course.id,
      title: course.title,
      provider: course.provider,
      description: course.description,
      url: course.url,
      estimatedHours: course.estimatedHours,
      skillMappings: course.skillMappings.map((mapping) => ({
        skill: {
          id: mapping.skill.id,
          name: mapping.skill.name,
          slug: mapping.skill.slug,
        },
        priority: mapping.priority,
      })),
    };
  }
}
