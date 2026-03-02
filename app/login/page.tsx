"use client"

import { useState, useEffect } from "react"
import { useRouter } from "next/navigation"

type Warehouse = {
    id: string
    name: string
}

// Color palette for warehouse cards
const COLORS = [
    { bg: "bg-indigo-600", shadow: "rgba(79,70,229,0.3)", icon: "bg-indigo-500/20", iconText: "text-indigo-200", ring: "focus:ring-indigo-500/50", text: "text-indigo-600" },
    { bg: "bg-emerald-600", shadow: "rgba(16,185,129,0.3)", icon: "bg-emerald-500/20", iconText: "text-emerald-200", ring: "focus:ring-emerald-500/50", text: "text-emerald-600" },
    { bg: "bg-amber-600", shadow: "rgba(217,119,6,0.3)", icon: "bg-amber-500/20", iconText: "text-amber-200", ring: "focus:ring-amber-500/50", text: "text-amber-600" },
    { bg: "bg-rose-600", shadow: "rgba(225,29,72,0.3)", icon: "bg-rose-500/20", iconText: "text-rose-200", ring: "focus:ring-rose-500/50", text: "text-rose-600" },
    { bg: "bg-cyan-600", shadow: "rgba(8,145,178,0.3)", icon: "bg-cyan-500/20", iconText: "text-cyan-200", ring: "focus:ring-cyan-500/50", text: "text-cyan-600" },
    { bg: "bg-violet-600", shadow: "rgba(124,58,237,0.3)", icon: "bg-violet-500/20", iconText: "text-violet-200", ring: "focus:ring-violet-500/50", text: "text-violet-600" },
]

export default function LoginPage() {
    const [warehouses, setWarehouses] = useState<Warehouse[]>([])
    const [selectedWarehouse, setSelectedWarehouse] = useState<Warehouse | null>(null)
    const [password, setPassword] = useState("")
    const [error, setError] = useState("")
    const [loading, setLoading] = useState(false)
    const [mounted, setMounted] = useState(false)

    // Create warehouse mode
    const [createMode, setCreateMode] = useState(false)
    const [newWarehouseName, setNewWarehouseName] = useState("")
    const [newPassword, setNewPassword] = useState("")
    const [secretKey, setSecretKey] = useState("")
    const [createLoading, setCreateLoading] = useState(false)
    const [createMessage, setCreateMessage] = useState<{ type: "success" | "error", text: string } | null>(null)

    const router = useRouter()

    useEffect(() => {
        setMounted(true)
        fetchWarehouses()
    }, [])

    const fetchWarehouses = async () => {
        try {
            const res = await fetch("/api/warehouses")
            const data = await res.json()
            if (Array.isArray(data)) {
                setWarehouses(data)
            } else {
                console.error("Invalid warehouses data:", data)
            }
        } catch {
            console.error("Failed to fetch warehouses")
        }
    }

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault()
        if (!selectedWarehouse) return

        setError("")
        setLoading(true)

        try {
            // Find the admin user for this warehouse
            const response = await fetch("/api/login", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                    warehouseId: selectedWarehouse.id,
                    password: password,
                }),
            })

            const data = await response.json()

            if (!response.ok) {
                setError(data.error || "Ошибка входа")
            } else {
                router.push("/")
                router.refresh()
            }
        } catch {
            setError("Произошла ошибка")
        } finally {
            setLoading(false)
        }
    }

    const handleCreateWarehouse = async (e: React.FormEvent) => {
        e.preventDefault()
        setCreateMessage(null)
        setCreateLoading(true)

        try {
            const response = await fetch("/api/warehouses/create", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                    secretKey,
                    warehouseName: newWarehouseName,
                    password: newPassword,
                }),
            })

            const data = await response.json()

            if (response.ok) {
                setCreateMessage({ type: "success", text: "Склад создан! Теперь вы можете войти." })
                setNewWarehouseName("")
                setNewPassword("")
                setSecretKey("")
                fetchWarehouses()
                setTimeout(() => {
                    setCreateMode(false)
                    setCreateMessage(null)
                }, 2000)
            } else {
                setCreateMessage({ type: "error", text: data.error || "Ошибка создания" })
            }
        } catch {
            setCreateMessage({ type: "error", text: "Ошибка сети" })
        } finally {
            setCreateLoading(false)
        }
    }

    const getColor = (index: number) => COLORS[index % COLORS.length]

    if (!mounted) return null

    return (
        <div className="min-h-screen flex flex-col items-center bg-slate-950 p-6 overflow-hidden selection:bg-indigo-500/30">
            {/* Branding */}
            <div className={`transition-all duration-1000 ease-in-out text-center ${!selectedWarehouse && !createMode ? 'mt-[15vh] mb-12' : 'mt-[8vh] mb-8'}`}>
                <div className="inline-block group animate-fade-in">
                    <h1 className="text-7xl md:text-9xl font-black tracking-tighter text-white flex items-baseline justify-center select-none">
                        ТакЭсеп
                    </h1>
                    <div className="mt-4 flex justify-center items-center gap-6 opacity-30">
                        <div className="h-[2px] w-16 bg-white rounded-full"></div>
                        <div className="h-[2px] w-16 bg-white rounded-full"></div>
                    </div>
                </div>
            </div>

            <div className="w-full max-w-7xl relative flex flex-col items-center justify-center flex-1 mb-[10vh]">

                {/* CREATE WAREHOUSE MODE */}
                {createMode && (
                    <div className="w-full max-w-md animate-fade-in">
                        <div className="bg-slate-900 rounded-[3rem] border border-white/10 p-8 shadow-2xl">
                            <div className="text-center mb-8">
                                <div className="w-20 h-20 bg-slate-800 rounded-3xl flex items-center justify-center mx-auto mb-4">
                                    <svg xmlns="http://www.w3.org/2000/svg" width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="text-slate-400">
                                        <path d="M12 5v14M5 12h14" />
                                    </svg>
                                </div>
                                <h2 className="text-2xl font-black text-white uppercase tracking-wide">Создать склад</h2>
                                <p className="text-slate-500 text-sm mt-2">Введите секретный ключ для создания</p>
                            </div>

                            <form onSubmit={handleCreateWarehouse} className="space-y-4">
                                <div>
                                    <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest block mb-2">Название склада</label>
                                    <input
                                        type="text"
                                        value={newWarehouseName}
                                        onChange={(e) => setNewWarehouseName(e.target.value)}
                                        placeholder="Склад Алматы"
                                        required
                                        className="w-full bg-slate-800 border border-slate-700 rounded-2xl text-white px-4 py-4 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 transition-all outline-none"
                                    />
                                </div>

                                <div>
                                    <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest block mb-2">Пароль для склада</label>
                                    <input
                                        type="password"
                                        value={newPassword}
                                        onChange={(e) => setNewPassword(e.target.value)}
                                        placeholder="••••••••"
                                        required
                                        className="w-full bg-slate-800 border border-slate-700 rounded-2xl text-white px-4 py-4 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 transition-all outline-none"
                                    />
                                </div>

                                <div>
                                    <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest block mb-2">Секретный ключ</label>
                                    <input
                                        type="password"
                                        value={secretKey}
                                        onChange={(e) => setSecretKey(e.target.value)}
                                        placeholder="••••••••"
                                        required
                                        className="w-full bg-slate-800 border border-slate-700 rounded-2xl text-white px-4 py-4 focus:ring-2 focus:ring-amber-500 focus:border-amber-500 transition-all outline-none"
                                    />
                                </div>

                                {createMessage && (
                                    <div className={`p-4 text-center text-xs font-black tracking-widest uppercase rounded-xl ${createMessage.type === "success"
                                        ? "bg-emerald-500/20 text-emerald-400 border border-emerald-500/30"
                                        : "bg-red-500/20 text-red-400 border border-red-500/30"
                                        }`}>
                                        {createMessage.text}
                                    </div>
                                )}

                                <button
                                    type="submit"
                                    disabled={createLoading}
                                    className="w-full py-5 bg-indigo-600 hover:bg-indigo-700 text-white font-black text-sm uppercase tracking-[0.3em] rounded-2xl transition-all active:scale-[0.98] disabled:opacity-50 shadow-lg shadow-indigo-500/20 mt-4"
                                >
                                    {createLoading ? "СОЗДАНИЕ..." : "СОЗДАТЬ СКЛАД"}
                                </button>

                                <button
                                    type="button"
                                    onClick={() => { setCreateMode(false); setCreateMessage(null) }}
                                    className="w-full text-[12px] font-black text-white/30 hover:text-white uppercase tracking-[0.4em] py-2 transition-colors"
                                >
                                    Назад
                                </button>
                            </form>
                        </div>
                    </div>
                )}

                {/* WAREHOUSE SELECTION */}
                {!createMode && !selectedWarehouse && (
                    <div className="w-full flex flex-wrap justify-center items-center gap-8 md:gap-12 relative z-10">
                        {warehouses.map((warehouse, index) => {
                            const color = getColor(index)
                            return (
                                <div
                                    key={warehouse.id}
                                    className={`w-[240px] md:w-[280px] aspect-square ${color.bg} rounded-[3rem] shadow-[0_40px_80px_-20px_${color.shadow}] border border-white/10 hover:-translate-y-4 group active:scale-95 cursor-pointer transition-all duration-500 relative overflow-hidden`}
                                    onClick={() => setSelectedWarehouse(warehouse)}
                                    role="button"
                                    tabIndex={0}
                                    onKeyDown={(e) => e.key === 'Enter' && setSelectedWarehouse(warehouse)}
                                >
                                    <div className="absolute inset-0 bg-gradient-to-br from-white/10 to-transparent pointer-events-none"></div>
                                    <div className="w-full h-full flex flex-col items-center justify-center p-8">
                                        <div className={`w-24 h-24 rounded-3xl ${color.icon} shadow-[inset_0_4px_10px_rgba(0,0,0,0.2)] flex items-center justify-center ${color.iconText} group-hover:text-white transition-all duration-500 group-hover:scale-110`}>
                                            <svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                                                <path d="M3 21h18" /><path d="M5 21V7l8-4 8 4v14" /><path d="M17 21v-8H7v8" />
                                            </svg>
                                        </div>
                                        <h2 className="text-3xl font-black text-white/80 group-hover:text-white tracking-tight mt-4 transition-colors">{warehouse.name}</h2>
                                    </div>
                                </div>
                            )
                        })}
                    </div>
                )}

                {/* PASSWORD INPUT FOR SELECTED WAREHOUSE */}
                {!createMode && selectedWarehouse && (
                    <div className="w-full max-w-md animate-fade-in">
                        {(() => {
                            const index = warehouses.findIndex(w => w.id === selectedWarehouse.id)
                            const color = getColor(index)
                            return (
                                <div className={`${color.bg} rounded-[3rem] border border-white/10 p-8 shadow-[0_40px_80px_-20px_${color.shadow}]`}>
                                    <div className="absolute inset-0 bg-gradient-to-br from-white/10 to-transparent pointer-events-none rounded-[3rem]"></div>

                                    <div className="text-center mb-8 relative">
                                        <div className={`w-16 h-16 ${color.icon} rounded-2xl flex items-center justify-center mx-auto mb-4`}>
                                            <svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className={color.iconText}>
                                                <path d="M3 21h18" /><path d="M5 21V7l8-4 8 4v14" /><path d="M17 21v-8H7v8" />
                                            </svg>
                                        </div>
                                        <h2 className="text-2xl font-black text-white/70">{selectedWarehouse.name}</h2>
                                    </div>

                                    <form onSubmit={handleSubmit} className="relative">
                                        <p className="text-[10px] font-black text-white/40 uppercase tracking-[0.5em] mb-6 text-center">Введите пароль</p>

                                        <div className="mb-4">
                                            <input
                                                type="password"
                                                value={password}
                                                onChange={(e) => setPassword(e.target.value)}
                                                placeholder="······"
                                                className={`w-full text-center text-4xl tracking-[0.4em] font-black py-8 bg-black/30 border-none rounded-[2rem] text-white placeholder:text-white/10 shadow-[inset_0_12px_24px_rgba(0,0,0,0.5),inset_0_-1px_0_rgba(255,255,255,0.05)] ${color.ring} focus:ring-4 transition-all outline-none`}
                                                autoFocus
                                                required
                                            />
                                            {error && (
                                                <div className="mt-4 p-3 bg-red-500/20 border border-red-500/30 rounded-2xl">
                                                    <p className="text-[11px] font-black text-red-200 uppercase tracking-widest text-center">
                                                        {error}
                                                    </p>
                                                </div>
                                            )}
                                        </div>

                                        <div className="flex flex-col gap-4 mt-6">
                                            <button type="submit" disabled={loading} className={`w-full py-6 bg-white ${color.text} rounded-[2rem] font-black text-sm uppercase tracking-[0.4em] shadow-2xl hover:bg-slate-50 active:scale-95 transition-all`}>
                                                {loading ? "ВХОД..." : "ПОДТВЕРДИТЬ"}
                                            </button>
                                            <button type="button" onClick={() => { setSelectedWarehouse(null); setPassword(""); setError("") }} className="text-[12px] font-black text-white/30 hover:text-white uppercase tracking-[0.4em] py-2 transition-colors">
                                                Назад
                                            </button>
                                        </div>
                                    </form>
                                </div>
                            )
                        })()}
                    </div>
                )}

            </div>

            {/* Version Label */}
            <div className="mt-auto py-12 opacity-10 pointer-events-none">
                <span className="text-[11px] font-black tracking-[2.5em] text-white uppercase">Unit Control Platform v6.25</span>
            </div>
        </div>
    )
}
