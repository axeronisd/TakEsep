import { NextResponse } from "next/server"
import { prisma } from "@/lib/prisma"
import { getSession } from "@/lib/session"
import { cookies } from "next/headers"

export async function GET(req: Request) {
    const cookieStore = await cookies()
    const sessionToken = cookieStore.get('session-id')?.value
    const session = sessionToken ? getSession(sessionToken) : null

    if (!session || !session.warehouseId) {
        return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
    }

    try {
        const employees = await prisma.employee.findMany({
            where: {
                warehouseId: session.warehouseId
            },
            orderBy: {
                createdAt: 'desc'
            }
        })

        return NextResponse.json(employees)
    } catch (error) {
        return NextResponse.json({ error: "Failed to fetch employees" }, { status: 500 })
    }
}

export async function POST(req: Request) {
    const cookieStore = await cookies()
    const sessionToken = cookieStore.get('session-id')?.value
    const session = sessionToken ? getSession(sessionToken) : null

    if (!session || !session.warehouseId) {
        return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
    }

    try {
        const body = await req.json()
        const { name, role, phone, salary } = body

        if (!name) {
            return NextResponse.json({ error: "Name is required" }, { status: 400 })
        }

        const employee = await prisma.employee.create({
            data: {
                name,
                role: role || "staff",
                phone,
                salary: parseFloat(salary) || 0,
                warehouseId: session.warehouseId
            }
        })

        return NextResponse.json(employee)
    } catch (error) {
        return NextResponse.json({ error: "Failed to create employee" }, { status: 500 })
    }
}
