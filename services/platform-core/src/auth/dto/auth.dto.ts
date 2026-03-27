import { IsEmail, IsString, MinLength, MaxLength } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class RegisterDto {
    @ApiProperty({ example: 'user@company.kz' })
    @IsEmail()
    email: string;

    @ApiProperty({ example: 'Иван Иванов' })
    @IsString()
    @MaxLength(100)
    displayName: string;

    @ApiProperty({ example: 'securePassword123' })
    @IsString()
    @MinLength(8)
    password: string;
}

export class LoginDto {
    @ApiProperty({ example: 'user@company.kz' })
    @IsEmail()
    email: string;

    @ApiProperty({ example: 'securePassword123' })
    @IsString()
    password: string;
}
