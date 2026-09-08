import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { DataSource, In, Repository } from 'typeorm';
import { InjectRepository } from '@nestjs/typeorm';
import { CareerRole } from '../database/entities/career-role.entity';
import { CareerRoleSkill } from '../database/entities/career-role-skill.entity';
import { SkillCategory } from '../database/entities/skill-category.entity';
import { Skill } from '../database/entities/skill.entity';
import { CreateCareerRoleDto } from './dto/create-career-role.dto';
import { CreateSkillCategoryDto } from './dto/create-skill-category.dto';
import { CreateSkillDto } from './dto/create-skill.dto';
import { ReplaceCareerRoleRequirementsDto } from './dto/replace-career-role-requirements.dto';

@Injectable()
export class SkillsService {
  constructor(
    private readonly dataSource: DataSource,
    @InjectRepository(SkillCategory)
    private readonly skillCategoriesRepository: Repository<SkillCategory>,
    @InjectRepository(Skill)
    private readonly skillsRepository: Repository<Skill>,
    @InjectRepository(CareerRole)
    private readonly careerRolesRepository: Repository<CareerRole>,
  ) {}

  listCategories() {
    return this.skillCategoriesRepository.find({ order: { name: 'ASC' } });
  }

  listSkills() {
    return this.skillsRepository.find({
      relations: { category: true },
      order: { name: 'ASC' },
    });
  }

  listCareerRoles() {
    return this.careerRolesRepository.find({ order: { name: 'ASC' } });
  }

  async getCareerRole(id: string) {
    const careerRole = await this.careerRolesRepository.findOne({
      where: { id },
      relations: { skillRequirements: { skill: { category: true } } },
    });

    if (!careerRole) {
      throw new NotFoundException('Career role was not found.');
    }

    return careerRole;
  }

  async createCategory(dto: CreateSkillCategoryDto) {
    const name = dto.name.trim();
    const existingCategory = await this.skillCategoriesRepository.findOne({
      where: { name },
    });

    if (existingCategory) {
      throw new ConflictException(
        'A skill category with this name already exists.',
      );
    }

    return this.skillCategoriesRepository.save(
      this.skillCategoriesRepository.create({
        name,
        description: dto.description?.trim(),
      }),
    );
  }

  async createSkill(dto: CreateSkillDto) {
    const category = await this.skillCategoriesRepository.findOne({
      where: { id: dto.categoryId },
    });

    if (!category) {
      throw new NotFoundException('Skill category was not found.');
    }

    const name = dto.name.trim();
    const slug = dto.slug.trim().toLowerCase();
    const existingSkill = await this.skillsRepository.findOne({
      where: [{ name }, { slug }],
    });

    if (existingSkill) {
      throw new ConflictException(
        'A skill with this name or slug already exists.',
      );
    }

    return this.skillsRepository.save(
      this.skillsRepository.create({
        name,
        slug,
        description: dto.description?.trim(),
        category,
      }),
    );
  }

  async createCareerRole(dto: CreateCareerRoleDto) {
    const name = dto.name.trim();
    const slug = dto.slug.trim().toLowerCase();
    const existingRole = await this.careerRolesRepository.findOne({
      where: [{ name }, { slug }],
    });

    if (existingRole) {
      throw new ConflictException(
        'A career role with this name or slug already exists.',
      );
    }

    return this.careerRolesRepository.save(
      this.careerRolesRepository.create({
        name,
        slug,
        description: dto.description?.trim(),
      }),
    );
  }

  async replaceCareerRoleRequirements(
    careerRoleId: string,
    dto: ReplaceCareerRoleRequirementsDto,
  ) {
    const skillIds = dto.requirements.map((requirement) => requirement.skillId);

    if (new Set(skillIds).size !== skillIds.length) {
      throw new BadRequestException(
        'A skill can appear only once in a career role.',
      );
    }

    await this.dataSource.transaction(async (manager) => {
      const careerRole = await manager.findOneBy(CareerRole, {
        id: careerRoleId,
      });
      if (!careerRole) {
        throw new NotFoundException('Career role was not found.');
      }

      const skills = await manager.findBy(Skill, { id: In(skillIds) });
      if (skills.length !== skillIds.length) {
        throw new NotFoundException('One or more skills were not found.');
      }

      await manager
        .createQueryBuilder()
        .delete()
        .from(CareerRoleSkill)
        .where('"careerRoleId" = :careerRoleId', { careerRoleId })
        .execute();

      await manager.save(
        CareerRoleSkill,
        dto.requirements.map((requirement) =>
          manager.create(CareerRoleSkill, {
            careerRole,
            skill: skills.find((skill) => skill.id === requirement.skillId),
            requiredLevel: requirement.requiredLevel,
            priority: requirement.priority,
            weight: requirement.weight,
          }),
        ),
      );
    });

    return this.getCareerRole(careerRoleId);
  }
}
