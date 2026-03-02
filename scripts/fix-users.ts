import { PrismaClient } from '@prisma/client'
import bcrypt from 'bcryptjs'

const prisma = new PrismaClient()

async function main() {
    console.log('Проверка пользователей...')

    // Получаем склады
    const warehouses = await prisma.warehouse.findMany()
    console.log('Найденные склады:', warehouses.map(w => ({ id: w.id, name: w.name })))

    if (warehouses.length < 2) {
        console.log('Создаем склады...')
        
        const warehouse1 = await prisma.warehouse.upsert({
            where: { name: 'Склад 1' },
            update: {},
            create: { name: 'Склад 1' },
        })
        
        const warehouse2 = await prisma.warehouse.upsert({
            where: { name: 'Склад 2' },
            update: {},
            create: { name: 'Склад 2' },
        })
        
        console.log('Склады созданы:', warehouse1.name, warehouse2.name)
    }

    // Удаляем старых пользователей
    await prisma.user.deleteMany({})
    console.log('Удалены старые пользователи')

    // Создаем новых пользователей с правильными паролями
    const warehouse1 = await prisma.warehouse.findUnique({ where: { name: 'Склад 1' } })
    const warehouse2 = await prisma.warehouse.findUnique({ where: { name: 'Склад 2' } })

    if (warehouse1 && warehouse2) {
        const hashedPassword1 = await bcrypt.hash('admin', 10)
        const hashedPassword2 = await bcrypt.hash('123456', 10)

        const admin1 = await prisma.user.create({
            data: {
                username: 'admin',
                password: hashedPassword1,
                role: 'admin',
                warehouseId: warehouse1.id,
            },
        })

        const admin2 = await prisma.user.create({
            data: {
                username: 'admin2',
                password: hashedPassword2,
                role: 'admin',
                warehouseId: warehouse2.id,
            },
        })

        console.log('✅ Пользователи созданы:')
        console.log(`   - Склад 1: admin / admin (ID: ${admin1.id})`)
        console.log(`   - Склад 2: admin2 / 123456 (ID: ${admin2.id})`)
        console.log(`   - Warehouse 1 ID: ${warehouse1.id}`)
        console.log(`   - Warehouse 2 ID: ${warehouse2.id}`)

        // Проверяем созданных пользователей
        const users = await prisma.user.findMany({
            include: { warehouse: true }
        })
        console.log('Все пользователи в базе:', users.map(u => ({
            id: u.id,
            username: u.username,
            role: u.role,
            warehouse: u.warehouse?.name,
            warehouseId: u.warehouseId
        })))
    } else {
        console.log('❌ Не удалось найти склады')
    }
}

main()
    .then(async () => {
        await prisma.$disconnect()
        console.log('✅ Скрипт завершен успешно')
    })
    .catch(async (e) => {
        console.error('❌ Ошибка:', e)
        await prisma.$disconnect()
        process.exit(1)
    })