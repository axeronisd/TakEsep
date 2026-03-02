import { prisma } from "@/lib/prisma"
import { NextResponse } from "next/server"
import { cookies } from "next/headers"
import { getSession } from "@/lib/session"

export const dynamic = "force-dynamic"

async function getWarehouseGroupId(warehouseId: string): Promise<string | null> {
    const warehouse = await prisma.warehouse.findUnique({
        where: { id: warehouseId },
        select: { groupId: true }
    })
    return warehouse?.groupId || null
}

export async function GET(req: Request) {
    const cookieStore = await cookies()
    const sessionToken = cookieStore.get('session-id')?.value
    const session = sessionToken ? getSession(sessionToken) : null
    const warehouseId = session?.warehouseId

    if (!warehouseId) {
        return NextResponse.json({ error: "Не авторизован" }, { status: 401 })
    }

    try {
        const groupId = await getWarehouseGroupId(warehouseId)

        const products = await prisma.product.findMany({
            where: groupId ? { warehouseGroupId: groupId } : {},
            include: {
                stocks: {
                    where: { warehouseId: warehouseId }
                }
            },
            orderBy: { name: "asc" }
        })

        const formatted = products.map(p => ({
            ...p,
            stock: p.stocks.length > 0 ? p.stocks[0].quantity : 0
        }))

        return NextResponse.json(formatted)
    } catch (error) {
        return NextResponse.json({ error: "Не удалось получить товары" }, { status: 500 })
    }
}

export async function POST(req: Request) {
    const cookieStore = await cookies()
    const sessionToken = cookieStore.get('session-id')?.value
    const session = sessionToken ? getSession(sessionToken) : null

    if (session?.role !== "admin") {
        return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
    }

    try {
        const body = await req.json()
        const { name, barcode, stock, buyPrice, sellPrice } = body

        const warehouseId = session?.warehouseId
        const groupId = warehouseId ? await getWarehouseGroupId(warehouseId) : null

        const product = await prisma.product.create({
            data: {
                name,
                barcode,
                buyPrice,
                sellPrice,
                stock: 0,
                warehouseGroupId: groupId,
            }
        })

        // Create stock entries only for warehouses in the same group
        const warehouses = groupId
            ? await prisma.warehouse.findMany({ where: { groupId } })
            : await prisma.warehouse.findMany()

        for (const wh of warehouses) {
            await prisma.stock.create({
                data: {
                    productId: product.id,
                    warehouseId: wh.id,
                    quantity: wh.id === warehouseId ? (stock || 0) : 0
                }
            })
        }

        return NextResponse.json(product)
    } catch (error) {
        return NextResponse.json({ error: "Не удалось создать товар" }, { status: 500 })
    }
}
