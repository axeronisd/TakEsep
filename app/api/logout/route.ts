import { NextResponse } from "next/server"
import { cookies } from "next/headers"

export async function POST() {
    try {
        const cookieStore = await cookies()

        // Clear session cookie
        cookieStore.delete('session-id')

        return NextResponse.json({ success: true })
    } catch {
        return NextResponse.json({ error: "Logout failed" }, { status: 500 })
    }
}
