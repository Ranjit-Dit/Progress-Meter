import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module';
import { Application } from '../database/entities/application.entity';
import { Interview } from '../database/entities/interview.entity';
import { NotificationsModule } from '../notifications/notifications.module';
import { InterviewsController } from './interviews.controller';
import { InterviewsService } from './interviews.service';
@Module({
  imports: [
    AuthModule,
    NotificationsModule,
    TypeOrmModule.forFeature([Interview, Application]),
  ],
  controllers: [InterviewsController],
  providers: [InterviewsService],
})
export class InterviewsModule {}
