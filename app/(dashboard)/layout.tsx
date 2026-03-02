"use client"

import { SessionProvider } from "next-auth/react"
import { Navigation } from "@/components/Navigation"

export default function DashboardLayout({
    children,
}: {
    children: React.ReactNode
}) {
    return (
        <SessionProvider>
            <div className="flex flex-col min-h-screen bg-slate-950">
                <Navigation />
                <main className="main-content flex-1">
                    {children}
                </main>
            </div>
        </SessionProvider>
    )
}
