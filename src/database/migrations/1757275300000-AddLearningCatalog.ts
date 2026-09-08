import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddLearningCatalog1757275300000 implements MigrationInterface {
  name = 'AddLearningCatalog1757275300000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "courses" (
        "id" uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
        "title" varchar(180) NOT NULL UNIQUE,
        "provider" varchar(120) NOT NULL,
        "description" text,
        "url" text,
        "estimated_hours" integer,
        "is_active" boolean NOT NULL DEFAULT true
      )
    `);
    await queryRunner.query(`
      CREATE TABLE "course_skills" (
        "id" uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
        "courseId" uuid NOT NULL REFERENCES "courses"("id") ON DELETE CASCADE,
        "skillId" uuid NOT NULL REFERENCES "skills"("id") ON DELETE CASCADE,
        "priority" smallint NOT NULL DEFAULT 3,
        CONSTRAINT "UQ_course_skill" UNIQUE ("courseId", "skillId")
      )
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query('DROP TABLE "course_skills"');
    await queryRunner.query('DROP TABLE "courses"');
  }
}
