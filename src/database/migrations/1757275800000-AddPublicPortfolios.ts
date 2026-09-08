import { MigrationInterface, QueryRunner } from 'typeorm';
export class AddPublicPortfolios1757275800000 implements MigrationInterface {
  name = 'AddPublicPortfolios1757275800000';
  async up(q: QueryRunner): Promise<void> {
    await q.query(
      'ALTER TABLE "students" ADD "is_portfolio_public" boolean NOT NULL DEFAULT false',
    );
    await q.query('ALTER TABLE "students" ADD "portfolio_slug" varchar(80)');
    await q.query(
      'ALTER TABLE "students" ADD CONSTRAINT "UQ_students_portfolio_slug" UNIQUE ("portfolio_slug")',
    );
  }
  async down(q: QueryRunner): Promise<void> {
    await q.query(
      'ALTER TABLE "students" DROP CONSTRAINT "UQ_students_portfolio_slug"',
    );
    await q.query('ALTER TABLE "students" DROP COLUMN "portfolio_slug"');
    await q.query('ALTER TABLE "students" DROP COLUMN "is_portfolio_public"');
  }
}
