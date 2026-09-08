import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddDigitalPortfolio1757275500000 implements MigrationInterface {
  name = 'AddDigitalPortfolio1757275500000';
  async up(q: QueryRunner): Promise<void> {
    await q.query(
      `CREATE TABLE "student_projects" ("id" uuid PRIMARY KEY DEFAULT uuid_generate_v4(), "studentId" uuid NOT NULL REFERENCES "students"("id") ON DELETE CASCADE, "title" varchar(180) NOT NULL, "description" text NOT NULL, "project_url" text, "is_verified" boolean NOT NULL DEFAULT false)`,
    );
    await q.query(
      `CREATE TABLE "student_certifications" ("id" uuid PRIMARY KEY DEFAULT uuid_generate_v4(), "studentId" uuid NOT NULL REFERENCES "students"("id") ON DELETE CASCADE, "name" varchar(180) NOT NULL, "issuer" varchar(140) NOT NULL, "credential_url" text, "issued_on" date, "is_verified" boolean NOT NULL DEFAULT false)`,
    );
    await q.query(
      `CREATE TABLE "student_achievements" ("id" uuid PRIMARY KEY DEFAULT uuid_generate_v4(), "studentId" uuid NOT NULL REFERENCES "students"("id") ON DELETE CASCADE, "title" varchar(180) NOT NULL, "description" text, "achievement_url" text)`,
    );
  }
  async down(q: QueryRunner): Promise<void> {
    await q.query('DROP TABLE "student_achievements"');
    await q.query('DROP TABLE "student_certifications"');
    await q.query('DROP TABLE "student_projects"');
  }
}
