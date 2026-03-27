import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from './auth/auth.module';

@Module({
    imports: [
        // Environment config
        ConfigModule.forRoot({
            isGlobal: true,
            envFilePath: '.env',
        }),

        // Database
        TypeOrmModule.forRootAsync({
            imports: [ConfigModule],
            inject: [ConfigService],
            useFactory: (config: ConfigService) => ({
                type: 'postgres' as const,
                host: config.get('DB_HOST', 'localhost'),
                port: config.get<number>('DB_PORT', 5432),
                username: config.get('DB_USER', 'takesep'),
                password: config.get('DB_PASSWORD', 'takesep_dev_2026'),
                database: config.get('DB_NAME', 'takesep_platform'),
                schema: 'platform',
                autoLoadEntities: true,
                synchronize: config.get('NODE_ENV') !== 'production',
            }),
        }),

        // Feature modules
        AuthModule,
    ],
})
export class AppModule { }
