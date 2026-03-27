import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import { AppModule } from './app.module';

async function bootstrap() {
    const app = await NestFactory.create(AppModule);

    // Global prefix
    app.setGlobalPrefix('api/v1');

    // CORS
    app.enableCors({
        origin: '*', // TODO: restrict in production
        methods: 'GET,HEAD,PUT,PATCH,POST,DELETE',
    });

    // Validation
    app.useGlobalPipes(
        new ValidationPipe({
            whitelist: true,
            forbidNonWhitelisted: true,
            transform: true,
        }),
    );

    // Swagger API docs
    const config = new DocumentBuilder()
        .setTitle('TakEsep Platform API')
        .setDescription('TakEsep Business Ecosystem — Platform Core API')
        .setVersion('0.1.0')
        .addBearerAuth()
        .build();
    const document = SwaggerModule.createDocument(app, config);
    SwaggerModule.setup('api/docs', app, document);

    const port = process.env.PORT || 3000;
    await app.listen(port);
    console.log(`🚀 TakEsep Platform Core running on http://localhost:${port}`);
    console.log(`📚 API docs: http://localhost:${port}/api/docs`);
}
bootstrap();
