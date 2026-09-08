import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, EntityManager, In, Repository } from 'typeorm';
import { AuthenticatedUser } from '../auth/auth.types';
import { OpportunityStatus } from '../database/entities/enums';
import { Opportunity } from '../database/entities/opportunity.entity';
import { OpportunitySkill } from '../database/entities/opportunity-skill.entity';
import { Skill } from '../database/entities/skill.entity';
import { CreateOpportunityDto } from './dto/create-opportunity.dto';
import { SkillRequirementDto } from './dto/skill-requirement.dto';
import { UpdateOpportunityDto } from './dto/update-opportunity.dto';
import { ListOpportunitiesDto } from './dto/list-opportunities.dto';

@Injectable()
export class OpportunitiesService {
  constructor(
    private readonly dataSource: DataSource,
    @InjectRepository(Opportunity)
    private readonly opportunitiesRepository: Repository<Opportunity>,
  ) {}

  async listPublished(query: ListOpportunitiesDto) {
    const page = query.page ?? 1;
    const limit = query.limit ?? 20;
    const builder = this.opportunitiesRepository
      .createQueryBuilder('opportunity')
      .leftJoinAndSelect('opportunity.skillRequirements', 'requirement')
      .leftJoinAndSelect('requirement.skill', 'skill')
      .where('opportunity.status = :status', {
        status: OpportunityStatus.PUBLISHED,
      })
      .orderBy('opportunity.createdAt', 'DESC')
      .skip((page - 1) * limit)
      .take(limit);
    if (query.type)
      builder.andWhere('opportunity.type = :type', { type: query.type });
    if (query.location)
      builder.andWhere('LOWER(opportunity.location) LIKE LOWER(:location)', {
        location: `%${query.location.trim()}%`,
      });
    if (query.search)
      builder.andWhere(
        '(LOWER(opportunity.title) LIKE LOWER(:search) OR LOWER(opportunity.companyName) LIKE LOWER(:search))',
        { search: `%${query.search.trim()}%` },
      );
    const [opportunities, total] = await builder.getManyAndCount();
    return {
      data: opportunities.map((opportunity) => this.toResponse(opportunity)),
      meta: { page, limit, total, totalPages: Math.ceil(total / limit) },
    };
  }

  async getPublished(id: string) {
    const opportunity = await this.opportunitiesRepository.findOne({
      where: { id, status: OpportunityStatus.PUBLISHED },
      relations: { skillRequirements: { skill: true } },
    });

    if (!opportunity) {
      throw new NotFoundException('Published opportunity was not found.');
    }

    return this.toResponse(opportunity);
  }

  async listMine(user: AuthenticatedUser) {
    const opportunities = await this.opportunitiesRepository.find({
      where: { createdBy: { id: user.id } },
      relations: { skillRequirements: { skill: true } },
      order: { createdAt: 'DESC' },
    });

    return opportunities.map((opportunity) => this.toResponse(opportunity));
  }

  async create(user: AuthenticatedUser, dto: CreateOpportunityDto) {
    const opportunityId = await this.dataSource.transaction(async (manager) => {
      const opportunity = await manager.save(
        Opportunity,
        manager.create(Opportunity, {
          createdBy: { id: user.id },
          title: dto.title.trim(),
          type: dto.type,
          companyName: dto.companyName.trim(),
          description: dto.description.trim(),
          location: dto.location?.trim(),
          isRemote: dto.isRemote ?? false,
          eligibilityCriteria: dto.eligibilityCriteria,
          deadline: dto.deadline ? new Date(dto.deadline) : undefined,
          status: dto.status ?? OpportunityStatus.DRAFT,
        }),
      );

      await this.replaceRequirements(
        manager,
        opportunity,
        dto.skillRequirements,
      );
      return opportunity.id;
    });

    return this.getMineById(user, opportunityId);
  }

  async update(user: AuthenticatedUser, id: string, dto: UpdateOpportunityDto) {
    const opportunity = await this.findOwnedOpportunity(user, id);

    await this.dataSource.transaction(async (manager) => {
      manager.merge(Opportunity, opportunity, {
        title: dto.title?.trim(),
        type: dto.type,
        companyName: dto.companyName?.trim(),
        description: dto.description?.trim(),
        location: dto.location?.trim(),
        isRemote: dto.isRemote,
        eligibilityCriteria: dto.eligibilityCriteria,
        deadline: dto.deadline ? new Date(dto.deadline) : undefined,
        status: dto.status,
      });
      await manager.save(opportunity);

      if (dto.skillRequirements) {
        await this.replaceRequirements(
          manager,
          opportunity,
          dto.skillRequirements,
        );
      }
    });

    return this.getMineById(user, opportunity.id);
  }

  async getMineById(user: AuthenticatedUser, id: string) {
    const opportunity = await this.opportunitiesRepository.findOne({
      where: { id, createdBy: { id: user.id } },
      relations: { skillRequirements: { skill: true } },
    });

    if (!opportunity) {
      throw new NotFoundException('Opportunity was not found.');
    }

    return this.toResponse(opportunity);
  }

  private async findOwnedOpportunity(user: AuthenticatedUser, id: string) {
    const opportunity = await this.opportunitiesRepository.findOne({
      where: { id },
      relations: { createdBy: true },
    });

    if (!opportunity) {
      throw new NotFoundException('Opportunity was not found.');
    }

    if (opportunity.createdBy.id !== user.id) {
      throw new ForbiddenException(
        'You cannot manage an opportunity created by another industry user.',
      );
    }

    return opportunity;
  }

  private async replaceRequirements(
    manager: EntityManager,
    opportunity: Opportunity,
    requirements: SkillRequirementDto[],
  ) {
    const skillIds = requirements.map((requirement) => requirement.skillId);
    if (new Set(skillIds).size !== skillIds.length) {
      throw new NotFoundException(
        'A skill can appear only once in an opportunity.',
      );
    }

    const skills = await manager.findBy(Skill, { id: In(skillIds) });
    if (skills.length !== skillIds.length) {
      throw new NotFoundException('One or more skills were not found.');
    }

    await manager.delete(OpportunitySkill, {
      opportunity: { id: opportunity.id },
    });
    await manager.save(
      OpportunitySkill,
      requirements.map((requirement) =>
        manager.create(OpportunitySkill, {
          opportunity,
          skill: skills.find((skill) => skill.id === requirement.skillId),
          minimumLevel: requirement.minimumLevel,
          isRequired: requirement.isRequired,
          priority: requirement.priority,
        }),
      ),
    );
  }

  private toResponse(opportunity: Opportunity) {
    return {
      id: opportunity.id,
      title: opportunity.title,
      type: opportunity.type,
      companyName: opportunity.companyName,
      description: opportunity.description,
      location: opportunity.location,
      isRemote: opportunity.isRemote,
      eligibilityCriteria: opportunity.eligibilityCriteria,
      status: opportunity.status,
      deadline: opportunity.deadline,
      createdAt: opportunity.createdAt,
      updatedAt: opportunity.updatedAt,
      skillRequirements: opportunity.skillRequirements.map((requirement) => ({
        skill: {
          id: requirement.skill.id,
          name: requirement.skill.name,
          slug: requirement.skill.slug,
        },
        minimumLevel: requirement.minimumLevel,
        isRequired: requirement.isRequired,
        priority: requirement.priority,
      })),
    };
  }
}
