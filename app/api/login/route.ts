import { NextResponse } from "next/server"
import bcrypt from "bcryptjs"
import { prisma } from "@/lib/prisma"
import { createSession } from "@/lib/session"

export async function POST(request: Request) {
    try {
        const body = await request.json()
        const { username, password, warehouseId: targetWarehouseId } = body

        if (!password) {
            return NextResponse.json(
                { error: "Пароль обязателен" },
                { status: 400 }
            )
        }

        let user;

        // Two login modes: by warehouseId (new) or by username (legacy)
        if (targetWarehouseId) {
            // Find all users for this warehouse
            const users = await prisma.user.findMany({
                where: { warehouseId: targetWarehouseId },
                include: { warehouse: true }
            })

            if (users.length === 0) {
                return NextResponse.json(
                    { error: "Для этого склада не созданы пользователи" },
                    { status: 401 }
                )
            }

            // Check admin first, then seller
            for (const u of users) {
                const isPasswordValid = await bcrypt.compare(password, u.password)
                if (isPasswordValid) {
                    user = u;
                    break;
                }
            }

            if (!user) {
                return NextResponse.json(
                    { error: "Неверный пароль" },
                    { status: 401 }
                )
            }
        } else if (username) {
            user = await prisma.user.findUnique({
                where: { username },
                include: { warehouse: true }
            })

            if (!user) {
                return NextResponse.json(
                    { error: "Пользователь не найден" },
                    { status: 401 }
                )
            }

            const isPasswordValid = await bcrypt.compare(password, user.password)
            if (!isPasswordValid) {
                return NextResponse.json(
                    { error: "Неверный пароль" },
                    { status: 401 }
                )
            }
        } else {
            return NextResponse.json(
                { error: "Укажите склад или имя пользователя" },
                { status: 400 }
            )
        }

        // Get warehouse info
        let warehouseId = user.warehouseId
        let warehouseName = user.warehouse?.name

        if (!warehouseId) {
            const warehouses = await prisma.warehouse.findMany()
            if (warehouses.length > 0) {
                warehouseId = warehouses[0].id
                warehouseName = warehouses[0].name

                await prisma.user.update({
                    where: { id: user.id },
                    data: { warehouseId }
                })
            }
        }

        // Create session
        const sessionData = {
            userId: user.id,
            username: user.username,
            role: user.role,
            warehouseId: warehouseId,
            warehouseName: warehouseName,
            exp: Date.now() + (24 * 60 * 60 * 1000) // 24 hours
        }

        const sessionId = await createSession(sessionData)

        const response = NextResponse.json({
            success: true,
            user: sessionData,
            message: "Login successful"
        })

        // Set session cookie
        response.cookies.set('session-id', sessionId, {
            httpOnly: true,
            secure: process.env.NODE_ENV === 'production',
            sameSite: 'lax',
            maxAge: 24 * 60 * 60, // 24 hours
            path: '/',
        })

        return response

    } catch (error) {
        console.error("Ошибка входа:", error)
        return NextResponse.json(
            { error: "Внутренняя ошибка сервера" },
            { status: 500 }
        )
    }
}