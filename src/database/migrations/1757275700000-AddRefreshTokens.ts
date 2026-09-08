import { MigrationInterface, QueryRunner } from 'typeorm';
export class AddRefreshTokens1757275700000 implements MigrationInterface {
  name = 'AddRefreshTokens1757275700000';
  async up(q: QueryRunner): Promise<void> {
    await q.query('ALTER TABLE "users" ADD "refresh_token_hash" varchar');
  }
  async down(q: QueryRunner): Promise<void> {
    await q.query('ALTER TABLE "users" DROP COLUMN "refresh_token_hash"');
  }
}
