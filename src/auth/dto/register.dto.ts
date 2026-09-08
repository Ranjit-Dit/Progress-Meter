import { IsEmail, IsEnum, IsString, MinLength } from 'class-validator';
import { UserRole } from '../../database/entities/enums';

export class RegisterDto {
  @IsEmail()
  email: string;

  @IsString()
  @MinLength(8)
  password: string;

  @IsEnum(UserRole)
  role: UserRole;
}
