import { prisma } from "@/lib/prisma"
import { NextResponse } from "next/server"

const SECRET_KEY = process.env.WAREHOUSE_SECRET_KEY || "amperbike20012731"

export async function PUT(req: Request) {
    try {
        const { warehouseId, secretKey, newName } = await req.json()

        // Verify secret key
        if (secretKey !== SECRET_KEY) {
            return NextResponse.json({ error: "Неверный секретный ключ" }, { status: 401 })
        }

        if (!warehouseId || !newName) {
            return NextResponse.json({ error: "Не указан склад или новое название" }, { status: 400 })
        }

        if (newName.length < 2) {
            return NextResponse.json({ error: "Название должно быть минимум 2 символа" }, { status: 400 })
        }

        // Check if name is already taken
        const existing = await prisma.warehouse.findFirst({
            where: { name: newName, id: { not: warehouseId } }
        })

        if (existing) {
            return NextResponse.json({ error: "Склад с таким названием уже существует" }, { status: 400 })
        }

        // Update warehouse name
        await prisma.warehouse.update({
            where: { id: warehouseId },
            data: { name: newName }
        })

        return NextResponse.json({ success: true, message: "Название успешно изменено" })
    } catch (e) {
        console.error("Rename warehouse error:", e)
        return NextResponse.json({ error: "Ошибка переименования" }, { status: 500 })
    }
}
