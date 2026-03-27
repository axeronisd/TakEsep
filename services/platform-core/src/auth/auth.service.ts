import {
    Injectable,
    ConflictException,
    UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as bcrypt from 'bcrypt';
import { UserEntity } from './entities/user.entity';
import { RegisterDto, LoginDto } from './dto/auth.dto';

@Injectable()
export class AuthService {
    constructor(
        @InjectRepository(UserEntity)
        private readonly userRepo: Repository<UserEntity>,
        private readonly jwtService: JwtService,
    ) { }

    async register(dto: RegisterDto) {
        // Check if user exists
        const existing = await this.userRepo.findOne({
            where: { email: dto.email },
        });
        if (existing) {
            throw new ConflictException('Пользователь с таким email уже существует');
        }

        // Hash password
        const hashedPassword = await bcrypt.hash(dto.password, 12);

        // Create user
        const user = this.userRepo.create({
            email: dto.email,
            displayName: dto.displayName,
            password: hashedPassword,
        });
        await this.userRepo.save(user);

        // Generate tokens
        return this.generateTokens(user);
    }

    async login(dto: LoginDto) {
        // Find user with password
        const user = await this.userRepo.findOne({
            where: { email: dto.email },
            select: ['id', 'email', 'displayName', 'password', 'role'],
        });

        if (!user) {
            throw new UnauthorizedException('Неверный email или пароль');
        }

        // Verify password
        const isPasswordValid = await bcrypt.compare(dto.password, user.password);
        if (!isPasswordValid) {
            throw new UnauthorizedException('Неверный email или пароль');
        }

        return this.generateTokens(user);
    }

    async getProfile(userId: string) {
        return this.userRepo.findOne({ where: { id: userId } });
    }

    private generateTokens(user: UserEntity) {
        const payload = {
            sub: user.id,
            email: user.email,
            role: user.role,
        };

        return {
            user: {
                id: user.id,
                email: user.email,
                display_name: user.displayName,
                role: user.role,
            },
            access_token: this.jwtService.sign(payload, { expiresIn: '1h' }),
            refresh_token: this.jwtService.sign(payload, { expiresIn: '7d' }),
        };
    }
}
