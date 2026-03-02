import { prisma } from "@/lib/prisma"
import { NextResponse } from "next/server"
import { cookies } from "next/headers"
import { getSession } from "@/lib/session"

export async function GET(req: Request) {
    const cookieStore = await cookies()
    const sessionToken = cookieStore.get('session-id')?.value
    const session = sessionToken ? getSession(sessionToken) : null
    const warehouseId = session?.warehouseId

    if (!warehouseId) {
        return NextResponse.json({ error: "Warehouse context required" }, { status: 400 })
    }

    try {
        const { searchParams } = new URL(req.url)
        const type = searchParams.get("type")
        const startDate = searchParams.get("startDate")
        const endDate = searchParams.get("endDate")

        const where: any = { warehouseId }

        if (type) where.type = type
        if (startDate && endDate) {
            where.createdAt = {
                gte: new Date(startDate),
                lte: new Date(endDate)
            }
        }

        const transactions = await prisma.transaction.findMany({
            where,
            select: {
                id: true,
                type: true,
                quantityChange: true,
                createdAt: true,
                note: true,
                snapshotPrice: true,
                product: {
                    select: {
                        name: true,
                        sellPrice: true
                    }
                }
            },
            orderBy: { createdAt: "desc" },
            take: 200
        })
        return NextResponse.json(transactions)
    } catch (error) {
        console.error("Error fetching transactions:", error)
        return NextResponse.json({ error: "Failed to fetch transactions" }, { status: 500 })
    }
}
