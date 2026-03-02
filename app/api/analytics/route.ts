import { prisma } from "@/lib/prisma"
import { NextResponse } from "next/server"
import { cookies } from "next/headers"
import { getSession } from "@/lib/session"

export async function GET(req: Request) {
    const cookieStore = await cookies()
    const sessionToken = cookieStore.get('session-id')?.value
    const session = sessionToken ? getSession(sessionToken) : null
    const warehouseId = session?.warehouseId

    // For analytics, allow null warehouseId to get global view (for owner)
    const { searchParams } = new URL(req.url)
    const period = searchParams.get("period") || "month" // day, week, month, all, custom
    const startStr = searchParams.get("startDate")
    const endStr = searchParams.get("endDate")

    try {
        // Calculate date threshold
        // BISHKEK TIMEZONE FIX (UTC+6)
        // We need to calculate the start of the day relative to Bishkek time
        const now = new Date()
        const BISHKEK_OFFSET = 6 * 60 * 60 * 1000 // +6 hours in ms

        let startDate: Date
        let endDate: Date = new Date() // Current time (end of period for 'today')

        if (period === "custom" && startStr && endStr) {
            startDate = new Date(startStr)
            endDate = new Date(endStr)
            // Ensure end of day for endDate
            // Note: If 'custom' dates are selected from UI, they usually come as YYYY-MM-DD
            // If we want strict Bishkek 'end of day' for custom dates, we might need adjustments, 
            // but usually custom range implies 00:00 to 23:59 of selected days.
            // Assuming frontend sends simple dates or ISOs. 
            // For now, retaining existing 'custom' logic but ensuring 23:59:59 coverage
            endDate.setHours(23, 59, 59, 999)
        } else {
            // Helper to get Start of Day in Bishkek (returned as UTC Date)
            const getBishkekStartOfDay = (date: Date) => {
                // Shift to Bishkek "Face Value" time
                const bishkekTime = new Date(date.getTime() + BISHKEK_OFFSET)
                // Reset to midnight
                bishkekTime.setUTCHours(0, 0, 0, 0)
                // Shift back to UTC to get the actual timestamp
                return new Date(bishkekTime.getTime() - BISHKEK_OFFSET)
            }

            switch (period) {
                case "today":
                case "day":
                    // Start: 00:00 Bishkek today
                    startDate = getBishkekStartOfDay(now)
                    // End: Now
                    break
                case "yesterday":
                    // Start: 00:00 Bishkek yesterday
                    const todayStart = getBishkekStartOfDay(now)
                    startDate = new Date(todayStart.getTime() - 24 * 60 * 60 * 1000)
                    // End: 23:59:59.999 Bishkek yesterday (which is todayStart - 1ms)
                    endDate = new Date(todayStart.getTime() - 1)
                    break
                case "week":
                    startDate = new Date(now)
                    startDate.setDate(startDate.getDate() - 7)
                    break
                case "month":
                    startDate = new Date(now)
                    startDate.setMonth(startDate.getMonth() - 1)
                    break
                case "all":
                    startDate = new Date(0)
                    break
                default:
                    startDate = new Date(now)
                    startDate.setMonth(startDate.getMonth() - 1)
            }
        }

        // Common where clause for date and warehouse
        const dateFilter = {
            gte: startDate,
            lte: endDate
        }

        const warehouseFilter = warehouseId ? { warehouseId } : {}

        // Get all transactions for the period
        const transactions = await prisma.transaction.findMany({
            where: {
                createdAt: dateFilter,
                ...warehouseFilter
            },
            include: {
                product: true
            }
        })

        // Get financial transactions (Salaries, Repairs, Expenses)
        const financialTransactions = await prisma.financialTransaction.findMany({
            where: {
                createdAt: dateFilter,
                ...warehouseFilter
            }
        })

        // Process Financials
        const repairRevenue = financialTransactions
            .filter(t => t.type === "REPAIR" || t.type === "OTHER_INCOME")
            .reduce((sum, t) => sum + t.amount, 0)

        const salaryExpenses = financialTransactions
            .filter(t => t.type === "SALARY")
            .reduce((sum, t) => sum + t.amount, 0)

        const otherExpenses = financialTransactions
            .filter(t => t.type === "EXPENSE")
            .reduce((sum, t) => sum + t.amount, 0)

        // Get sales (SALE type transactions) with product cost info
        const sales = transactions.filter(t => t.type === "SALE")

        // Calculate Revenue from Products
        const productRevenue = sales.reduce((sum, t) => {
            const actualPrice = t.snapshotPrice ?? t.product.sellPrice
            return sum + (actualPrice * Math.abs(t.quantityChange))
        }, 0)

        // Calculate COGS (Cost of Goods Sold)
        const cogs = sales.reduce((sum, t) => {
            return sum + (t.product.buyPrice * Math.abs(t.quantityChange))
        }, 0)

        // Gross Profit (Product only)
        const grossProfit = productRevenue - cogs

        // Get inventory stats (Snapshot at current time - this is always "current" state, hard to reconstruct past state accurately without full history playback)
        // For simplicity, we return current inventory stats regardless of period, or we could just omit them for historical views if desired.
        // We will keep them as "Current Status" indicators.
        const stockData = await prisma.stock.findMany({
            where: warehouseFilter,
            include: {
                product: true
            }
        })

        const inventoryValue = stockData.reduce((sum, s) => sum + (s.quantity * s.product.sellPrice), 0)
        const inventoryCost = stockData.reduce((sum, s) => sum + (s.quantity * s.product.buyPrice), 0)
        const totalSKUs = stockData.length
        const lowStockItems = stockData.filter(s => s.quantity > 0 && s.quantity <= 5).length

        // Get audit losses
        const audits = await prisma.audit.findMany({
            where: {
                completedAt: dateFilter,
                status: { in: ["SAVED", "APPLIED"] },
                ...warehouseFilter
            }
        })
        const auditLosses = audits.reduce((sum, a) => sum + ((a.totalDiscrepancyValue ?? 0) < 0 ? Math.abs(a.totalDiscrepancyValue ?? 0) : 0), 0)

        // Net Profit Calculation
        // Net Profit = (Product Gross Profit + Repair Revenue) - (Salaries + Other Expenses + Audit Losses)
        const netProfit = (grossProfit + repairRevenue) - (salaryExpenses + otherExpenses + auditLosses)

        // Total Revenue (Product + Repair)
        const totalRevenue = productRevenue + repairRevenue

        // Combined Margin
        const netMargin = totalRevenue > 0 ? Math.round((netProfit / totalRevenue) * 100) : 0

        // Top selling products logic (unchanged)
        const productSales: Record<string, any> = {}

        sales.forEach(t => {
            const pid = t.productId
            const qty = Math.abs(t.quantityChange)
            const actualPrice = t.snapshotPrice ?? t.product.sellPrice
            const rev = actualPrice * qty
            const cost = t.product.buyPrice * qty

            if (!productSales[pid]) {
                productSales[pid] = {
                    name: t.product.name,
                    barcode: t.product.barcode,
                    quantity: 0,
                    revenue: 0,
                    cost: 0,
                    profit: 0,
                    margin: 0
                }
            }
            productSales[pid].quantity += qty
            productSales[pid].revenue += rev
            productSales[pid].cost += cost
            productSales[pid].profit += (rev - cost)
        })

        Object.values(productSales).forEach(p => {
            p.margin = p.revenue > 0 ? Math.round((p.profit / p.revenue) * 100) : 0
        })

        const topProducts = Object.values(productSales)
            .sort((a, b) => b.profit - a.profit)
            .slice(0, 15)

        // Slow-moving (unchanged)
        const soldProductIds = new Set(sales.map(t => t.productId))
        const slowMoving = stockData
            .filter(s => s.quantity > 0 && !soldProductIds.has(s.productId))
            .map(s => ({
                name: s.product.name,
                barcode: s.product.barcode,
                quantity: s.quantity,
                value: s.quantity * s.product.sellPrice
            }))
            .sort((a, b) => b.value - a.value)
            .slice(0, 10)

        // Transaction counts
        const transactionCounts = {
            sales: transactions.filter(t => t.type === "SALE").length,
            restocks: transactions.filter(t => t.type === "RESTOCK").length,
            transfersIn: transactions.filter(t => t.type === "TRANSFER_IN").length,
            transfersOut: transactions.filter(t => t.type === "TRANSFER_OUT").length,
            adjustments: transactions.filter(t => t.type === "ADJUSTMENT").length,
            repairs: financialTransactions.filter(t => t.type === "REPAIR").length,
            expenses: financialTransactions.filter(t => t.type === "EXPENSE").length,
        }

        const avgTransactionValue = sales.length > 0
            ? Math.round(productRevenue / sales.length)
            : 0

        return NextResponse.json({
            period,
            dateRange: { start: startDate, end: endDate },
            kpis: {
                revenue: productRevenue,
                repairRevenue,
                totalRevenue,
                cogs,
                grossProfit,
                salaryExpenses,
                otherExpenses,
                auditLosses,
                netProfit,
                margin: netMargin, // Now Net Margin
                grossMargin: productRevenue > 0 ? Math.round((grossProfit / productRevenue) * 100) : 0,

                inventoryValue,
                inventoryCost,
                totalSKUs,
                lowStockItems,
                lowStockList: stockData
                    .filter(s => s.quantity > 0 && s.quantity <= 5)
                    .map(s => ({
                        name: s.product.name,
                        barcode: s.product.barcode,
                        quantity: s.quantity,
                        sellPrice: s.product.sellPrice
                    })),

                avgTransactionValue,
                totalSales: sales.length
            },
            transactionCounts,
            topProducts,
            slowMoving
        })
    } catch (e) {
        console.error("Analytics error:", e)
        return NextResponse.json({ error: "Analytics failed" }, { status: 500 })
    }
}
