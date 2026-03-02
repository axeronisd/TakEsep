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
        const { action, items, auditId } = body

        // --- ACTION: START ---
        if (action === "START") {
            const existing = await prisma.audit.findFirst({
                where: { warehouseId, status: "IN_PROGRESS" }
            })
            if (existing) return NextResponse.json({ error: "Ревизия уже запущена", auditId: existing.id }, { status: 400 })

            return await prisma.$transaction(async (tx) => {
                const audit = await tx.audit.create({
                    data: {
                        status: "IN_PROGRESS",
                        warehouseId
                    }
                })

                // Snapshot only products for this warehouse's group
                const warehouse = await tx.warehouse.findUnique({
                    where: { id: warehouseId },
                    select: { groupId: true }
                })

                const products = await tx.product.findMany({
                    where: warehouse?.groupId ? { warehouseGroupId: warehouse.groupId } : {},
                    include: {
                        stocks: { where: { warehouseId } }
                    }
                })

                await tx.auditItem.createMany({
                    data: products.map(p => ({
                        auditId: audit.id,
                        productId: p.id,
                        expectedQty: p.stocks[0]?.quantity || 0,
                    }))
                })

                return NextResponse.json({ success: true, auditId: audit.id })
            })
        }

        // --- ACTION: SAVE (Draft) ---
        if (action === "SAVE") {
            if (!auditId) return NextResponse.json({ error: "Audit ID required" }, { status: 400 })

            await prisma.$transaction(
                items.map((item: any) =>
                    prisma.auditItem.updateMany({
                        where: { auditId, productId: item.productId },
                        data: { actualQty: item.actualQty, discrepancy: item.actualQty !== null ? item.actualQty - item.expectedQty : null }
                    })
                )
            )
            return NextResponse.json({ success: true })
        }

        // --- ACTION: SAVE_REPORT (Save audit without updating stock) ---
        if (action === "SAVE_REPORT") {
            if (!auditId) return NextResponse.json({ error: "Audit ID required" }, { status: 400 })

            await prisma.$transaction(async (tx) => {
                const audit = await tx.audit.findUnique({
                    where: { id: auditId },
                    include: { items: { include: { product: true } } }
                })

                if (!audit || audit.status !== "IN_PROGRESS") throw new Error("Invalid audit state")

                let totalDiscValue = 0

                for (const item of audit.items) {
                    const actual = item.actualQty ?? item.expectedQty
                    const diff = actual - item.expectedQty
                    totalDiscValue += diff * item.product.sellPrice

                    // Update item with actual values for record
                    await tx.auditItem.update({
                        where: { id: item.id },
                        data: {
                            actualQty: actual,
                            discrepancy: diff
                        }
                    })
                }

                // Mark as SAVED but not applied to stock yet
                await tx.audit.update({
                    where: { id: auditId },
                    data: {
                        status: "SAVED",
                        completedAt: new Date(),
                        totalDiscrepancyValue: totalDiscValue
                    }
                })
            })

            return NextResponse.json({ success: true })
        }

        // --- ACTION: PAUSE (Save draft and set to DRAFT status) ---
        if (action === "PAUSE") {
            if (!auditId) return NextResponse.json({ error: "Audit ID required" }, { status: 400 })

            await prisma.audit.update({
                where: { id: auditId },
                data: { status: "DRAFT" }
            })

            return NextResponse.json({ success: true })
        }

        // --- ACTION: REOPEN (Resume a DRAFT audit) ---
        if (action === "REOPEN") {
            if (!auditId) return NextResponse.json({ error: "Audit ID required" }, { status: 400 })

            // Check no other IN_PROGRESS audit exists
            const existing = await prisma.audit.findFirst({
                where: { warehouseId, status: "IN_PROGRESS" }
            })
            if (existing) {
                return NextResponse.json({ error: "Уже есть активная ревизия" }, { status: 400 })
            }

            const audit = await prisma.audit.findUnique({ where: { id: auditId } })
            if (!audit || audit.status !== "DRAFT") {
                return NextResponse.json({ error: "Черновик не найден" }, { status: 404 })
            }

            await prisma.audit.update({
                where: { id: auditId },
                data: { status: "IN_PROGRESS" }
            })

            return NextResponse.json({ success: true })
        }

        // --- ACTION: APPLY_STOCK (Apply saved audit to stock) ---
        if (action === "APPLY_STOCK") {
            if (!auditId) return NextResponse.json({ error: "Audit ID required" }, { status: 400 })

            await prisma.$transaction(async (tx) => {
                const audit = await tx.audit.findUnique({
                    where: { id: auditId },
                    include: { items: { include: { product: true } } }
                })

                if (!audit || audit.status !== "SAVED") throw new Error("Аудит не найден или уже применен")

                for (const item of audit.items) {
                    const actual = item.actualQty ?? item.expectedQty
                    const diff = actual - item.expectedQty

                    if (diff !== 0) {
                        await tx.stock.upsert({
                            where: { productId_warehouseId: { productId: item.productId, warehouseId } },
                            update: { quantity: actual },
                            create: { productId: item.productId, warehouseId, quantity: actual }
                        })

                        await tx.transaction.create({
                            data: {
                                type: "ADJUSTMENT",
                                quantityChange: diff,
                                productId: item.productId,
                                warehouseId,
                                note: `Ревизия (Применено)`
                            }
                        })
                    }
                }

                await tx.audit.update({
                    where: { id: auditId },
                    data: { status: "APPLIED" }
                })
            })

            return NextResponse.json({ success: true })
        }

        return NextResponse.json({ error: "Invalid action" }, { status: 400 })

    } catch (error: any) {
        console.error(error)
        return NextResponse.json({ error: error.message || "Failed to process audit" }, { status: 500 })
    }
}

export async function GET(req: Request) {
    const { searchParams } = new URL(req.url)
    const current = searchParams.get("current") === "true"

    const cookieStore = await cookies()
    const sessionToken = cookieStore.get('session-id')?.value
    const session = sessionToken ? getSession(sessionToken) : null
    const warehouseId = session?.warehouseId

    if (!warehouseId) return NextResponse.json([], { status: 401 })

    const drafts = searchParams.get("drafts") === "true"

    try {
        if (current) {
            const audit = await prisma.audit.findFirst({
                where: { warehouseId, status: "IN_PROGRESS" },
                include: {
                    items: {
                        include: { product: true },
                        orderBy: { product: { name: 'asc' } }
                    }
                }
            })
            return NextResponse.json(audit)
        }

        if (drafts) {
            const draftAudits = await prisma.audit.findMany({
                where: { warehouseId, status: "DRAFT" },
                include: {
                    items: {
                        include: { product: true },
                        orderBy: { product: { name: 'asc' } }
                    }
                },
                orderBy: { startedAt: 'desc' },
                take: 10
            })
            return NextResponse.json(draftAudits)
        }

        const audits = await prisma.audit.findMany({
            where: { warehouseId, status: { in: ["SAVED", "APPLIED"] } },
            include: {
                items: {
                    include: { product: true }
                }
            },
            orderBy: { completedAt: 'desc' },
            take: 20
        })
        return NextResponse.json(audits)
    } catch (e) {
        return NextResponse.json({ error: "Ошибка загрузки" }, { status: 500 })
    }
}

export async function DELETE(req: Request) {
    const cookieStore = await cookies()
    const sessionToken = cookieStore.get('session-id')?.value
    const session = sessionToken ? getSession(sessionToken) : null
    const warehouseId = session?.warehouseId

    if (!warehouseId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 })

    const { searchParams } = new URL(req.url)
    const auditId = searchParams.get("id")

    if (!auditId) return NextResponse.json({ error: "ID required" }, { status: 400 })

    try {
        // Verify audit belongs to this warehouse
        const audit = await prisma.audit.findFirst({
            where: { id: auditId, warehouseId }
        })

        if (!audit) return NextResponse.json({ error: "Not found" }, { status: 404 })

        // Delete audit items first, then audit
        await prisma.auditItem.deleteMany({ where: { auditId } })
        await prisma.audit.delete({ where: { id: auditId } })

        return NextResponse.json({ success: true })
    } catch (e) {
        return NextResponse.json({ error: "Ошибка удаления" }, { status: 500 })
    }
}
