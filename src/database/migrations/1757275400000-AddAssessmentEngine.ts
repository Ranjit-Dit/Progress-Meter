import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddAssessmentEngine1757275400000 implements MigrationInterface {
  name = 'AddAssessmentEngine1757275400000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "assessment_questions" (
        "id" uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
        "skillId" uuid NOT NULL REFERENCES "skills"("id") ON DELETE CASCADE,
        "prompt" text NOT NULL,
        "options" jsonb NOT NULL,
        "correct_answer" varchar NOT NULL,
        "difficulty" smallint NOT NULL DEFAULT 1,
        "is_active" boolean NOT NULL DEFAULT true
      )
    `);
    await queryRunner.query(`
      CREATE TABLE "assessment_attempts" (
        "id" uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
        "studentId" uuid NOT NULL REFERENCES "students"("id") ON DELETE CASCADE,
        "skillId" uuid NOT NULL REFERENCES "skills"("id") ON DELETE CASCADE,
        "status" varchar NOT NULL DEFAULT 'in_progress',
        "score" decimal(5,2),
        "started_at" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
        "submitted_at" timestamptz
      )
    `);
    await queryRunner.query(`
      CREATE TABLE "assessment_answers" (
        "id" uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
        "attemptId" uuid NOT NULL REFERENCES "assessment_attempts"("id") ON DELETE CASCADE,
        "questionId" uuid NOT NULL REFERENCES "assessment_questions"("id") ON DELETE CASCADE,
        "selected_answer" varchar NOT NULL,
        "is_correct" boolean NOT NULL,
        CONSTRAINT "UQ_attempt_question" UNIQUE ("attemptId", "questionId")
      )
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query('DROP TABLE "assessment_answers"');
    await queryRunner.query('DROP TABLE "assessment_attempts"');
    await queryRunner.query('DROP TABLE "assessment_questions"');
  }
}
