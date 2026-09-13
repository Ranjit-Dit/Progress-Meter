import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddStudentResumes1757276100000 implements MigrationInterface {
  name = 'AddStudentResumes1757276100000';
  async up(q: QueryRunner): Promise<void> {
    await q.query('ALTER TABLE "students" ADD "resume_path" text');
    await q.query(
      'ALTER TABLE "students" ADD "resume_original_name" varchar(255)',
    );
    await q.query(
      'ALTER TABLE "students" ADD "resume_uploaded_at" timestamptz',
    );
  }
  async down(q: QueryRunner): Promise<void> {
    await q.query('ALTER TABLE "students" DROP COLUMN "resume_uploaded_at"');
    await q.query('ALTER TABLE "students" DROP COLUMN "resume_original_name"');
    await q.query('ALTER TABLE "students" DROP COLUMN "resume_path"');
  }
}
