import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'

// Inlined session types and parser to avoid Edge Runtime module resolution issues
interface SessionData {
    userId: string
    username: string
    role: string
    warehouseId: string | null
    warehouseName?: string
    exp: number
}

function getSession(token: string): SessionData | null {
    try {
        const parts = token.split('.')
        if (parts.length !== 3) return null

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

export function middleware(request: NextRequest) {
    const { pathname } = request.nextUrl

    // Allow access to login page and API endpoints
    if (pathname === '/login' ||
        pathname.startsWith('/api/') ||
        pathname.includes('.')) {
        return NextResponse.next()
    }

    // Check for authentication on protected routes
    const sessionId = request.cookies.get('session-id')?.value
    if (!sessionId) {
        return NextResponse.redirect(new URL('/login', request.url))
    }

    const session = getSession(sessionId)
    if (!session) {
        return NextResponse.redirect(new URL('/login', request.url))
    }

    // Role-Based Access Control logic for frontend routes
    if (!pathname.startsWith('/api/') && session.role === 'seller') {
        const allowedSellerRoutes = ['/sales', '/restock', '/transfers', '/login'];

        // If the pathname doesn't start with any of the allowed routes, redirect to /sales
        const isAllowed = allowedSellerRoutes.some(route => pathname === route || pathname.startsWith(route + '/'));

        // Let homepage (/) redirect naturally via other logic, or specifically block it?
        // Usually Next.js app router root might redirect to /sales or /analytics.
        // Let's ensure any unallowed route goes to /sales.
        if (!isAllowed && pathname !== '/') {
            return NextResponse.redirect(new URL('/sales', request.url))
        }
    }

    // Add user info to request headers for API routes
    const requestHeaders = new Headers(request.headers)
    requestHeaders.set('x-user-id', session.userId)
    requestHeaders.set('x-user-warehouse-id', session.warehouseId || '')
    requestHeaders.set('x-user-role', session.role || '')

    return NextResponse.next({
        request: {
            headers: requestHeaders,
        },
    })
}

export const config = {
    matcher: [
        /*
         * Match all request paths except for the ones starting with:
         * - _next/static (static files)
         * - _next/image (image optimization files)
         * - favicon.ico (favicon file)
         * - login (login page)
         * - api/login (login endpoint)
         */
        '/((?!_next/static|_next/image|favicon.ico|login|api/login).*)',
    ],
}
