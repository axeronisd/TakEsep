import { prisma } from "@/lib/prisma"
import { NextResponse } from "next/server"
import bcrypt from "bcryptjs"
import { auth } from "@/auth"

export async function PUT(request: Request) {
    try {
        const session = await auth()
        if (!session?.user) {
            return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
        }

        const body = await request.json()
        const { currentPassword, newPassword } = body

        // Get current user
        const user = await prisma.user.findFirst()
        if (!user) {
            return NextResponse.json({ error: "User not found" }, { status: 404 })
        }

        // Verify current password
        const passwordsMatch = await bcrypt.compare(currentPassword, user.password)
        if (!passwordsMatch) {
            return NextResponse.json({ error: "Неверный текущий пароль" }, { status: 400 })
        }

        // Hash new password and update
        const hashedPassword = await bcrypt.hash(newPassword, 10)
        await prisma.user.update({
            where: { id: user.id },
            data: { password: hashedPassword }
        })

        return NextResponse.json({ success: true })
    } catch (error) {
        console.error("Error changing password:", error)
        return NextResponse.json({ error: "Failed to change password" }, { status: 500 })
    }
}
