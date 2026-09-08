import {
  ConflictException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import * as bcrypt from 'bcryptjs';
import { Repository } from 'typeorm';
import { UserRole } from '../database/entities/enums';
import { User } from '../database/entities/user.entity';
import { AuthenticatedUser, JwtPayload } from './auth.types';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';

@Injectable()
export class AuthService {
  constructor(
    @InjectRepository(User)
    private readonly usersRepository: Repository<User>,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
  ) {}

  async register(registerDto: RegisterDto) {
    const email = registerDto.email.trim().toLowerCase();
    const existingUser = await this.usersRepository.findOne({
      where: { email },
    });

    if (existingUser) {
      throw new ConflictException(
        'An account already exists for this email address.',
      );
    }

    if (![UserRole.STUDENT, UserRole.INDUSTRY].includes(registerDto.role)) {
      throw new UnauthorizedException(
        'This role cannot be created through public registration.',
      );
    }

    const passwordHash = await bcrypt.hash(registerDto.password, 12);
    const user = await this.usersRepository.save(
      this.usersRepository.create({
        email,
        passwordHash,
        role: registerDto.role,
      }),
    );

    return this.createAuthResponse(user);
  }

  async login(loginDto: LoginDto) {
    const email = loginDto.email.trim().toLowerCase();
    const user = await this.usersRepository
      .createQueryBuilder('user')
      .addSelect('user.passwordHash')
      .where('user.email = :email', { email })
      .getOne();

    if (
      !user ||
      !user.isActive ||
      !(await bcrypt.compare(loginDto.password, user.passwordHash))
    ) {
      throw new UnauthorizedException('Invalid email or password.');
    }

    return this.createAuthResponse(user);
  }

  async refresh(refreshToken: RefreshTokenDto['refreshToken']) {
    try {
      const payload =
        await this.jwtService.verifyAsync<JwtPayload>(refreshToken);
      const user = await this.usersRepository
        .createQueryBuilder('user')
        .addSelect('user.refreshTokenHash')
        .where('user.id = :id', { id: payload.sub })
        .getOne();
      if (
        !user ||
        !user.isActive ||
        !user.refreshTokenHash ||
        !(await bcrypt.compare(refreshToken, user.refreshTokenHash))
      )
        throw new UnauthorizedException('Invalid refresh token.');
      return this.createAuthResponse(user);
    } catch {
      throw new UnauthorizedException('Invalid refresh token.');
    }
  }

  async logout(user: AuthenticatedUser) {
    await this.usersRepository.update(user.id, { refreshTokenHash: null });
    return { success: true };
  }

  private async createAuthResponse(user: User) {
    const payload: JwtPayload = {
      sub: user.id,
      email: user.email,
      role: user.role,
    };

    const refreshToken = await this.jwtService.signAsync(payload, {
      expiresIn: this.configService.get<string>(
        'JWT_REFRESH_EXPIRES_IN',
        '7d',
      ) as `${number}${'s' | 'm' | 'h' | 'd'}`,
    });
    await this.usersRepository.update(user.id, {
      refreshTokenHash: await bcrypt.hash(refreshToken, 12),
    });
    return {
      accessToken: await this.jwtService.signAsync(payload),
      refreshToken,
      user: this.toAuthenticatedUser(user),
    };
  }

  private toAuthenticatedUser(user: User): AuthenticatedUser {
    return { id: user.id, email: user.email, role: user.role };
  }
}
