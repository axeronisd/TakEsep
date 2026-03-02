import NextAuth from "next-auth"
import CredentialsProvider from "next-auth/providers/credentials"
import { prisma } from "@/lib/prisma"
import bcrypt from "bcryptjs"

export const { auth, handlers, signIn, signOut } = NextAuth({
    providers: [
        CredentialsProvider({
            name: "credentials",
            credentials: {
                username: { label: "Username", type: "text" },
                password: { label: "Password", type: "password" }
            },
            async authorize(credentials) {
                if (!credentials?.username || !credentials?.password) {
                    return null
                }

                const username = credentials.username as string
                const password = credentials.password as string

                const user = await prisma.user.findUnique({
                    where: { username },
                    include: { warehouse: true }
                })

                if (!user) {
                    return null
                }

                const isPasswordValid = await bcrypt.compare(password, user.password)

                if (!isPasswordValid) {
                    return null
                }

                return {
                    id: user.id,
                    username: user.username,
                    role: user.role,
                    warehouseId: user.warehouseId ?? undefined,
                    warehouseName: user.warehouse?.name
                }
            }
        })
    ],
    session: {
        strategy: "jwt"
    },
    callbacks: {
        async jwt({ token, user }) {
            if (user) {
                token.sub = user.id
                token.warehouseId = (user as any).warehouseId
                token.role = (user as any).role
                token.username = (user as any).username
                token.warehouseName = (user as any).warehouseName
            }
            return token
        },
        async session({ session, token }) {
            if (session.user && token) {
                session.user.id = token.sub || ''
                session.user.warehouseId = (token as any).warehouseId
                session.user.role = (token as any).role || 'user'
                session.user.username = (token as any).username || ''
                    ; (session.user as any).warehouseName = (token as any).warehouseName || ''
            }
            return session
        }
    },
    pages: {
        signIn: '/login',
    },
    secret: process.env.NEXTAUTH_SECRET,
})

export const { GET, POST } = handlers
