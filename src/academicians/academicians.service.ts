import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AuthenticatedUser } from '../auth/auth.types';
import { Academician } from '../database/entities/academician.entity';
import { UpsertAcademicianProfileDto } from './dto/upsert-my-profile.dto';
@Injectable()
export class AcademiciansService {
  constructor(
    @InjectRepository(Academician)
    private readonly profiles: Repository<Academician>,
  ) {}
  async getMine(user: AuthenticatedUser) {
    const profile = await this.profiles.findOne({
      where: { user: { id: user.id } },
    });
    if (!profile)
      throw new NotFoundException(
        'Academician profile has not been completed yet.',
      );
    return profile;
  }
  async upsertMine(user: AuthenticatedUser, dto: UpsertAcademicianProfileDto) {
    const existing = await this.profiles.findOne({
      where: { user: { id: user.id } },
    });
    return this.profiles.save(
      this.profiles.create({ ...existing, ...dto, user: { id: user.id } }),
    );
  }
}
