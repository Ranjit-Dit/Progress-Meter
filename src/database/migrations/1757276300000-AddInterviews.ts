import { MigrationInterface, QueryRunner } from 'typeorm';
export class AddInterviews1757276300000 implements MigrationInterface {
  name = 'AddInterviews1757276300000';
  async up(q: QueryRunner): Promise<void> {
    await q.query(
      `CREATE TABLE "interviews" ("id" uuid PRIMARY KEY DEFAULT uuid_generate_v4(), "applicationId" uuid NOT NULL REFERENCES "applications"("id") ON DELETE CASCADE, "scheduled_at" timestamptz NOT NULL, "mode" varchar(120), "meeting_url" text, "notes" text, "status" varchar(30) NOT NULL DEFAULT 'scheduled', "created_at" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP)`,
    );
  }
  async down(q: QueryRunner): Promise<void> {
    await q.query('DROP TABLE "interviews"');
  }
}
