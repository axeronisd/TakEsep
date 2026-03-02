"use client"

import Link from "next/link"
import { usePathname, useRouter } from "next/navigation"
import { useState, useEffect } from "react"

const navItems = [
    { href: "/sales", label: "ПРОДАЖА" },
    { href: "/restock", label: "ПРИХОД" },
    { href: "/transfers", label: "ПЕРЕМЕЩЕНИЕ" },
    { href: "/products", label: "СКЛАД" },
    { href: "/staff", label: "СОТРУДНИКИ" },
    { href: "/audit", label: "РЕВИЗИЯ" },
    { href: "/analytics", label: "АНАЛИТИКА" },
    { href: "/reports", label: "ОТЧЕТЫ" },
    { href: "/settings", label: "НАСТРОЙКИ" },
]

type Warehouse = { id: string, name: string, groupId?: string, group?: { id: string, name: string } }

export function Navigation() {
    const pathname = usePathname()
    const router = useRouter()
    const [warehouses, setWarehouses] = useState<Warehouse[]>([])
    const [currentWarehouseId, setCurrentWarehouseId] = useState<string | null>(null)
    const [currentWarehouseName, setCurrentWarehouseName] = useState("")
    const [userRole, setUserRole] = useState("admin")

    // Warehouse switch modal
    const [showSwitchModal, setShowSwitchModal] = useState(false)
    const [selectedWarehouse, setSelectedWarehouse] = useState<Warehouse | null>(null)
    const [switchPassword, setSwitchPassword] = useState("")
    const [switchLoading, setSwitchLoading] = useState(false)
    const [switchError, setSwitchError] = useState("")

    useEffect(() => {
        // Fetch warehouses
        fetch("/api/warehouses")
            .then(res => res.json())
            .then(data => {
                if (Array.isArray(data)) setWarehouses(data)
            })
            .catch(console.error)

        // Fetch current session
        fetch("/api/auth/session")
            .then(res => res.json())
            .then(data => {
                if (data?.user) {
                    setCurrentWarehouseId(data.user.warehouseId)
                    setCurrentWarehouseName(data.user.warehouseName || "")
                    setUserRole(data.user.role || "admin")
                }
            })
            .catch(console.error)
    }, [])

    const handleWarehouseSwitch = async (e: React.FormEvent) => {
        e.preventDefault()
        if (!selectedWarehouse) return

        setSwitchError("")
        setSwitchLoading(true)

        try {
            const res = await fetch("/api/warehouses", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                    warehouseId: selectedWarehouse.id,
                    password: switchPassword
                })
            })

            const data = await res.json()

            if (res.ok) {
                setShowSwitchModal(false)
                setSwitchPassword("")
                setSelectedWarehouse(null)
                window.location.reload()
            } else {
                setSwitchError(data.error || "Неверный пароль")
            }
        } catch {
            setSwitchError("Ошибка сети")
        } finally {
            setSwitchLoading(false)
        }
    }

    const openSwitchModal = (warehouse: Warehouse) => {
        setSelectedWarehouse(warehouse)
        setSwitchPassword("")
        setSwitchError("")
        setShowSwitchModal(true)
    }

    const handleLogout = async () => {
        await fetch("/api/logout", { method: "POST" })
        router.push("/login")
        router.refresh()
    }

    return (
        <>
            <nav className="fixed top-0 left-0 right-0 bg-slate-900 border-b border-slate-800 z-50 shadow-2xl">
                {/* Main Nav Bar */}
                <div className="h-14 md:h-16 flex items-center justify-between px-3 md:px-6">

                    {/* Left: Warehouse Selector */}
                    <div className="relative group">
                        <button
                            className="text-white font-bold text-xs md:text-sm hover:text-indigo-400 transition-colors uppercase tracking-tight flex items-center gap-1.5 py-2 px-2 md:px-3 rounded-lg hover:bg-slate-800"
                        >
                            <svg className="w-4 h-4 text-indigo-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                                <path strokeLinecap="round" strokeLinejoin="round" d="M3 21h18M5 21V7l8-4 8 4v14M17 21v-8H7v8" />
                            </svg>
                            <span className="hidden sm:inline max-w-[120px] truncate">{currentWarehouseName}</span>
                            <span className="text-slate-500 text-[8px]">▼</span>
                        </button>

                        {/* Dropdown */}
                        <div className="absolute top-full left-0 mt-1 w-56 bg-slate-900 border border-slate-700 rounded-xl shadow-2xl opacity-0 invisible group-hover:opacity-100 group-hover:visible transition-all duration-200 z-50">
                            <div className="p-2">
                                <p className="text-[9px] font-bold text-slate-500 uppercase tracking-widest px-3 py-2">Переключить склад</p>
                                {warehouses.filter(w => {
                                    if (w.id === currentWarehouseId) return false
                                    // Show all warehouses (for cross-group switching)
                                    return true
                                }).map(w => (
                                    <button
                                        key={w.id}
                                        onClick={() => openSwitchModal(w)}
                                        className="w-full text-left px-3 py-2.5 text-sm text-white hover:bg-slate-800 rounded-lg font-medium transition-colors flex items-center gap-2"
                                    >
                                        <span className={`w-2 h-2 rounded-full ${w.group?.name === 'Телефоны' ? 'bg-blue-500' : 'bg-emerald-500'}`}></span>
                                        {w.name}
                                        {w.group && <span className="text-[9px] text-slate-500 ml-auto">{w.group.name}</span>}
                                    </button>
                                ))}
                            </div>
                        </div>
                    </div>

                    {/* Center: Nav Items (Desktop) */}
                    <div className="hidden lg:flex items-center gap-1 bg-slate-950/50 rounded-full p-1 border border-slate-800/50">
                        {navItems.filter(item => {
                            if (userRole === "admin") return true;
                            // Sellers only see these 3 pages
                            return ["/sales", "/restock", "/transfers"].includes(item.href)
                        }).map((item) => {
                            const isActive = pathname === item.href
                            return (
                                <Link
                                    key={item.href}
                                    href={item.href}
                                    className={`px-3 xl:px-4 py-2 text-[10px] xl:text-xs font-bold rounded-full transition-all ${isActive
                                        ? "text-white bg-indigo-600 shadow-lg"
                                        : "text-slate-400 hover:text-white hover:bg-slate-800"
                                        }`}
                                >
                                    {item.label}
                                </Link>
                            )
                        })}
                    </div>

                    {/* Right: Logout */}
                    <button
                        onClick={handleLogout}
                        className="text-slate-500 hover:text-red-400 text-[10px] md:text-xs font-bold uppercase transition-all px-2 md:px-4 py-2 border border-slate-800 hover:border-red-500/30 rounded-lg hover:bg-red-500/10 flex items-center gap-1.5"
                    >
                        <span className="hidden sm:inline">Выход</span>
                        <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                            <path strokeLinecap="round" strokeLinejoin="round" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" />
                        </svg>
                    </button>
                </div>

                {/* Mobile: Bottom Nav */}
                <div className="lg:hidden overflow-x-auto border-t border-slate-800/50 bg-slate-950/50">
                    <div className="flex items-center gap-1.5 p-2 min-w-max">
                        {navItems.filter(item => {
                            if (userRole === "admin") return true;
                            // Sellers only see these 3 pages
                            return ["/sales", "/restock", "/transfers"].includes(item.href)
                        }).map((item) => {
                            const isActive = pathname === item.href
                            return (
                                <Link
                                    key={item.href}
                                    href={item.href}
                                    className={`px-3 py-2 text-[9px] font-bold rounded-lg transition-all whitespace-nowrap ${isActive
                                        ? "text-white bg-indigo-600"
                                        : "text-slate-500 bg-slate-900 border border-slate-800"
                                        }`}
                                >
                                    {item.label}
                                </Link>
                            )
                        })}
                    </div>
                </div>
            </nav>

            {/* Warehouse Switch Modal */}
            {showSwitchModal && selectedWarehouse && (
                <div className="fixed inset-0 bg-black/70 backdrop-blur-sm z-[100] flex items-center justify-center p-4" onClick={() => setShowSwitchModal(false)}>
                    <div className="bg-slate-900 rounded-3xl border border-slate-700 w-full max-w-sm p-6 shadow-2xl" onClick={e => e.stopPropagation()}>
                        <div className="text-center mb-6">
                            <div className="w-14 h-14 bg-indigo-600/20 rounded-2xl flex items-center justify-center mx-auto mb-3">
                                <svg className="w-7 h-7 text-indigo-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                                    <path strokeLinecap="round" strokeLinejoin="round" d="M3 21h18M5 21V7l8-4 8 4v14M17 21v-8H7v8" />
                                </svg>
                            </div>
                            <h3 className="text-lg font-black text-white">{selectedWarehouse.name}</h3>
                            <p className="text-slate-500 text-xs mt-1">Введите пароль для переключения</p>
                        </div>

                        <form onSubmit={handleWarehouseSwitch}>
                            <input
                                type="password"
                                value={switchPassword}
                                onChange={(e) => setSwitchPassword(e.target.value)}
                                placeholder="Пароль склада"
                                autoFocus
                                required
                                className="w-full bg-slate-800 border border-slate-700 rounded-xl text-white text-center text-lg font-bold px-4 py-4 mb-3 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 transition-all outline-none"
                            />

                            {switchError && (
                                <div className="mb-3 p-3 bg-red-500/20 border border-red-500/30 rounded-xl">
                                    <p className="text-xs font-bold text-red-400 text-center">{switchError}</p>
                                </div>
                            )}

                            <div className="flex gap-2">
                                <button
                                    type="button"
                                    onClick={() => setShowSwitchModal(false)}
                                    className="flex-1 py-3 bg-slate-800 text-slate-400 rounded-xl font-bold text-xs uppercase tracking-wide hover:bg-slate-700 transition-colors"
                                >
                                    Отмена
                                </button>
                                <button
                                    type="submit"
                                    disabled={switchLoading}
                                    className="flex-1 py-3 bg-indigo-600 text-white rounded-xl font-bold text-xs uppercase tracking-wide hover:bg-indigo-700 transition-colors disabled:opacity-50"
                                >
                                    {switchLoading ? "..." : "Войти"}
                                </button>
                            </div>
                        </form>
                    </div>
                </div>
            )}
        </>
    )
}
