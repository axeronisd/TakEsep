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
        const { items } = await req.json()

        await prisma.$transaction(async (tx) => {
            for (const item of items) {
                const stockEntry = await tx.stock.findUnique({
                    where: {
                        productId_warehouseId: {
                            productId: item.productId,
                            warehouseId
                        }
                    }
                })

                if (!stockEntry || stockEntry.quantity < item.quantity) {
                    throw new Error(`Insufficient stock for product ${item.productId}`)
                }

                await tx.stock.update({
                    where: { id: stockEntry.id },
                    data: { quantity: stockEntry.quantity - item.quantity }
                })

                await tx.transaction.create({
                    data: {
                        type: "SALE",
                        quantityChange: -item.quantity,
                        productId: item.productId,
                        warehouseId,
                        snapshotPrice: item.price,
                        note: item.discount > 0 ? `Discount: ${item.discount}%` : null
                    }
                })
            }
        })

        return NextResponse.json({ success: true })
    } catch (error) {
        console.error(error)
        return NextResponse.json({ error: "Failed to process sale" }, { status: 500 })
    }
}
