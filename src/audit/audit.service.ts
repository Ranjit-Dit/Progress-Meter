import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AuditLog } from '../database/entities/audit-log.entity';
@Injectable()
export class AuditService {
  constructor(
    @InjectRepository(AuditLog) private readonly logs: Repository<AuditLog>,
  ) {}
  record(
    actorId: string | undefined,
    action: string,
    resourceType: string,
    resourceId?: string,
    metadata?: Record<string, unknown>,
  ) {
    return this.logs.save(
      this.logs.create({
        actor: actorId ? { id: actorId } : undefined,
        action,
        resourceType,
        resourceId,
        metadata,
      }),
    );
  }
}
