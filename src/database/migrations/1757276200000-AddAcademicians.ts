import { MigrationInterface, QueryRunner } from 'typeorm';
export class AddAcademicians1757276200000 implements MigrationInterface {
  name = 'AddAcademicians1757276200000';
  async up(q: QueryRunner): Promise<void> {
    await q.query(
      `CREATE TABLE "academicians" ("id" uuid PRIMARY KEY DEFAULT uuid_generate_v4(), "user_id" uuid NOT NULL UNIQUE REFERENCES "users"("id") ON DELETE CASCADE, "first_name" varchar(100) NOT NULL, "last_name" varchar(100) NOT NULL, "institution" varchar(180), "department" varchar(120), "expertise" text, "bio" text)`,
    );
  }
  async down(q: QueryRunner): Promise<void> {
    await q.query('DROP TABLE "academicians"');
  }
}
