import 'dotenv/config';
import * as bcrypt from 'bcryptjs';
import dataSource from './data-source';
import { UserRole } from './entities/enums';
import { User } from './entities/user.entity';

async function run() {
  if (process.env.NODE_ENV === 'production') {
    throw new Error('The admin bootstrap script cannot run in production.');
  }

  const email = process.env.ADMIN_EMAIL?.trim().toLowerCase();
  const password = process.env.ADMIN_PASSWORD;
  if (!email || !password) {
    throw new Error('Set ADMIN_EMAIL and ADMIN_PASSWORD before running this script.');
  }
  if (password.length < 8) {
    throw new Error('ADMIN_PASSWORD must be at least 8 characters long.');
  }

  await dataSource.initialize();
  const users = dataSource.getRepository(User);
  const existing = await users.findOne({ where: { email } });

  if (existing) {
    if (existing.role !== UserRole.ADMIN) {
      throw new Error(`Cannot bootstrap admin: ${email} already has the ${existing.role} role.`);
    }
    console.log(`Admin already exists: ${email}`);
  } else {
    await users.save(
      users.create({
        email,
        passwordHash: await bcrypt.hash(password, 12),
        role: UserRole.ADMIN,
        isEmailVerified: true,
      }),
    );
    console.log(`Admin created: ${email}`);
  }

  await dataSource.destroy();
}

void run().catch(async (error: unknown) => {
  console.error(error);
  if (dataSource.isInitialized) await dataSource.destroy();
  process.exitCode = 1;
});
