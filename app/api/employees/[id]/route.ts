import { NextResponse } from "next/server"
import { prisma } from "@/lib/prisma"
import { getSession } from "@/lib/session"
import { cookies } from "next/headers"

export async function PUT(req: Request, { params }: { params: Promise<{ id: string }> }) {
    const { id } = await params
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

        // Verify the employee belongs to the current warehouse
        const existingEmployee = await prisma.employee.findUnique({
            where: { id }
        })

        if (!existingEmployee || existingEmployee.warehouseId !== session.warehouseId) {
            return NextResponse.json({ error: "Employee not found or access denied" }, { status: 404 })
        }

        const employee = await prisma.employee.update({
            where: { id },
            data: {
                name,
                role: role || "staff",
                phone,
                salary: parseFloat(salary) || 0,
            }
        })

        return NextResponse.json(employee)
    } catch (error) {
        return NextResponse.json({ error: "Failed to update employee" }, { status: 500 })
    }
}

export async function DELETE(req: Request, { params }: { params: Promise<{ id: string }> }) {
    const { id } = await params
    const cookieStore = await cookies()
    const sessionToken = cookieStore.get('session-id')?.value
    const session = sessionToken ? getSession(sessionToken) : null

    if (!session || !session.warehouseId) {
        return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
    }

    try {
        // Verify the employee belongs to the current warehouse
        const existingEmployee = await prisma.employee.findUnique({
            where: { id }
        })

        if (!existingEmployee || existingEmployee.warehouseId !== session.warehouseId) {
            return NextResponse.json({ error: "Employee not found or access denied" }, { status: 404 })
        }

        // Delete the employee
        await prisma.employee.delete({
            where: { id }
        })

        return NextResponse.json({ success: true, message: "Employee deleted" })
    } catch (error) {
        return NextResponse.json({ error: "Failed to delete employee" }, { status: 500 })
    }
}
