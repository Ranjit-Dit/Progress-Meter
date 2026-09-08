import { MigrationInterface, QueryRunner } from 'typeorm';
export class AddInstitutions1757276000000 implements MigrationInterface {
  name = 'AddInstitutions1757276000000';
  async up(q: QueryRunner): Promise<void> {
    await q.query(
      `CREATE TABLE "institutions" ("id" uuid PRIMARY KEY DEFAULT uuid_generate_v4(), "name" varchar(180) NOT NULL UNIQUE, "code" varchar(40) NOT NULL UNIQUE, "location" varchar(120))`,
    );
    await q.query(
      `CREATE TABLE "institution_admins" ("id" uuid PRIMARY KEY DEFAULT uuid_generate_v4(), "user_id" uuid NOT NULL UNIQUE REFERENCES "users"("id") ON DELETE CASCADE, "institutionId" uuid NOT NULL REFERENCES "institutions"("id") ON DELETE CASCADE)`,
    );
    await q.query(
      'ALTER TABLE "students" ADD "institution_id" uuid REFERENCES "institutions"("id")',
    );
  }
  async down(q: QueryRunner): Promise<void> {
    await q.query('ALTER TABLE "students" DROP COLUMN "institution_id"');
    await q.query('DROP TABLE "institution_admins"');
    await q.query('DROP TABLE "institutions"');
  }
}
