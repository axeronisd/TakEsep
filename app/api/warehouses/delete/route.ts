import { prisma } from "@/lib/prisma"
import { NextResponse } from "next/server"

const SECRET_KEY = process.env.WAREHOUSE_SECRET_KEY || "amperbike20012731"

// Delete warehouse with secret key verification
export async function POST(req: Request) {
    try {
        const { warehouseId, secretKey } = await req.json()

        // Verify secret key
        if (secretKey !== SECRET_KEY) {
            return NextResponse.json({ error: "Неверный секретный ключ" }, { status: 401 })
        }

        if (!warehouseId) {
            return NextResponse.json({ error: "Не указан склад" }, { status: 400 })
        }

        // Check if warehouse exists
        const warehouse = await prisma.warehouse.findUnique({
            where: { id: warehouseId }
        })

        if (!warehouse) {
            return NextResponse.json({ error: "Склад не найден" }, { status: 404 })
        }

        // Delete all related data first (due to foreign key constraints)
        // Delete users
        await prisma.user.deleteMany({ where: { warehouseId } })

        // Delete stocks
        await prisma.stock.deleteMany({ where: { warehouseId } })

        // Delete transactions
        await prisma.transaction.deleteMany({ where: { warehouseId } })

        // Delete audits and audit items
        const audits = await prisma.audit.findMany({ where: { warehouseId } })
        for (const audit of audits) {
            await prisma.auditItem.deleteMany({ where: { auditId: audit.id } })
        }
        await prisma.audit.deleteMany({ where: { warehouseId } })

        // Delete transfers (where this warehouse is source or destination)
        await prisma.transfer.deleteMany({
            where: {
                OR: [
                    { fromWarehouseId: warehouseId },
                    { toWarehouseId: warehouseId }
                ]
            }
        })

        // Finally delete the warehouse
        await prisma.warehouse.delete({ where: { id: warehouseId } })

        return NextResponse.json({
            success: true,
            message: "Склад успешно удалён"
        })
    } catch (e) {
        console.error("Warehouse deletion error:", e)
        return NextResponse.json({ error: "Ошибка удаления склада" }, { status: 500 })
    }
}
