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
        const { transferId, newName, newBarcode, newSellPrice } = body

        if (!transferId) {
            return NextResponse.json({ error: "Transfer ID required" }, { status: 400 })
        }

        const result = await prisma.$transaction(async (tx) => {
            // 1. Fetch Transfer & Validate
            const transfer = await tx.transfer.findUnique({
                where: { id: transferId },
                include: { product: true }
            })

            if (!transfer) throw new Error("Transfer not found")
            if (transfer.toWarehouseId !== currentWarehouseId) throw new Error("Unauthorized to accept this transfer")
            if (transfer.status !== "PENDING") throw new Error("Transfer is not pending")

            // 2. Determine Target Product
            let targetProductId = transfer.productId
            let isNewProduct = false

            // If user provided a new barcode and it differs from original
            if (newBarcode && newBarcode !== transfer.product.barcode) {
                const existingProduct = await tx.product.findUnique({ where: { barcode: newBarcode } })

                if (existingProduct) {
                    targetProductId = existingProduct.id
                } else {
                    // Create New Product
                    const newProduct = await tx.product.create({
                        data: {
                            name: newName || transfer.product.name,
                            barcode: newBarcode,
                            sellPrice: newSellPrice !== undefined ? Number(newSellPrice) : transfer.product.sellPrice,
                            buyPrice: transfer.product.buyPrice, // Inherit cost
                            stock: 0
                        }
                    })
                    targetProductId = newProduct.id
                    isNewProduct = true
                }
            } else if (newName && newName !== transfer.product.name) {
                // Optimization: If they just changed the NAME but kept the barcode, usually we update the existing product?
                // But wait, "renaming" might affect other warehouses.
                // Dangerous to rename globally.
                // Per user request: "If you change... system creates separate".
                // BUT if barcode is same, we cannot create separate (Barcode unique constraint).
                // So if Barcode is SAME but Name is DIFFERENT, we probably should just UPDATE the local name? No, Product is global.
                // Let's assume for now: To create new, you MUST change Barcode.
                // Or we can auto-generate a barcode? No.
                // Let's stick to: New Barcode = New/Different Product.
                // If Barcode is same, we accept as original.
            }

            // 3. Update Transfer Status
            await tx.transfer.update({
                where: { id: transferId },
                data: {
                    status: "COMPLETED",
                    note: isNewProduct ? `Принят как новый товар: ${newBarcode}` : transfer.note
                }
            })

            // 4. Add Stock to Destination (Target Product)
            await tx.stock.upsert({
                where: {
                    productId_warehouseId: {
                        productId: targetProductId,
                        warehouseId: currentWarehouseId
                    }
                },
                update: { quantity: { increment: transfer.quantity } },
                create: {
                    productId: targetProductId,
                    warehouseId: currentWarehouseId,
                    quantity: transfer.quantity
                }
            })

            // 5. Log Transaction (TRANSFER_IN) - using TARGET Product
            await tx.transaction.create({
                data: {
                    type: "TRANSFER_IN",
                    productId: targetProductId,
                    warehouseId: currentWarehouseId,
                    quantityChange: transfer.quantity,
                    note: `Принято перемещение от склада ${transfer.fromWarehouseId}` + (targetProductId !== transfer.productId ? " (Как новый товар)" : "")
                }
            })

            return { success: true, targetProductId }
        })

        return NextResponse.json(result)

    } catch (error: any) {
        console.error(error)
        return NextResponse.json({ error: error.message || "Failed to accept transfer" }, { status: 500 })
    }
}
