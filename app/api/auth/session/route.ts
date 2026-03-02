import { NextResponse } from "next/server"
import { cookies } from "next/headers"
import { getSessionFromToken } from "@/lib/session"

export async function GET() {
    try {
        const cookieStore = await cookies()
        const sessionToken = cookieStore.get('session-id')?.value

        if (!sessionToken) {
            return NextResponse.json({ user: null })
        }

        const session = await getSessionFromToken(sessionToken)

        if (!session) {
            return NextResponse.json({ user: null })
        }

        return NextResponse.json({
            user: {
                id: session.userId,
                username: session.username,
                role: session.role,
                warehouseId: session.warehouseId,
                warehouseName: session.warehouseName
            }
        })
    } catch {
        return NextResponse.json({ user: null })
    }
}
