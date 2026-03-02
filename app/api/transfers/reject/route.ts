import { prisma } from "@/lib/prisma"
import { NextResponse } from "next/server"
import { cookies } from "next/headers"
import { getSession } from "@/lib/session"

export async function POST(req: Request) {
    const cookieStore = await cookies()
    const sessionToken = cookieStore.get('session-id')?.value
    const session = sessionToken ? getSession(sessionToken) : null
    const currentWarehouseId = session?.warehouseId

    if (!currentWarehouseId) {
        return NextResponse.json({ error: "Warehouse context required" }, { status: 400 })
    }

    try {
        const body = await req.json()
        const { transferId } = body

        if (!transferId) {
            return NextResponse.json({ error: "Transfer ID required" }, { status: 400 })
        }

        const result = await prisma.$transaction(async (tx) => {
            // 1. Fetch Transfer & Validate
            const transfer = await tx.transfer.findUnique({
                where: { id: transferId },
                include: { product: true }
            })

            if (!transfer) {
                throw new Error("Transfer not found")
            }

            if (transfer.toWarehouseId !== currentWarehouseId) {
                throw new Error("Unauthorized to reject this transfer")
            }

            if (transfer.status !== "PENDING") {
                throw new Error("Transfer is not pending")
            }

            // 2. Update Transfer Status to REJECTED
            await tx.transfer.update({
                where: { id: transferId },
                data: { status: "REJECTED" }
            })

            // 3. Return Stock to Source Warehouse
            const sourceStock = await tx.stock.findUnique({
                where: {
                    productId_warehouseId: {
                        productId: transfer.productId,
                        warehouseId: transfer.fromWarehouseId
                    }
                }
            })

            if (sourceStock) {
                await tx.stock.update({
                    where: { id: sourceStock.id },
                    data: { quantity: sourceStock.quantity + transfer.quantity }
                })
            } else {
                await tx.stock.create({
                    data: {
                        productId: transfer.productId,
                        warehouseId: transfer.fromWarehouseId,
                        quantity: transfer.quantity
                    }
                })
            }

            // 4. Log Transaction (TRANSFER_REJECTED)
            await tx.transaction.create({
                data: {
                    type: "TRANSFER_REJECTED",
                    productId: transfer.productId,
                    warehouseId: transfer.fromWarehouseId,
                    quantityChange: transfer.quantity,
                    note: `Отклонено складом ${currentWarehouseId}`
                }
            })

            return transfer
        })

        return NextResponse.json(result)

    } catch (error: any) {
        console.error(error)
        return NextResponse.json({ error: error.message || "Failed to reject transfer" }, { status: 500 })
    }
}
