import { MigrationInterface, QueryRunner } from 'typeorm';
export class AddNotifications1757275600000 implements MigrationInterface {
  name = 'AddNotifications1757275600000';
  async up(q: QueryRunner): Promise<void> {
    await q.query(
      `CREATE TABLE "notifications" ("id" uuid PRIMARY KEY DEFAULT uuid_generate_v4(), "userId" uuid NOT NULL REFERENCES "users"("id") ON DELETE CASCADE, "title" varchar(180) NOT NULL, "message" text NOT NULL, "is_read" boolean NOT NULL DEFAULT false, "created_at" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP)`,
    );
  }
  async down(q: QueryRunner): Promise<void> {
    await q.query('DROP TABLE "notifications"');
  }
}
