import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AuthenticatedUser } from '../auth/auth.types';
import { Application } from '../database/entities/application.entity';
import { ApplicationStatus } from '../database/entities/enums';
import { Interview } from '../database/entities/interview.entity';
import { NotificationsService } from '../notifications/notifications.service';
import { CreateInterviewDto } from './dto/create-interview.dto';
@Injectable()
export class InterviewsService {
  constructor(
    @InjectRepository(Interview)
    private readonly interviews: Repository<Interview>,
    @InjectRepository(Application)
    private readonly applications: Repository<Application>,
    private readonly notifications: NotificationsService,
  ) {}
  async create(
    user: AuthenticatedUser,
    applicationId: string,
    dto: CreateInterviewDto,
  ) {
    const application = await this.applications.findOne({
      where: { id: applicationId },
      relations: { opportunity: { createdBy: true }, student: { user: true } },
    });
    if (!application) throw new NotFoundException('Application was not found.');
    if (application.opportunity.createdBy.id !== user.id)
      throw new ForbiddenException(
        'You cannot schedule an interview for this application.',
      );
    const interview = await this.interviews.save(
      this.interviews.create({
        application,
        scheduledAt: new Date(dto.scheduledAt),
        mode: dto.mode?.trim(),
        meetingUrl: dto.meetingUrl,
        notes: dto.notes?.trim(),
      }),
    );
    application.status = ApplicationStatus.INTERVIEW;
    await this.applications.save(application);
    await this.notifications.create(
      application.student.user.id,
      'Interview scheduled',
      `An interview for ${application.opportunity.title} has been scheduled.`,
    );
    return interview;
  }
  async listMine(user: AuthenticatedUser) {
    return this.interviews.find({
      where: { application: { student: { user: { id: user.id } } } },
      relations: { application: { opportunity: true } },
      order: { scheduledAt: 'ASC' },
    });
  }
}
