
import { DefaultSession } from "next-auth"

declare module "next-auth" {
    interface Session {
        user: {
            id: string
            role: string
            warehouseId?: string
            username?: string
        } & DefaultSession["user"]
    }

    interface User {
        id: string
        role: string
        warehouseId?: string | null
        username?: string
    }
}

declare module "next-auth/jwt" {
    interface JWT {
        warehouseId?: string
        role?: string
        warehouseName?: string
    }
}
