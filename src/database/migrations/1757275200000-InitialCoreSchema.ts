import { MigrationInterface, QueryRunner } from 'typeorm';

export class InitialCoreSchema1757275200000 implements MigrationInterface {
  name = 'InitialCoreSchema1757275200000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query('CREATE EXTENSION IF NOT EXISTS "uuid-ossp"');
    await queryRunner.query(
      `CREATE TYPE "user_role_enum" AS ENUM ('student', 'industry', 'academician', 'institution_admin', 'admin')`,
    );
    await queryRunner.query(
      `CREATE TYPE "skill_evidence_source_enum" AS ENUM ('self_declared', 'assessment', 'project', 'certification', 'industry')`,
    );
    await queryRunner.query(
      `CREATE TYPE "opportunity_type_enum" AS ENUM ('internship', 'job', 'apprenticeship', 'project', 'training')`,
    );
    await queryRunner.query(
      `CREATE TYPE "opportunity_status_enum" AS ENUM ('draft', 'published', 'closed')`,
    );
    await queryRunner.query(
      `CREATE TYPE "application_status_enum" AS ENUM ('submitted', 'shortlisted', 'interview', 'offered', 'rejected', 'withdrawn')`,
    );

    await queryRunner.query(`
      CREATE TABLE "users" (
        "id" uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
        "email" varchar(255) NOT NULL UNIQUE,
        "password_hash" varchar NOT NULL,
        "role" "user_role_enum" NOT NULL,
        "is_email_verified" boolean NOT NULL DEFAULT false,
        "is_active" boolean NOT NULL DEFAULT true,
        "created_at" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
        "updated_at" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    `);
    await queryRunner.query(`
      CREATE TABLE "skill_categories" (
        "id" uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
        "name" varchar(100) NOT NULL UNIQUE,
        "description" text
      )
    `);
    await queryRunner.query(`
      CREATE TABLE "career_roles" (
        "id" uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
        "name" varchar(120) NOT NULL UNIQUE,
        "slug" varchar(140) NOT NULL UNIQUE,
        "description" text
      )
    `);
    await queryRunner.query(`
      CREATE TABLE "skills" (
        "id" uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
        "name" varchar(100) NOT NULL UNIQUE,
        "slug" varchar(120) NOT NULL UNIQUE,
        "description" text,
        "categoryId" uuid NOT NULL REFERENCES "skill_categories"("id")
      )
    `);
    await queryRunner.query(`
      CREATE TABLE "students" (
        "id" uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
        "user_id" uuid NOT NULL UNIQUE REFERENCES "users"("id") ON DELETE CASCADE,
        "first_name" varchar(100) NOT NULL,
        "last_name" varchar(100) NOT NULL,
        "institution" varchar(100),
        "department" varchar(100),
        "graduation_year" smallint,
        "target_career_role_id" uuid REFERENCES "career_roles"("id"),
        "readiness_score" decimal(5,2) NOT NULL DEFAULT 0
      )
    `);
    await queryRunner.query(`
      CREATE TABLE "career_role_skills" (
        "id" uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
        "careerRoleId" uuid NOT NULL REFERENCES "career_roles"("id") ON DELETE CASCADE,
        "skillId" uuid NOT NULL REFERENCES "skills"("id") ON DELETE CASCADE,
        "required_level" smallint NOT NULL,
        "priority" smallint NOT NULL DEFAULT 3,
        "weight" decimal(5,2) NOT NULL DEFAULT 1,
        CONSTRAINT "UQ_career_role_skill" UNIQUE ("careerRoleId", "skillId")
      )
    `);
    await queryRunner.query(`
      CREATE TABLE "student_skills" (
        "id" uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
        "studentId" uuid NOT NULL REFERENCES "students"("id") ON DELETE CASCADE,
        "skillId" uuid NOT NULL REFERENCES "skills"("id") ON DELETE CASCADE,
        "proficiency_level" smallint NOT NULL,
        "source" "skill_evidence_source_enum" NOT NULL DEFAULT 'self_declared',
        "is_verified" boolean NOT NULL DEFAULT false,
        CONSTRAINT "UQ_student_skill" UNIQUE ("studentId", "skillId")
      )
    `);
    await queryRunner.query(`
      CREATE TABLE "opportunities" (
        "id" uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
        "created_by_user_id" uuid NOT NULL REFERENCES "users"("id"),
        "title" varchar(160) NOT NULL,
        "type" "opportunity_type_enum" NOT NULL,
        "company_name" varchar(160) NOT NULL,
        "description" text NOT NULL,
        "location" varchar(120),
        "is_remote" boolean NOT NULL DEFAULT false,
        "eligibility_criteria" jsonb,
        "status" "opportunity_status_enum" NOT NULL DEFAULT 'draft',
        "deadline" timestamptz,
        "created_at" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
        "updated_at" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    `);
    await queryRunner.query(`
      CREATE TABLE "opportunity_skills" (
        "id" uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
        "opportunityId" uuid NOT NULL REFERENCES "opportunities"("id") ON DELETE CASCADE,
        "skillId" uuid NOT NULL REFERENCES "skills"("id") ON DELETE CASCADE,
        "minimum_level" smallint NOT NULL DEFAULT 1,
        "is_required" boolean NOT NULL DEFAULT true,
        "priority" smallint NOT NULL DEFAULT 3,
        CONSTRAINT "UQ_opportunity_skill" UNIQUE ("opportunityId", "skillId")
      )
    `);
    await queryRunner.query(`
      CREATE TABLE "applications" (
        "id" uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
        "studentId" uuid NOT NULL REFERENCES "students"("id") ON DELETE CASCADE,
        "opportunityId" uuid NOT NULL REFERENCES "opportunities"("id") ON DELETE CASCADE,
        "status" "application_status_enum" NOT NULL DEFAULT 'submitted',
        "compatibility_score" decimal(5,2),
        "cover_note" text,
        "applied_at" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
        "updated_at" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
        CONSTRAINT "UQ_student_opportunity_application" UNIQUE ("studentId", "opportunityId")
      )
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query('DROP TABLE "applications"');
    await queryRunner.query('DROP TABLE "opportunity_skills"');
    await queryRunner.query('DROP TABLE "opportunities"');
    await queryRunner.query('DROP TABLE "student_skills"');
    await queryRunner.query('DROP TABLE "career_role_skills"');
    await queryRunner.query('DROP TABLE "students"');
    await queryRunner.query('DROP TABLE "skills"');
    await queryRunner.query('DROP TABLE "career_roles"');
    await queryRunner.query('DROP TABLE "skill_categories"');
    await queryRunner.query('DROP TABLE "users"');
    await queryRunner.query('DROP TYPE "application_status_enum"');
    await queryRunner.query('DROP TYPE "opportunity_status_enum"');
    await queryRunner.query('DROP TYPE "opportunity_type_enum"');
    await queryRunner.query('DROP TYPE "skill_evidence_source_enum"');
    await queryRunner.query('DROP TYPE "user_role_enum"');
  }
}
