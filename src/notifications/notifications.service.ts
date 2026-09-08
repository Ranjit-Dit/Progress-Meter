import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AuthenticatedUser } from '../auth/auth.types';
import { Notification } from '../database/entities/notification.entity';

@Injectable()
export class NotificationsService {
  constructor(
    @InjectRepository(Notification)
    private readonly notifications: Repository<Notification>,
  ) {}
  create(userId: string, title: string, message: string) {
    return this.notifications.save(
      this.notifications.create({ user: { id: userId }, title, message }),
    );
  }
  list(user: AuthenticatedUser) {
    return this.notifications.find({
      where: { user: { id: user.id } },
      order: { createdAt: 'DESC' },
    });
  }
  async markRead(user: AuthenticatedUser, id: string) {
    const notification = await this.notifications.findOne({
      where: { id, user: { id: user.id } },
    });
    if (!notification)
      throw new NotFoundException('Notification was not found.');
    notification.isRead = true;
    return this.notifications.save(notification);
  }
}
