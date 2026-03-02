import { prisma } from "@/lib/prisma"
import { NextResponse } from "next/server"
import bcrypt from "bcryptjs"

const SECRET_KEY = process.env.WAREHOUSE_SECRET_KEY || "amperbike20012731"

export async function POST(req: Request) {
    try {
        const { warehouseId, secretKey, password } = await req.json()

        // Verify secret key
        if (secretKey !== SECRET_KEY) {
            return NextResponse.json({ error: "Неверный секретный ключ" }, { status: 401 })
        }

        if (!warehouseId || !password) {
            return NextResponse.json({ error: "Не указан склад или пароль" }, { status: 400 })
        }

        if (password.length < 4) {
            return NextResponse.json({ error: "Пароль должен быть минимум 4 символа" }, { status: 400 })
        }

        // Check if seller already exists for this warehouse
        const username = `seller_${warehouseId.slice(0, 8)}`

        const existingSeller = await prisma.user.findUnique({
            where: { username }
        })

        const hashedPassword = await bcrypt.hash(password, 10)

        if (existingSeller) {
            // Update existing seller password
            await prisma.user.update({
                where: { id: existingSeller.id },
                data: { password: hashedPassword }
            })
        } else {
            // Create new seller
            await prisma.user.create({
                data: {
                    username,
                    password: hashedPassword,
                    role: "seller",
                    warehouseId: warehouseId
                }
            })
        }

        return NextResponse.json({ success: true, message: "Пароль продавца успешно установлен" })
    } catch (e) {
        console.error("Setup seller error:", e)
        return NextResponse.json({ error: "Ошибка при установке пароля продавца" }, { status: 500 })
    }
}
