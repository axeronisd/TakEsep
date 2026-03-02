import { prisma } from "@/lib/prisma"
import { NextResponse } from "next/server"
import { cookies } from "next/headers"
import { getSession } from "@/lib/session"

export async function POST(req: Request) {
    const cookieStore = await cookies()
    const sessionToken = cookieStore.get('session-id')?.value
    const session = sessionToken ? getSession(sessionToken) : null
    const warehouseId = session?.warehouseId

    if (!warehouseId) {
        return NextResponse.json({ error: "Требуется контекст склада" }, { status: 400 })
    }

    try {
        const body = await req.json()
        const items = Array.isArray(body) ? body : [body]

        if (items.length === 0) return NextResponse.json({ success: true })

        await prisma.$transaction(async (tx) => {
            for (const item of items) {
                const { productId, quantity, buyPrice, sellPrice } = item

                // Update Prices if provided
                if (buyPrice !== undefined || sellPrice !== undefined) {
                    await tx.product.update({
                        where: { id: productId },
                        data: {
                            ...(buyPrice !== undefined && { buyPrice: parseFloat(buyPrice) }),
                            ...(sellPrice !== undefined && { sellPrice: parseFloat(sellPrice) })
                        }
                    })
                }

                // Update Stock
                const stockEntry = await tx.stock.findUnique({
                    where: {
                        productId_warehouseId: { productId, warehouseId }
                    }
                })

                if (stockEntry) {
                    await tx.stock.update({
                        where: { id: stockEntry.id },
                        data: { quantity: stockEntry.quantity + quantity }
                    })
                } else {
                    await tx.stock.create({
                        data: { productId, warehouseId, quantity }
                    })
                }

                await tx.transaction.create({
                    data: {
                        type: "RESTOCK",
                        quantityChange: quantity,
                        productId,
                        warehouseId,
                        snapshotPrice: buyPrice ? parseFloat(buyPrice) : undefined
                    }
                })
            }
        })

        return NextResponse.json({ success: true })
    } catch (error) {
        return NextResponse.json({ error: "Не удалось пополнить склад" }, { status: 500 })
    }
}
