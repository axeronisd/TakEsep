// JWT-based session management
// Stores session data directly in the cookie

import { SignJWT, jwtVerify } from 'jose'

const secret = new TextEncoder().encode(process.env.AUTH_SECRET || 'fallback-secret-key-for-development')

export interface SessionData {
    userId: string
    username: string
    role: string
    warehouseId: string | null
    warehouseName?: string
    exp: number
}

export async function createSession(userData: Omit<SessionData, 'exp'>): Promise<string> {
    const exp = Math.floor(Date.now() / 1000) + (24 * 60 * 60) // 24 hours

    const token = await new SignJWT({ ...userData, exp })
        .setProtectedHeader({ alg: 'HS256' })
        .setExpirationTime('24h')
        .sign(secret)

    return token
}

export async function getSessionFromToken(token: string): Promise<SessionData | null> {
    try {
        const { payload } = await jwtVerify(token, secret)

        if (payload.exp && payload.exp < Date.now() / 1000) {
            return null
        }

        return {
            userId: payload.userId as string,
            username: payload.username as string,
            role: payload.role as string,
            warehouseId: payload.warehouseId as string | null,
            warehouseName: payload.warehouseName as string | undefined,
            exp: (payload.exp as number) * 1000
        }
    } catch {
        return null
    }
}

// Synchronous version for middleware - parses JWT without verification
// Only for extracting claims, actual verification happens async
export function getSession(token: string): SessionData | null {
    try {
        const parts = token.split('.')
        if (parts.length !== 3) return null

        // Fix Base64Url encoding
        const base64 = parts[1].replace(/-/g, '+').replace(/_/g, '/')
        const payload = JSON.parse(atob(base64))

        if (payload.exp && payload.exp < Date.now() / 1000) {
            return null
        }

        return {
            userId: payload.userId,
            username: payload.username,
            role: payload.role,
            warehouseId: payload.warehouseId,
            warehouseName: payload.warehouseName,
            exp: payload.exp * 1000
        }
    } catch {
        return null
    }
}

export function deleteSession(sessionId: string): void {
    // JWT tokens are stateless, deletion happens by clearing cookie
}