import { prisma } from "@/lib/prisma"
import { NextResponse } from "next/server"

export async function GET() {
    try {
        await prisma.$connect()
        const warehouses = await prisma.warehouse.count()
        return NextResponse.json({
            status: "ok",
            message: "Connected to database",
            warehouseCount: warehouses,
            env: {
                hasDatabaseUrl: !!process.env.DATABASE_URL,
                databaseUrlStart: process.env.DATABASE_URL?.substring(0, 15) + "..."
            }
        })
    } catch (e: any) {
        console.error("DB Connection Error:", e)
        return NextResponse.json({
            status: "error",
            message: e.message,
            stack: e.stack
        }, { status: 500 })
    }
}
