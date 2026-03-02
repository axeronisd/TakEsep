import { prisma } from "@/lib/prisma"
import { NextResponse } from "next/server"
import bcrypt from "bcryptjs"

const SECRET_KEY = process.env.WAREHOUSE_SECRET_KEY || "amperbike20012731"

// Create new warehouse with secret key verification
export async function POST(req: Request) {
    try {
        const { secretKey, warehouseName, password } = await req.json()

        // Verify secret key
        if (secretKey !== SECRET_KEY) {
            return NextResponse.json({ error: "Неверный секретный ключ" }, { status: 401 })
        }

        if (!warehouseName || !password) {
            return NextResponse.json({ error: "Название склада и пароль обязательны" }, { status: 400 })
        }

        if (password.length < 4) {
            return NextResponse.json({ error: "Пароль должен быть минимум 4 символа" }, { status: 400 })
        }

        // Check if warehouse name already exists
        const existingWarehouse = await prisma.warehouse.findUnique({
            where: { name: warehouseName }
        })

        if (existingWarehouse) {
            return NextResponse.json({ error: "Склад с таким названием уже существует" }, { status: 400 })
        }

        // Create warehouse
        const warehouse = await prisma.warehouse.create({
            data: { name: warehouseName }
        })

        // Generate unique username for this warehouse's admin
        const username = `admin_${warehouse.id.slice(0, 8)}`
        const hashedPassword = await bcrypt.hash(password, 10)

        // Create admin user for this warehouse
        await prisma.user.create({
            data: {
                username,
                password: hashedPassword,
                role: "admin",
                warehouseId: warehouse.id
            }
        })

        return NextResponse.json({
            success: true,
            warehouse: { id: warehouse.id, name: warehouse.name },
            message: "Склад успешно создан"
        })
    } catch (e) {
        console.error("Warehouse creation error:", e)
        return NextResponse.json({ error: "Ошибка создания склада" }, { status: 500 })
    }
}
