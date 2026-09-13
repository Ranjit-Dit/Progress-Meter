import { IsEmail, IsIn, IsString, MinLength } from 'class-validator';
import { UserRole } from '../../database/entities/enums';

export class CreatePrivilegedUserDto {
  @IsEmail()
  email: string;

  @IsString()
  @MinLength(8)
  password: string;

  @IsIn([UserRole.ACADEMICIAN, UserRole.INSTITUTION_ADMIN])
  role: UserRole.ACADEMICIAN | UserRole.INSTITUTION_ADMIN;
}
