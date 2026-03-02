import { NextResponse } from "next/server"
import { PrismaClient } from '@prisma/client'
import bcrypt from 'bcryptjs'

const prisma = new PrismaClient()

const PASSWORDS = {
    owner1: 'owner1',
    owner2: 'owner2',
    owner3: 'owner3',
    seller1: 'seller1',
    seller2: 'seller2',
    seller3: 'seller3',
}

const SECRET_KEY = 'takesep02'

export async function GET() {
    try {
        console.log('🚀 API Route: Создание 3 складов с пользователями...\n')

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

        // ── Склад 1 ──
        const hashOwner1 = await bcrypt.hash(PASSWORDS.owner1, 10)
        await prisma.user.upsert({
            where: { username: 'owner1' },
            update: { password: hashOwner1, warehouseId: warehouse1.id },
            create: { username: 'owner1', password: hashOwner1, role: 'admin', warehouseId: warehouse1.id },
        })
        const hashSeller1 = await bcrypt.hash(PASSWORDS.seller1, 10)
        await prisma.user.upsert({
            where: { username: 'seller1' },
            update: { password: hashSeller1, warehouseId: warehouse1.id },
            create: { username: 'seller1', password: hashSeller1, role: 'seller', warehouseId: warehouse1.id },
        })

        // ── Склад 2 ──
        const hashOwner2 = await bcrypt.hash(PASSWORDS.owner2, 10)
        await prisma.user.upsert({
            where: { username: 'owner2' },
            update: { password: hashOwner2, warehouseId: warehouse2.id },
            create: { username: 'owner2', password: hashOwner2, role: 'admin', warehouseId: warehouse2.id },
        })
        const hashSeller2 = await bcrypt.hash(PASSWORDS.seller2, 10)
        await prisma.user.upsert({
            where: { username: 'seller2' },
            update: { password: hashSeller2, warehouseId: warehouse2.id },
            create: { username: 'seller2', password: hashSeller2, role: 'seller', warehouseId: warehouse2.id },
        })

        // ── Склад 3 ──
        const hashOwner3 = await bcrypt.hash(PASSWORDS.owner3, 10)
        await prisma.user.upsert({
            where: { username: 'owner3' },
            update: { password: hashOwner3, warehouseId: warehouse3.id },
            create: { username: 'owner3', password: hashOwner3, role: 'admin', warehouseId: warehouse3.id },
        })
        const hashSeller3 = await bcrypt.hash(PASSWORDS.seller3, 10)
        await prisma.user.upsert({
            where: { username: 'seller3' },
            update: { password: hashSeller3, warehouseId: warehouse3.id },
            create: { username: 'seller3', password: hashSeller3, role: 'seller', warehouseId: warehouse3.id },
        })

        return NextResponse.json({
            success: true,
            message: "База данных успешно заполнена тестовыми данными! 🚀",
            credentials: {
                "Склад 1": { owner: 'owner1 / owner1', seller: 'seller1 / seller1' },
                "Склад 2": { owner: 'owner2 / owner2', seller: 'seller2 / seller2' },
                "Склад 3": { owner: 'owner3 / owner3', seller: 'seller3 / seller3' },
                key: `Секретный ключ для смены: ${SECRET_KEY}`
            }
        }, { status: 200 })

    } catch (error: any) {
        console.error("❌ Ошибка при генерации:", error)
        return NextResponse.json({ success: false, error: error.message }, { status: 500 })
    }
}
