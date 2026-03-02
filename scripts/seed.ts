import { PrismaClient } from '@prisma/client'
import bcrypt from 'bcryptjs'

const prisma = new PrismaClient()

// ============================================
// НАСТРОЙКИ ПАРОЛЕЙ — МЕНЯЙТЕ ЗДЕСЬ
// ============================================
const PASSWORDS = {
    // Владельцы (admin) — полный доступ ко всему
    owner1: 'owner1',     // Склад 1 — владелец
    owner2: 'owner2',     // Склад 2 — владелец
    owner3: 'owner3',     // Склад 3 — владелец

    // Продавцы (seller) — доступ только к Продажа, Приход, Перемещение
    seller1: 'seller1',   // Склад 1 — продавец
    seller2: 'seller2',   // Склад 2 — продавец
    seller3: 'seller3',   // Склад 3 — продавец
}

// Секретный ключ для смены паролей (только владельцы знают)
const SECRET_KEY = 'takesep02'
// ============================================

async function main() {
    console.log('🚀 Создание 3 складов с пользователями...\n')

    // ── Создаём 3 склада ──
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

    const warehouse3 = await prisma.warehouse.upsert({
        where: { name: 'Склад 3' },
        update: {},
        create: { name: 'Склад 3' },
    })

    console.log('✅ Склады созданы:', warehouse1.name, warehouse2.name, warehouse3.name)

    // ── Хешируем все пароли и создаем пользователей по очереди ──

    console.log('⏳ Генерация паролей и создание пользователей...')

    // ── Склад 1 ──
    console.log('   👤 Создаем owner1...')
    const hashOwner1 = await bcrypt.hash(PASSWORDS.owner1, 10)
    await prisma.user.upsert({
        where: { username: 'owner1' },
        update: { password: hashOwner1, warehouseId: warehouse1.id },
        create: { username: 'owner1', password: hashOwner1, role: 'admin', warehouseId: warehouse1.id },
    })

    console.log('   👤 Создаем seller1...')
    const hashSeller1 = await bcrypt.hash(PASSWORDS.seller1, 10)
    await prisma.user.upsert({
        where: { username: 'seller1' },
        update: { password: hashSeller1, warehouseId: warehouse1.id },
        create: { username: 'seller1', password: hashSeller1, role: 'seller', warehouseId: warehouse1.id },
    })

    // ── Склад 2 ──
    console.log('   👤 Создаем owner2...')
    const hashOwner2 = await bcrypt.hash(PASSWORDS.owner2, 10)
    await prisma.user.upsert({
        where: { username: 'owner2' },
        update: { password: hashOwner2, warehouseId: warehouse2.id },
        create: { username: 'owner2', password: hashOwner2, role: 'admin', warehouseId: warehouse2.id },
    })

    console.log('   👤 Создаем seller2...')
    const hashSeller2 = await bcrypt.hash(PASSWORDS.seller2, 10)
    await prisma.user.upsert({
        where: { username: 'seller2' },
        update: { password: hashSeller2, warehouseId: warehouse2.id },
        create: { username: 'seller2', password: hashSeller2, role: 'seller', warehouseId: warehouse2.id },
    })

    // ── Склад 3 ──
    console.log('   👤 Создаем owner3...')
    const hashOwner3 = await bcrypt.hash(PASSWORDS.owner3, 10)
    await prisma.user.upsert({
        where: { username: 'owner3' },
        update: { password: hashOwner3, warehouseId: warehouse3.id },
        create: { username: 'owner3', password: hashOwner3, role: 'admin', warehouseId: warehouse3.id },
    })

    console.log('   👤 Создаем seller3...')
    const hashSeller3 = await bcrypt.hash(PASSWORDS.seller3, 10)
    await prisma.user.upsert({
        where: { username: 'seller3' },
        update: { password: hashSeller3, warehouseId: warehouse3.id },
        create: { username: 'seller3', password: hashSeller3, role: 'seller', warehouseId: warehouse3.id },
    })

    console.log('✅ Все пользователи успешно созданы!')

    // ── Итоговая таблица ──
    console.log('\n' + '═'.repeat(55))
    console.log('  📋 ДАННЫЕ ДЛЯ ВХОДА')
    console.log('═'.repeat(55))
    console.log('')
    console.log('  🏭 Склад 1:')
    console.log(`     👑 Владелец:  owner1  /  ${PASSWORDS.owner1}`)
    console.log(`     🛒 Продавец:  seller1 /  ${PASSWORDS.seller1}`)
    console.log('')
    console.log('  🏭 Склад 2:')
    console.log(`     👑 Владелец:  owner2  /  ${PASSWORDS.owner2}`)
    console.log(`     🛒 Продавец:  seller2 /  ${PASSWORDS.seller2}`)
    console.log('')
    console.log('  🏭 Склад 3:')
    console.log(`     👑 Владелец:  owner3  /  ${PASSWORDS.owner3}`)
    console.log(`     🛒 Продавец:  seller3 /  ${PASSWORDS.seller3}`)
    console.log('')
    console.log('═'.repeat(55))
    console.log(`  🔑 Секретный ключ: ${SECRET_KEY}`)
    console.log('  ⚠️  Только владельцы могут менять пароли!')
    console.log('  📍 Смена пароля: Настройки → Секретный ключ')
    console.log('═'.repeat(55))
}

main()
    .then(async () => {
        await prisma.$disconnect()
    })
    .catch(async (e) => {
        console.error(e)
        await prisma.$disconnect()
        process.exit(1)
    })
