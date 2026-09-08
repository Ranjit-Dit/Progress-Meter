import { MigrationInterface, QueryRunner } from 'typeorm';
export class AddAuditLogs1757275900000 implements MigrationInterface {
  name = 'AddAuditLogs1757275900000';
  async up(q: QueryRunner): Promise<void> {
    await q.query(
      `CREATE TABLE "audit_logs" ("id" uuid PRIMARY KEY DEFAULT uuid_generate_v4(), "actorId" uuid REFERENCES "users"("id") ON DELETE SET NULL, "action" varchar(120) NOT NULL, "resource_type" varchar(80) NOT NULL, "resource_id" uuid, "metadata" jsonb, "created_at" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP)`,
    );
  }
  async down(q: QueryRunner): Promise<void> {
    await q.query('DROP TABLE "audit_logs"');
  }
}
