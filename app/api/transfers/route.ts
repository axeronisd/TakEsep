import { prisma } from "@/lib/prisma"
import { NextResponse } from "next/server"
import { cookies } from "next/headers"
import { getSession } from "@/lib/session"

// Get all transfers (for history)
export async function GET(req: Request) {
    const cookieStore = await cookies()
    const sessionToken = cookieStore.get('session-id')?.value
    const session = sessionToken ? getSession(sessionToken) : null
    const warehouseId = session?.warehouseId

    try {
        const transfers = await prisma.transfer.findMany({
            where: {
                OR: [
                    { fromWarehouseId: warehouseId ?? undefined },
                    { toWarehouseId: warehouseId ?? undefined }
                ]
            },
            include: {
                product: true,
                fromWarehouse: true,
                toWarehouse: true
            },
            orderBy: { createdAt: "desc" }
        })
        return NextResponse.json(transfers)
    } catch (e) {
        return NextResponse.json({ error: "Failed to fetch transfers" }, { status: 500 })
    }
}

// Create a bulk transfer
export async function POST(req: Request) {
    const cookieStore = await cookies()
    const sessionToken = cookieStore.get('session-id')?.value
    const session = sessionToken ? getSession(sessionToken) : null
    const fromWarehouseId = session?.warehouseId

    if (!fromWarehouseId) {
        return NextResponse.json({ error: "No warehouse context" }, { status: 400 })
    }

    try {
        const body = await req.json()
        // Support both single item (legacy) and bulk (new)
        // New format: { toWarehouseId, items: [{ productId, quantity }], note }
        const { toWarehouseId, items, note } = body

        // Handle legacy single item format if necessary, or just enforce new structure. 
        // Let's assume we proceed with the new structure OR adapt.
        const transferItems = items || (body.productId ? [{ productId: body.productId, quantity: body.quantity }] : [])

        if (fromWarehouseId === toWarehouseId) {
            return NextResponse.json({ error: "Cannot transfer to same warehouse" }, { status: 400 })
        }

        // Validate same warehouse group
        const [fromWh, toWh] = await Promise.all([
            prisma.warehouse.findUnique({ where: { id: fromWarehouseId }, select: { groupId: true } }),
            prisma.warehouse.findUnique({ where: { id: toWarehouseId }, select: { groupId: true } }),
        ])

        if (fromWh?.groupId && toWh?.groupId && fromWh.groupId !== toWh.groupId) {
            return NextResponse.json({ error: "Нельзя перемещать товары между разными группами складов" }, { status: 400 })
        }

        if (transferItems.length === 0) {
            return NextResponse.json({ error: "No items to transfer" }, { status: 400 })
        }

        await prisma.$transaction(async (tx) => {
            for (const item of transferItems) {
                const { productId, quantity } = item

                const sourceStock = await tx.stock.findUnique({
                    where: {
                        productId_warehouseId: {
                            productId,
                            warehouseId: fromWarehouseId
                        }
                    }
                })

                if (!sourceStock || sourceStock.quantity < quantity) {
                    throw new Error(`Недостаточно товара (ID: ${productId})`)
                }

                await tx.stock.update({
                    where: { id: sourceStock.id },
                    data: { quantity: sourceStock.quantity - quantity }
                })

                await tx.transfer.create({
                    data: {
                        productId,
                        fromWarehouseId,
                        toWarehouseId,
                        quantity,
                        note,
                        status: "PENDING"
                    }
                })

                await tx.transaction.create({
                    data: {
                        type: "TRANSFER_OUT",
                        productId,
                        warehouseId: fromWarehouseId,
                        quantityChange: -quantity,
                        note: `Transfer to ${toWarehouseId}`
                    }
                })
            }
        })

        return NextResponse.json({ success: true })
    } catch (e: any) {
        return NextResponse.json({ error: e.message || "Transfer failed" }, { status: 500 })
    }
}
