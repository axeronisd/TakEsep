import { PrismaClient } from '@prisma/client'
import bcrypt from 'bcryptjs'

const prisma = new PrismaClient()

async function testAuth() {
    console.log('🧪 Тестирование аутентификации...')

    try {
        // Получаем пользователей
        const users = await prisma.user.findMany({
            include: { warehouse: true }
        })

        console.log('👥 Найденные пользователи:')
        users.forEach(user => {
            console.log(`   - ${user.username} (${user.warehouse?.name})`)
        })

        // Тестируем первого пользователя
        const admin = users.find(u => u.username === 'admin')
        if (admin) {
            const passwordValid = await bcrypt.compare('admin', admin.password)
            console.log(`🔑 Тест пароля для admin: ${passwordValid ? '✅ Работает' : '❌ Не работает'}`)
        }

        const admin2 = users.find(u => u.username === 'admin2')
        if (admin2) {
            const passwordValid = await bcrypt.compare('123456', admin2.password)
            console.log(`🔑 Тест пароля для admin2: ${passwordValid ? '✅ Работает' : '❌ Не работает'}`)
        }

        console.log('✅ Тестирование завершено')

    } catch (error) {
        console.error('❌ Ошибка тестирования:', error)
    }
}

testAuth()
    .then(async () => {
        await prisma.$disconnect()
    })
    .catch(async (e) => {
        console.error(e)
        await prisma.$disconnect()
        process.exit(1)
    })