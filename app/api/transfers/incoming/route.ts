import { prisma } from "@/lib/prisma"
import { NextResponse } from "next/server"
import { cookies } from "next/headers"
import { getSession } from "@/lib/session"

export async function GET(req: Request) {
    const cookieStore = await cookies()
    const sessionToken = cookieStore.get('session-id')?.value
    const session = sessionToken ? getSession(sessionToken) : null
    const currentWarehouseId = session?.warehouseId

    if (!currentWarehouseId) {
        return NextResponse.json([])
    }

    try {
        const incoming = await prisma.transfer.findMany({
            where: {
                toWarehouseId: currentWarehouseId,
                status: "PENDING"
            },
            include: {
                product: true,
                fromWarehouse: {
                    select: { name: true }
                }
            },
            orderBy: { createdAt: "desc" }
        })

        return NextResponse.json(incoming)
    } catch (error) {
        return NextResponse.json({ error: "Failed to fetch transfers" }, { status: 500 })
    }
}
