import { NextResponse } from "next/server"
import { prisma } from "@/lib/prisma"
import { getSession } from "@/lib/session"
import { cookies } from "next/headers"

export async function POST(req: Request) {
    const cookieStore = await cookies()
    const sessionToken = cookieStore.get('session-id')?.value
    const session = sessionToken ? getSession(sessionToken) : null

    if (!session || !session.warehouseId) {
        return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
    }

    try {
        const body = await req.json()
        const { amount, type, description, employeeId } = body

        if (!amount || !type) {
            return NextResponse.json({ error: "Amount and type are required" }, { status: 400 })
        }

        const transaction = await prisma.financialTransaction.create({
            data: {
                amount: parseFloat(amount),
                type, // SALARY, REPAIR, EXPENSE, OTHER_INCOME
                description,
                employeeId,
                warehouseId: session.warehouseId
            }
        })

        return NextResponse.json(transaction)
    } catch (error) {
        console.error("Finance Error:", error)
        return NextResponse.json({ error: "Failed to record transaction" }, { status: 500 })
    }
}

export async function GET(req: Request) {
    const cookieStore = await cookies()
    const sessionToken = cookieStore.get('session-id')?.value
    const session = sessionToken ? getSession(sessionToken) : null

    if (!session || !session.warehouseId) {
        return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
    }

    const { searchParams } = new URL(req.url)
    const type = searchParams.get("type")
    const startDate = searchParams.get("startDate")
    const endDate = searchParams.get("endDate")

    const where: any = {
        warehouseId: session.warehouseId
    }

    if (type) where.type = type
    if (startDate && endDate) {
        where.createdAt = {
            gte: new Date(startDate),
            lte: new Date(endDate)
        }
    }

    try {
        const transactions = await prisma.financialTransaction.findMany({
            where,
            include: {
                employee: true
            },
            orderBy: {
                createdAt: 'desc'
            },
            take: 200
        })

        return NextResponse.json(transactions)
    } catch (error) {
        return NextResponse.json({ error: "Failed to fetch transactions" }, { status: 500 })
    }
}

export async function DELETE(req: Request) {
    const cookieStore = await cookies()
    const sessionToken = cookieStore.get('session-id')?.value
    const session = sessionToken ? getSession(sessionToken) : null

    if (!session || !session.warehouseId) {
        return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
    }

    try {
        const { searchParams } = new URL(req.url)
        const id = searchParams.get("id")

        if (!id) {
            return NextResponse.json({ error: "ID is required" }, { status: 400 })
        }

        const transaction = await prisma.financialTransaction.findUnique({ where: { id } })

        if (!transaction || transaction.warehouseId !== session.warehouseId) {
            return NextResponse.json({ error: "Not found or unauthorized" }, { status: 404 })
        }

        await prisma.financialTransaction.delete({
            where: { id }
        })

        return NextResponse.json({ success: true })
    } catch (error) {
        console.error("Delete Finance Error:", error)
        return NextResponse.json({ error: "Failed to delete transaction" }, { status: 500 })
    }
}
