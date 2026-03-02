import { prisma } from "@/lib/prisma"
import { NextResponse } from "next/server"
import bcrypt from "bcryptjs"
import { cookies } from "next/headers"
import { createSession } from "@/lib/session"

export async function GET() {
    try {
        const warehouses = await prisma.warehouse.findMany({
            include: { group: true },
            orderBy: { name: 'asc' }
        })
        return NextResponse.json(warehouses)
    } catch (e) {
        return NextResponse.json({ error: "Failed to fetch warehouses" }, { status: 500 })
    }
}

// Switch active warehouse with password verification
export async function POST(req: Request) {
    try {
        const cookieStore = await cookies()
        const currentToken = cookieStore.get("session")?.value
        if (!currentToken) {
            return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
        }

        const { warehouseId, password } = await req.json()

        if (!password) {
            return NextResponse.json({ error: "Password required" }, { status: 400 })
        }

        // Find the target warehouse
        const warehouse = await prisma.warehouse.findUnique({
            where: { id: warehouseId }
        })

        if (!warehouse) {
            return NextResponse.json({ error: "Warehouse not found" }, { status: 404 })
        }

        // Find admin user for target warehouse to verify password
        const targetWarehouseUser = await prisma.user.findFirst({
            where: { warehouseId: warehouseId }
        })

        if (!targetWarehouseUser) {
            return NextResponse.json({ error: "No user credentials found for this warehouse" }, { status: 404 })
        }

        const passwordsMatch = await bcrypt.compare(password, targetWarehouseUser.password)
        if (!passwordsMatch) {
            return NextResponse.json({ error: "Invalid warehouse password" }, { status: 401 })
        }

        // Create new session with updated warehouse info
        const newToken = await createSession({
            userId: targetWarehouseUser.id,
            username: targetWarehouseUser.username,
            role: targetWarehouseUser.role,
            warehouseId: warehouseId,
            warehouseName: warehouse.name
        })

        // Set the new session cookie
        cookieStore.set("session", newToken, {
            httpOnly: true,
            secure: process.env.NODE_ENV === "production",
            sameSite: "lax",
            maxAge: 60 * 60 * 24 * 7 // 7 days
        })

        return NextResponse.json({
            success: true,
            warehouseId: warehouseId,
            warehouseName: warehouse.name
        })
    } catch (e) {
        console.error("Switch error:", e)
        return NextResponse.json({ error: "Failed to switch warehouse" }, { status: 500 })
    }
}

// Change warehouse password with secret key verification
const SECRET_KEY = process.env.WAREHOUSE_SECRET_KEY || "amperbike20012731"

export async function PUT(req: Request) {
    try {
        const { warehouseId, secretKey, newPassword } = await req.json()

        // Verify secret key
        if (secretKey !== SECRET_KEY) {
            return NextResponse.json({ error: "Неверный секретный ключ" }, { status: 401 })
        }

        if (!warehouseId || !newPassword) {
            return NextResponse.json({ error: "Не указан склад или новый пароль" }, { status: 400 })
        }

        if (newPassword.length < 4) {
            return NextResponse.json({ error: "Пароль должен быть минимум 4 символа" }, { status: 400 })
        }

        // Find user for this warehouse
        const warehouseUser = await prisma.user.findFirst({
            where: { warehouseId }
        })

        if (!warehouseUser) {
            return NextResponse.json({ error: "Нет пользователя для этого склада" }, { status: 404 })
        }

        // Hash new password
        const hashedPassword = await bcrypt.hash(newPassword, 10)

        // Update user password
        await prisma.user.update({
            where: { id: warehouseUser.id },
            data: { password: hashedPassword }
        })

        return NextResponse.json({ success: true, message: "Пароль успешно изменён" })
    } catch (e) {
        console.error("Password change error:", e)
        return NextResponse.json({ error: "Ошибка смены пароля" }, { status: 500 })
    }
}
