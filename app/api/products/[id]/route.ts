import { prisma } from "@/lib/prisma"
import { NextResponse } from "next/server"
import { getSession } from "@/lib/session"
import { cookies } from "next/headers"

export const dynamic = "force-dynamic"

export async function PUT(
    request: Request,
    { params }: { params: Promise<{ id: string }> }
) {
    try {
        const { id } = await params
        const body = await request.json()
        const { name, barcode, stock, buyPrice, sellPrice } = body

        // Get warehouse ID from session
        const cookieStore = await cookies()
        const sessionToken = cookieStore.get('session-id')?.value
        const session = sessionToken ? getSession(sessionToken) : null

        // If updating common product fields
        await prisma.product.update({
            where: { id },
            data: {
                ...(name && { name }),
                ...(barcode && { barcode }),
                ...(buyPrice !== undefined && { buyPrice }),
                ...(sellPrice !== undefined && { sellPrice }),
            }
        })

        // If stock is provided and we have a warehouse, update the SPECIFIC STOCK record
        if (stock !== undefined && session?.warehouseId) {
            await prisma.stock.upsert({
                where: {
                    productId_warehouseId: {
                        productId: id,
                        warehouseId: session.warehouseId
                    }
                },
                update: { quantity: stock },
                create: {
                    productId: id,
                    warehouseId: session.warehouseId,
                    quantity: stock
                }
            })
        }

        return NextResponse.json({ success: true })
    } catch (error) {
        console.error("Error updating product:", error)
        return NextResponse.json({ error: "Failed to update product" }, { status: 500 })
    }
}

export async function DELETE(
    request: Request,
    { params }: { params: Promise<{ id: string }> }
) {
    try {
        const { id } = await params

        // Manual Cascade Delete for relations without onDelete: Cascade in schema
        // 1. Transactions
        await prisma.transaction.deleteMany({ where: { productId: id } })

        // 2. Transfers
        await prisma.transfer.deleteMany({ where: { productId: id } })

        // 3. Audit Items
        await prisma.auditItem.deleteMany({ where: { productId: id } })

        // 4. Stocks (handled by schema cascade usually, but safe to include)
        await prisma.stock.deleteMany({ where: { productId: id } })

        // Finally delete the product
        await prisma.product.delete({ where: { id } })

        return NextResponse.json({ success: true })
    } catch (error) {
        console.error("Error deleting product:", error)
        return NextResponse.json({ error: "Failed to delete product" }, { status: 500 })
    }
}
