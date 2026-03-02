"use client"

import { useState, useEffect } from "react"
import { useRouter } from "next/navigation"

export default function SettingsPage() {
    const router = useRouter()

    const [userName, setUserName] = useState("")
    const [warehouseName, setWarehouseName] = useState("")
    const [warehouseId, setWarehouseId] = useState<string | null>(null)

    // Password form
    const [newPassword, setNewPassword] = useState("")
    const [confirmPassword, setConfirmPassword] = useState("")
    const [secretKey, setSecretKey] = useState("")
    const [loading, setLoading] = useState(false)
    const [message, setMessage] = useState<{ type: "success" | "error"; text: string } | null>(null)

    // Rename warehouse
    const [editName, setEditName] = useState("")
    const [renameSecretKey, setRenameSecretKey] = useState("")
    const [renameLoading, setRenameLoading] = useState(false)
    const [renameMessage, setRenameMessage] = useState<{ type: "success" | "error"; text: string } | null>(null)

    // Seller password form
    const [sellerPassword, setSellerPassword] = useState("")
    const [sellerSecretKey, setSellerSecretKey] = useState("")
    const [sellerLoading, setSellerLoading] = useState(false)
    const [sellerMessage, setSellerMessage] = useState<{ type: "success" | "error"; text: string } | null>(null)

    useEffect(() => {
        fetch("/api/auth/session")
            .then(res => res.json())
            .then(data => {
                if (data?.user) {
                    setUserName(data.user.username || "")
                    setWarehouseName(data.user.warehouseName || "")
                    setEditName(data.user.warehouseName || "")
                    setWarehouseId(data.user.warehouseId || null)
                }
            })
            .catch(console.error)
    }, [])

    const handleChangePassword = async (e: React.FormEvent) => {
        e.preventDefault()
        setMessage(null)

        if (!secretKey) {
            setMessage({ type: "error", text: "Секретный ключ обязателен" })
            return
        }

        if (newPassword !== confirmPassword) {
            setMessage({ type: "error", text: "Пароли не совпадают" })
            return
        }

        if (newPassword.length < 4) {
            setMessage({ type: "error", text: "Пароль должен быть минимум 4 символа" })
            return
        }

        setLoading(true)
        try {
            const response = await fetch("/api/warehouses", {
                method: "PUT",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                    warehouseId,
                    secretKey,
                    newPassword
                })
            })
            const data = await response.json()
            if (response.ok) {
                setMessage({ type: "success", text: "Пароль успешно изменён" })
                setNewPassword(""); setConfirmPassword(""); setSecretKey("")
            } else {
                setMessage({ type: "error", text: data.error || "Ошибка" })
            }
        } catch {
            setMessage({ type: "error", text: "Ошибка сети" })
        } finally {
            setLoading(false)
        }
    }

    const handleRenameWarehouse = async (e: React.FormEvent) => {
        e.preventDefault()
        setRenameMessage(null)

        if (!renameSecretKey) {
            setRenameMessage({ type: "error", text: "Секретный ключ обязателен" })
            return
        }

        if (!editName.trim()) {
            setRenameMessage({ type: "error", text: "Название не может быть пустым" })
            return
        }

        setRenameLoading(true)
        try {
            const response = await fetch("/api/warehouses/rename", {
                method: "PUT",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                    warehouseId,
                    secretKey: renameSecretKey,
                    newName: editName.trim()
                })
            })
            const data = await response.json()
            if (response.ok) {
                setRenameMessage({ type: "success", text: "Название успешно изменено" })
                setWarehouseName(editName.trim())
                setRenameSecretKey("")
            } else {
                setRenameMessage({ type: "error", text: data.error || "Ошибка" })
            }
        } catch {
            setRenameMessage({ type: "error", text: "Ошибка сети" })
        } finally {
            setRenameLoading(false)
        }
    }

    const handleCreateSellerPassword = async (e: React.FormEvent) => {
        e.preventDefault()
        setSellerMessage(null)

        if (!sellerSecretKey) {
            setSellerMessage({ type: "error", text: "Секретный ключ обязателен" })
            return
        }

        if (sellerPassword.length < 4) {
            setSellerMessage({ type: "error", text: "Пароль должен быть минимум 4 символа" })
            return
        }

        setSellerLoading(true)
        try {
            const response = await fetch("/api/warehouses/seller", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                    warehouseId,
                    secretKey: sellerSecretKey,
                    password: sellerPassword
                })
            })
            const data = await response.json()
            if (response.ok) {
                setSellerMessage({ type: "success", text: "Пароль продавца успешно установлен" })
                setSellerPassword("")
                setSellerSecretKey("")
            } else {
                setSellerMessage({ type: "error", text: data.error || "Ошибка" })
            }
        } catch {
            setSellerMessage({ type: "error", text: "Ошибка сети" })
        } finally {
            setSellerLoading(false)
        }
    }

    const handleLogout = async () => {
        await fetch("/api/logout", { method: "POST" })
        router.push("/login")
        router.refresh()
    }

    return (
        <div className="min-h-screen bg-slate-950 py-8 px-4">
            <div className="max-w-md mx-auto">

                {/* Header */}
                <header className="mb-8 text-center">
                    <h1 className="text-2xl font-black text-white tracking-tight uppercase">Настройки</h1>
                    <p className="text-sm text-slate-500 mt-1">Безопасность и аккаунт</p>
                </header>

                {/* User Info */}
                <div className="bg-slate-900 rounded-2xl border border-slate-800 p-5 mb-4">
                    <div className="flex items-center gap-4">
                        <div className="w-12 h-12 bg-indigo-600/20 rounded-xl flex items-center justify-center flex-shrink-0">
                            <svg className="w-6 h-6 text-indigo-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth="2">
                                <path strokeLinecap="round" strokeLinejoin="round" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                            </svg>
                        </div>
                        <div className="min-w-0">
                            <p className="text-[10px] font-bold text-slate-500 uppercase tracking-wide">Вы вошли как</p>
                            <p className="text-base font-black text-white truncate">{userName}</p>
                            <p className="text-xs text-indigo-400 font-semibold truncate">{warehouseName}</p>
                        </div>
                    </div>
                </div>

                {/* Rename Warehouse */}
                <div className="bg-slate-900 rounded-2xl border border-slate-800 p-5 mb-4">
                    <h2 className="text-xs font-black text-slate-500 uppercase tracking-wide mb-5 text-center">Название склада</h2>

                    <form onSubmit={handleRenameWarehouse} className="space-y-4">
                        <div>
                            <label className="text-[10px] font-bold text-slate-500 uppercase tracking-wide block mb-1.5">
                                Новое название
                            </label>
                            <input
                                type="text"
                                value={editName}
                                onChange={(e) => setEditName(e.target.value)}
                                placeholder="Введите название"
                                required
                                className="w-full bg-slate-800 border border-slate-700 rounded-xl text-sm text-white px-4 py-3 focus:bg-slate-800 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 transition-all outline-none placeholder:text-slate-600"
                            />
                        </div>

                        <div>
                            <label className="text-[10px] font-bold text-amber-500 uppercase tracking-wide block mb-1.5">
                                Секретный ключ *
                            </label>
                            <input
                                type="password"
                                value={renameSecretKey}
                                onChange={(e) => setRenameSecretKey(e.target.value)}
                                placeholder="Обязательно"
                                required
                                className="w-full bg-amber-950/30 border border-amber-800/50 rounded-xl text-sm text-white px-4 py-3 focus:bg-slate-800 focus:ring-2 focus:ring-amber-500 focus:border-amber-500 transition-all outline-none placeholder:text-amber-800"
                            />
                        </div>

                        {renameMessage && (
                            <div className={`p-3 text-center text-xs font-bold tracking-wide uppercase rounded-xl ${renameMessage.type === "success"
                                ? "bg-emerald-900/30 text-emerald-400 border border-emerald-800/50"
                                : "bg-red-900/30 text-red-400 border border-red-800/50"
                                }`}>
                                {renameMessage.text}
                            </div>
                        )}

                        <button
                            type="submit"
                            disabled={renameLoading || editName === warehouseName}
                            className="w-full py-4 bg-indigo-600 hover:bg-indigo-700 text-white text-xs font-black tracking-widest uppercase rounded-xl transition-all active:scale-[0.98] disabled:opacity-50 shadow-lg shadow-indigo-500/20"
                        >
                            {renameLoading ? "СОХРАНЕНИЕ..." : "ПЕРЕИМЕНОВАТЬ"}
                        </button>
                    </form>
                </div>

                {/* Password Change Form */}
                <div className="bg-slate-900 rounded-2xl border border-slate-800 p-5 mb-4">
                    <h2 className="text-xs font-black text-slate-500 uppercase tracking-wide mb-5 text-center">Смена пароля</h2>

                    <form onSubmit={handleChangePassword} className="space-y-4">

                        <div>
                            <label className="text-[10px] font-bold text-slate-500 uppercase tracking-wide block mb-1.5">
                                Новый пароль
                            </label>
                            <input
                                type="password"
                                value={newPassword}
                                onChange={(e) => setNewPassword(e.target.value)}
                                placeholder="••••••••"
                                required
                                className="w-full bg-slate-800 border border-slate-700 rounded-xl text-sm text-white px-4 py-3 focus:bg-slate-800 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 transition-all outline-none placeholder:text-slate-600"
                            />
                        </div>

                        <div>
                            <label className="text-[10px] font-bold text-slate-500 uppercase tracking-wide block mb-1.5">
                                Подтверждение пароля
                            </label>
                            <input
                                type="password"
                                value={confirmPassword}
                                onChange={(e) => setConfirmPassword(e.target.value)}
                                placeholder="••••••••"
                                required
                                className="w-full bg-slate-800 border border-slate-700 rounded-xl text-sm text-white px-4 py-3 focus:bg-slate-800 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 transition-all outline-none placeholder:text-slate-600"
                            />
                        </div>

                        <div>
                            <label className="text-[10px] font-bold text-amber-500 uppercase tracking-wide block mb-1.5">
                                Секретный ключ *
                            </label>
                            <input
                                type="password"
                                value={secretKey}
                                onChange={(e) => setSecretKey(e.target.value)}
                                placeholder="Обязательно"
                                required
                                className="w-full bg-amber-950/30 border border-amber-800/50 rounded-xl text-sm text-white px-4 py-3 focus:bg-slate-800 focus:ring-2 focus:ring-amber-500 focus:border-amber-500 transition-all outline-none placeholder:text-amber-800"
                            />
                        </div>

                        {message && (
                            <div className={`p-3 text-center text-xs font-bold tracking-wide uppercase rounded-xl ${message.type === "success"
                                ? "bg-emerald-900/30 text-emerald-400 border border-emerald-800/50"
                                : "bg-red-900/30 text-red-400 border border-red-800/50"
                                }`}>
                                {message.text}
                            </div>
                        )}

                        <button
                            type="submit"
                            disabled={loading}
                            className="w-full py-4 bg-indigo-600 hover:bg-indigo-700 text-white text-xs font-black tracking-widest uppercase rounded-xl transition-all active:scale-[0.98] disabled:opacity-50 shadow-lg shadow-indigo-500/20"
                        >
                            {loading ? "СОХРАНЕНИЕ..." : "СОХРАНИТЬ ПАРОЛЬ"}
                        </button>
                    </form>
                </div>

                {/* Create/Update Seller Password Form */}
                <div className="bg-slate-900 rounded-2xl border border-slate-800 p-5 mb-4">
                    <h2 className="text-xs font-black text-slate-500 uppercase tracking-wide mb-5 text-center">Пароль для продавца</h2>
                    <p className="text-[10px] text-slate-500 text-center mb-4 leading-relaxed">
                        По этому паролю сотрудники будут входить в систему, но у них будет доступ только к разделам: Продажа, Приход, Перемещение.
                    </p>

                    <form onSubmit={handleCreateSellerPassword} className="space-y-4">
                        <div>
                            <label className="text-[10px] font-bold text-slate-500 uppercase tracking-wide block mb-1.5">
                                Новый пароль продавца
                            </label>
                            <input
                                type="password"
                                value={sellerPassword}
                                onChange={(e) => setSellerPassword(e.target.value)}
                                placeholder="••••••••"
                                required
                                className="w-full bg-slate-800 border border-slate-700 rounded-xl text-sm text-white px-4 py-3 focus:bg-slate-800 focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 transition-all outline-none placeholder:text-slate-600"
                            />
                        </div>

                        <div>
                            <label className="text-[10px] font-bold text-amber-500 uppercase tracking-wide block mb-1.5">
                                Секретный ключ (Владельца) *
                            </label>
                            <input
                                type="password"
                                value={sellerSecretKey}
                                onChange={(e) => setSellerSecretKey(e.target.value)}
                                placeholder="Обязательно"
                                required
                                className="w-full bg-amber-950/30 border border-amber-800/50 rounded-xl text-sm text-white px-4 py-3 focus:bg-slate-800 focus:ring-2 focus:ring-amber-500 focus:border-amber-500 transition-all outline-none placeholder:text-amber-800"
                            />
                        </div>

                        {sellerMessage && (
                            <div className={`p-3 text-center text-xs font-bold tracking-wide uppercase rounded-xl ${sellerMessage.type === "success"
                                ? "bg-emerald-900/30 text-emerald-400 border border-emerald-800/50"
                                : "bg-red-900/30 text-red-400 border border-red-800/50"
                                }`}>
                                {sellerMessage.text}
                            </div>
                        )}

                        <button
                            type="submit"
                            disabled={sellerLoading}
                            className="w-full py-4 bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-black tracking-widest uppercase rounded-xl transition-all active:scale-[0.98] disabled:opacity-50 shadow-lg shadow-emerald-500/20"
                        >
                            {sellerLoading ? "СОХРАНЕНИЕ..." : "УСТАНОВИТЬ ПАРОЛЬ"}
                        </button>
                    </form>
                </div>

                {/* Logout */}
                <div className="bg-slate-900/50 rounded-2xl border-2 border-dashed border-slate-800 p-5">
                    <p className="text-[10px] font-bold text-slate-600 uppercase tracking-wide mb-3 text-center">Завершение сеанса</p>
                    <button
                        onClick={handleLogout}
                        className="w-full py-4 bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs font-black tracking-widest uppercase rounded-xl transition-all active:scale-[0.98]"
                    >
                        ВЫЙТИ ИЗ СИСТЕМЫ
                    </button>
                </div>

            </div>
        </div>
    )
}
