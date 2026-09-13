import 'dotenv/config';
import { DataSource } from 'typeorm';
import { Application } from './entities/application.entity';
import { AssessmentAnswer } from './entities/assessment-answer.entity';
import { AssessmentAttempt } from './entities/assessment-attempt.entity';
import { AssessmentQuestion } from './entities/assessment-question.entity';
import { Course } from './entities/course.entity';
import { CourseSkill } from './entities/course-skill.entity';
import { CareerRole } from './entities/career-role.entity';
import { CareerRoleSkill } from './entities/career-role-skill.entity';
import { Opportunity } from './entities/opportunity.entity';
import { OpportunitySkill } from './entities/opportunity-skill.entity';
import { SkillCategory } from './entities/skill-category.entity';
import { Skill } from './entities/skill.entity';
import { StudentSkill } from './entities/student-skill.entity';
import { Student } from './entities/student.entity';
import { StudentAchievement } from './entities/student-achievement.entity';
import { StudentCertification } from './entities/student-certification.entity';
import { StudentProject } from './entities/student-project.entity';
import { Notification } from './entities/notification.entity';
import { AuditLog } from './entities/audit-log.entity';
import { Institution } from './entities/institution.entity';
import { InstitutionAdmin } from './entities/institution-admin.entity';
import { Academician } from './entities/academician.entity';
import { Interview } from './entities/interview.entity';
import { User } from './entities/user.entity';

export default new DataSource({
  type: 'postgres',
  host: process.env.DB_HOST ?? 'localhost',
  port: Number(process.env.DB_PORT ?? 5432),
  username: process.env.DB_USERNAME ?? 'progress',
  password: process.env.DB_PASSWORD ?? 'progress',
  database: process.env.DB_DATABASE ?? 'progress_meter',
  entities: [
    User,
    Student,
    SkillCategory,
    Skill,
    CareerRole,
    CareerRoleSkill,
    StudentSkill,
    Opportunity,
    OpportunitySkill,
    Application,
    Course,
    CourseSkill,
    AssessmentQuestion,
    AssessmentAttempt,
    AssessmentAnswer,
    StudentProject,
    StudentCertification,
    StudentAchievement,
    Notification,
    AuditLog,
    Institution,
    InstitutionAdmin,
    Academician,
    Interview,
  ],
  migrations: [`${__dirname}/migrations/*{.ts,.js}`],
  synchronize: false,
});
