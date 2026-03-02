"use client"

import { useState, useEffect, useMemo } from "react"
import { toast } from "sonner"

interface Transaction {
    id: string
    type: string
    quantityChange: number
    createdAt: string
    note: string | null
    snapshotPrice: number | null
    product: {
        name: string
        sellPrice: number
    }
}

interface AuditReport {
    id: string
    status: string
    completedAt: string
    totalDiscrepancyValue: number
    items: {
        productId: string
        product: { name: string, barcode: string, sellPrice: number }
        expectedQty: number
        actualQty: number
        discrepancy: number
    }[]
}

type TimePeriod = "day" | "week" | "month" | "all"

export default function ReportsPage() {
    const [transactions, setTransactions] = useState<Transaction[]>([])
    const [audits, setAudits] = useState<AuditReport[]>([])
    const [loading, setLoading] = useState(true)
    const [filter, setFilter] = useState<string>("ALL")
    const [applyingStock, setApplyingStock] = useState<string | null>(null)
    const [expandedAudit, setExpandedAudit] = useState<string | null>(null)
    const [activeTab, setActiveTab] = useState<"audits" | "transactions">("audits")
    const [timePeriod, setTimePeriod] = useState<TimePeriod>("all")

    useEffect(() => {
        Promise.all([
            fetch("/api/transactions").then(res => res.json()),
            fetch("/api/audit").then(res => res.json())
        ])
            .then(([txData, auditData]) => {
                setTransactions(txData)
                setAudits(Array.isArray(auditData) ? auditData : [])
            })
            .catch(console.error)
            .finally(() => setLoading(false))
    }, [])

    // Filter by time period
    const getDateThreshold = (period: TimePeriod): Date => {
        const now = new Date()
        switch (period) {
            case "day":
                return new Date(now.getFullYear(), now.getMonth(), now.getDate())
            case "week":
                const weekAgo = new Date(now)
                weekAgo.setDate(weekAgo.getDate() - 7)
                return weekAgo
            case "month":
                const monthAgo = new Date(now)
                monthAgo.setMonth(monthAgo.getMonth() - 1)
                return monthAgo
            default:
                return new Date(0)
        }
    }

    const filteredAudits = useMemo(() => {
        const threshold = getDateThreshold(timePeriod)
        return audits.filter(a => new Date(a.completedAt) >= threshold)
    }, [audits, timePeriod])

    const filteredTransactions = useMemo(() => {
        const threshold = getDateThreshold(timePeriod)
        let filtered = transactions.filter(tx => new Date(tx.createdAt) >= threshold)
        if (filter !== "ALL") {
            filtered = filtered.filter(tx => tx.type === filter)
        }
        return filtered
    }, [transactions, timePeriod, filter])

    const applyStock = async (auditId: string) => {
        if (!confirm("Применить результаты ревизии к складу? Остатки будут обновлены.")) return

        setApplyingStock(auditId)
        try {
            const res = await fetch("/api/audit", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ action: "APPLY_STOCK", auditId })
            })
            if (res.ok) {
                toast.success("Склад успешно обновлен")
                setAudits(prev => prev.map(a => a.id === auditId ? { ...a, status: "APPLIED" } : a))
            } else {
                const data = await res.json()
                toast.error(data.error || "Ошибка применения")
            }
        } catch (e) {
            toast.error("Ошибка сети")
        } finally {
            setApplyingStock(null)
        }
    }

    const deleteAudit = async (auditId: string) => {
        if (!confirm("Удалить этот отчёт? Действие необратимо.")) return

        try {
            const res = await fetch(`/api/audit?id=${auditId}`, { method: "DELETE" })
            if (res.ok) {
                toast.success("Отчёт удален")
                setAudits(prev => prev.filter(a => a.id !== auditId))
            } else {
                toast.error("Ошибка удаления")
            }
        } catch {
            toast.error("Ошибка сети")
        }
    }

    const formatTime = (dateStr: string) => {
        return new Date(dateStr).toLocaleString("ru-RU", {
            timeZone: "Asia/Bishkek",
            day: "2-digit",
            month: "2-digit",
            year: "2-digit",
            hour: "2-digit",
            minute: "2-digit"
        })
    }

    const formatDate = (dateStr: string) => {
        return new Date(dateStr).toLocaleDateString("ru-RU", {
            timeZone: "Asia/Bishkek",
            day: "numeric",
            month: "long",
            year: "numeric"
        })
    }

    const getTypeStyle = (type: string) => {
        switch (type) {
            case "SALE": return { label: "Продажа", color: "text-emerald-400", bg: "bg-emerald-500/10", border: "border-emerald-500/20" }
            case "RESTOCK": return { label: "Приход", color: "text-blue-400", bg: "bg-blue-500/10", border: "border-blue-500/20" }
            case "TRANSFER_IN": return { label: "Входящий", color: "text-purple-400", bg: "bg-purple-500/10", border: "border-purple-500/20" }
            case "TRANSFER_OUT": return { label: "Исходящий", color: "text-orange-400", bg: "bg-orange-500/10", border: "border-orange-500/20" }
            case "ADJUSTMENT": return { label: "Корректировка", color: "text-amber-400", bg: "bg-amber-500/10", border: "border-amber-500/20" }
            case "AUDIT": return { label: "Ревизия", color: "text-indigo-400", bg: "bg-indigo-500/10", border: "border-indigo-500/20" }
            default: return { label: type, color: "text-slate-400", bg: "bg-slate-500/10", border: "border-slate-500/20" }
        }
    }

    // Stats
    const savedAudits = filteredAudits.filter(a => a.status === "SAVED")
    const appliedAudits = filteredAudits.filter(a => a.status === "APPLIED")
    const totalDiscrepancy = filteredAudits.reduce((sum, a) => sum + (a.totalDiscrepancyValue || 0), 0)

    if (loading) return (
        <div className="flex items-center justify-center h-[calc(100vh-5rem)] bg-slate-950 text-slate-500 font-black tracking-widest uppercase">
            Загрузка...
        </div>
    )

    return (
        <div className="min-h-[calc(100vh-5rem)] bg-slate-950 p-4 md:p-6 space-y-6 select-none font-sans">
            {/* Header */}
            <header className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
                <div>
                    <span className="text-[10px] font-black text-indigo-500 tracking-[0.4em] uppercase opacity-90">Журнал</span>
                    <h1 className="text-2xl sm:text-3xl font-black text-white tracking-tight mt-1 uppercase">Отчёты</h1>
                    <p className="text-sm text-slate-500 mt-1">История движения товаров и ревизий</p>
                </div>

                {/* Time Period Filter */}
                <div className="flex gap-2 flex-wrap">
                    {[
                        { value: "day" as TimePeriod, label: "День" },
                        { value: "week" as TimePeriod, label: "Неделя" },
                        { value: "month" as TimePeriod, label: "Месяц" },
                        { value: "all" as TimePeriod, label: "Всё время" },
                    ].map(p => (
                        <button
                            key={p.value}
                            onClick={() => setTimePeriod(p.value)}
                            className={`px-3 md:px-4 py-2 rounded-lg text-[10px] font-black tracking-widest uppercase transition-all ${timePeriod === p.value
                                ? "bg-indigo-600 text-white"
                                : "bg-slate-900 text-slate-500 hover:bg-slate-800"
                                }`}
                        >
                            {p.label}
                        </button>
                    ))}
                </div>
            </header>

            {/* Quick Stats */}
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 md:gap-4">
                <div className="bg-slate-900/50 border border-slate-800 rounded-2xl p-4">
                    <span className="text-[10px] font-black text-amber-500 uppercase tracking-widest">Ожидают</span>
                    <p className="text-2xl font-black text-white mt-1">{savedAudits.length}</p>
                </div>
                <div className="bg-slate-900/50 border border-slate-800 rounded-2xl p-4">
                    <span className="text-[10px] font-black text-emerald-500 uppercase tracking-widest">Применено</span>
                    <p className="text-2xl font-black text-white mt-1">{appliedAudits.length}</p>
                </div>
                <div className="bg-slate-900/50 border border-slate-800 rounded-2xl p-4">
                    <span className="text-[10px] font-black text-indigo-500 uppercase tracking-widest">Ревизий</span>
                    <p className="text-2xl font-black text-white mt-1">{filteredAudits.length}</p>
                </div>
                <div className="bg-slate-900/50 border border-slate-800 rounded-2xl p-4">
                    <span className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Разница</span>
                    <p className={`text-xl md:text-2xl font-black mt-1 ${totalDiscrepancy < 0 ? "text-red-500" : totalDiscrepancy > 0 ? "text-emerald-500" : "text-white"}`}>
                        {totalDiscrepancy > 0 ? "+" : ""}{totalDiscrepancy.toLocaleString()} сом
                    </p>
                </div>
            </div>

            {/* Tabs */}
            <div className="flex gap-2 border-b border-slate-800 pb-4 overflow-x-auto no-scrollbar">
                <button
                    onClick={() => setActiveTab("audits")}
                    className={`px-6 py-3 rounded-xl text-xs font-black tracking-widest uppercase transition-all whitespace-nowrap ${activeTab === "audits"
                        ? "bg-indigo-600 text-white shadow-lg shadow-indigo-500/20"
                        : "bg-slate-900 text-slate-400 hover:bg-slate-800"
                        }`}
                >
                    Ревизии ({filteredAudits.length})
                </button>
                <button
                    onClick={() => setActiveTab("transactions")}
                    className={`px-6 py-3 rounded-xl text-xs font-black tracking-widest uppercase transition-all whitespace-nowrap ${activeTab === "transactions"
                        ? "bg-indigo-600 text-white shadow-lg shadow-indigo-500/20"
                        : "bg-slate-900 text-slate-400 hover:bg-slate-800"
                        }`}
                >
                    Транзакции ({filteredTransactions.length})
                </button>
            </div>

            {/* Audits Tab */}
            {activeTab === "audits" && (
                <div className="space-y-4">
                    {filteredAudits.length === 0 ? (
                        <div className="text-center py-20 text-slate-600 font-bold uppercase tracking-widest">
                            Нет отчётов за выбранный период
                        </div>
                    ) : (
                        filteredAudits.map(audit => {
                            const isExpanded = expandedAudit === audit.id
                            const shortages = audit.items.filter(i => (i.discrepancy ?? 0) < 0)
                            const surpluses = audit.items.filter(i => (i.discrepancy ?? 0) > 0)
                            const shortageValue = shortages.reduce((sum, i) => sum + (i.discrepancy * i.product.sellPrice), 0)
                            const surplusValue = surpluses.reduce((sum, i) => sum + (i.discrepancy * i.product.sellPrice), 0)

                            return (
                                <div key={audit.id} className="bg-slate-900/50 border border-slate-800 rounded-2xl overflow-hidden">
                                    {/* Audit Header */}
                                    <div
                                        className="p-4 md:p-5 flex flex-col sm:flex-row sm:items-center justify-between gap-4 cursor-pointer hover:bg-slate-900 transition-colors"
                                        onClick={() => setExpandedAudit(isExpanded ? null : audit.id)}
                                    >
                                        <div className="flex items-center gap-4">
                                            <div className={`w-12 h-12 rounded-xl flex items-center justify-center text-lg font-black shrink-0 ${audit.status === "APPLIED"
                                                ? "bg-emerald-500/10 text-emerald-400"
                                                : "bg-amber-500/10 text-amber-400"
                                                }`}>
                                                {audit.status === "APPLIED" ? "OK" : "..."}
                                            </div>
                                            <div>
                                                <div className="flex items-center gap-3">
                                                    <p className="text-base font-bold text-white">{formatDate(audit.completedAt)}</p>
                                                    <span className={`px-2.5 py-1 rounded-lg text-[10px] font-black uppercase ${audit.status === "APPLIED"
                                                        ? "bg-emerald-500/10 text-emerald-400 border border-emerald-500/20"
                                                        : "bg-amber-500/10 text-amber-400 border border-amber-500/20"
                                                        }`}>
                                                        {audit.status === "APPLIED" ? "Применено" : "Ожидает"}
                                                    </span>
                                                </div>
                                                <p className="text-xs text-slate-500 mt-1">{audit.items.length} позиций проверено</p>
                                            </div>
                                        </div>
                                        <div className="flex items-center justify-between sm:justify-end gap-6 w-full sm:w-auto mt-2 sm:mt-0 pl-16 sm:pl-0">
                                            <div className="text-left sm:text-right">
                                                <span className="text-[9px] text-slate-600 font-bold uppercase block">Итого</span>
                                                <span className={`text-xl font-black ${audit.totalDiscrepancyValue < 0 ? "text-red-500" : audit.totalDiscrepancyValue > 0 ? "text-emerald-500" : "text-slate-500"}`}>
                                                    {audit.totalDiscrepancyValue > 0 ? "+" : ""}{audit.totalDiscrepancyValue?.toLocaleString()} сом
                                                </span>
                                            </div>
                                            <div className={`w-8 h-8 rounded-lg bg-slate-800 flex items-center justify-center text-slate-500 transition-transform ${isExpanded ? "rotate-180" : ""}`}>
                                                <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" /></svg>
                                            </div>
                                        </div>
                                    </div>

                                    {/* Expanded Content */}
                                    {isExpanded && (
                                        <div className="border-t border-slate-800 p-4 md:p-5 bg-slate-950/50 space-y-5">
                                            {/* Summary Cards */}
                                            <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                                                <div className="bg-red-500/10 border border-red-500/20 rounded-xl p-4">
                                                    <span className="text-[10px] text-red-400 font-black uppercase tracking-widest">Недостача</span>
                                                    <p className="text-xl font-black text-red-500 mt-1">{shortageValue.toLocaleString()} сом</p>
                                                    <p className="text-xs text-red-400/60 mt-1">{shortages.length} позиций</p>
                                                </div>
                                                <div className="bg-emerald-500/10 border border-emerald-500/20 rounded-xl p-4">
                                                    <span className="text-[10px] text-emerald-400 font-black uppercase tracking-widest">Излишки</span>
                                                    <p className="text-xl font-black text-emerald-500 mt-1">+{surplusValue.toLocaleString()} сом</p>
                                                    <p className="text-xs text-emerald-400/60 mt-1">{surpluses.length} позиций</p>
                                                </div>
                                                <div className="bg-slate-800/50 border border-slate-700 rounded-xl p-4">
                                                    <span className="text-[10px] text-slate-400 font-black uppercase tracking-widest">Без изменений</span>
                                                    <p className="text-xl font-black text-slate-300 mt-1">{audit.items.length - shortages.length - surpluses.length}</p>
                                                    <p className="text-xs text-slate-500 mt-1">позиций совпало</p>
                                                </div>
                                            </div>

                                            {/* Items with Discrepancies */}
                                            {(shortages.length > 0 || surpluses.length > 0) && (
                                                <div className="space-y-3">
                                                    <h4 className="text-xs font-black text-slate-400 uppercase tracking-widest">Расхождения</h4>
                                                    <div className="max-h-64 overflow-y-auto space-y-2 pr-1 custom-scrollbar">
                                                        {[...shortages, ...surpluses].map(item => (
                                                            <div key={item.productId} className="flex flex-col sm:flex-row sm:items-center justify-between py-3 px-4 bg-slate-900 rounded-xl gap-3">
                                                                <div className="flex-1 min-w-0">
                                                                    <p className="font-bold text-white truncate text-sm">{item.product.name}</p>
                                                                    <p className="text-[10px] text-slate-600 font-mono">{item.product.barcode}</p>
                                                                </div>
                                                                <div className="flex items-center justify-between sm:justify-end gap-6 shrink-0 bg-slate-950/50 p-2 sm:p-0 rounded-lg">
                                                                    <div className="text-center">
                                                                        <span className="text-[9px] text-slate-600 block">Ожид.</span>
                                                                        <span className="text-sm font-bold text-slate-400">{item.expectedQty}</span>
                                                                    </div>
                                                                    <span className="text-slate-600">→</span>
                                                                    <div className="text-center">
                                                                        <span className="text-[9px] text-slate-600 block">Факт</span>
                                                                        <span className="text-sm font-bold text-white">{item.actualQty}</span>
                                                                    </div>
                                                                    <div className="w-20 text-right">
                                                                        <span className={`text-base font-black ${item.discrepancy < 0 ? "text-red-500" : "text-emerald-500"}`}>
                                                                            {item.discrepancy > 0 ? "+" : ""}{item.discrepancy}
                                                                        </span>
                                                                    </div>
                                                                </div>
                                                            </div>
                                                        ))}
                                                    </div>
                                                </div>
                                            )}

                                            {/* Action Buttons */}
                                            <div className="flex flex-col sm:flex-row gap-3 pt-2">
                                                {audit.status === "SAVED" && (
                                                    <button
                                                        onClick={(e) => { e.stopPropagation(); applyStock(audit.id) }}
                                                        disabled={applyingStock === audit.id}
                                                        className="flex-1 py-4 bg-indigo-600 hover:bg-indigo-500 disabled:opacity-50 text-white text-xs font-black tracking-widest uppercase rounded-xl transition-all shadow-lg shadow-indigo-500/20"
                                                    >
                                                        {applyingStock === audit.id ? "Применение..." : "Обновить Склад"}
                                                    </button>
                                                )}
                                                <button
                                                    onClick={(e) => { e.stopPropagation(); deleteAudit(audit.id) }}
                                                    className="px-6 py-4 bg-red-500/10 hover:bg-red-500/20 text-red-400 text-xs font-black tracking-widest uppercase rounded-xl transition-all border border-red-500/20 w-full sm:w-auto"
                                                >
                                                    Удалить
                                                </button>
                                            </div>

                                            {audit.status === "APPLIED" && (
                                                <div className="text-center py-2 text-emerald-500 font-bold text-sm">
                                                    Склад был обновлён по результатам этой ревизии
                                                </div>
                                            )}
                                        </div>
                                    )}
                                </div>
                            )
                        })
                    )}
                </div>
            )}

            {/* Transactions Tab */}
            {activeTab === "transactions" && (
                <div className="space-y-4">
                    {/* Transaction Filters */}
                    <div className="flex gap-2 flex-wrap">
                        {[
                            { value: "ALL", label: "Все" },
                            { value: "SALE", label: "Продажи" },
                            { value: "RESTOCK", label: "Приход" },
                            { value: "TRANSFER_IN", label: "Входящие" },
                            { value: "TRANSFER_OUT", label: "Исходящие" },
                            { value: "ADJUSTMENT", label: "Корректировки" },
                        ].map(f => (
                            <button
                                key={f.value}
                                onClick={() => setFilter(f.value)}
                                className={`px-4 py-2 rounded-xl text-xs font-black tracking-widest uppercase transition-all ${filter === f.value
                                    ? "bg-indigo-600 text-white shadow-lg shadow-indigo-500/20"
                                    : "bg-slate-900 text-slate-500 hover:bg-slate-800"
                                    }`}
                            >
                                {f.label}
                            </button>
                        ))}
                    </div>

                    {/* Transaction List */}
                    <div className="space-y-2">
                        {filteredTransactions.length === 0 ? (
                            <div className="text-center py-20 text-slate-600 font-bold uppercase tracking-widest">
                                Нет транзакций за выбранный период
                            </div>
                        ) : (
                            filteredTransactions.map(tx => {
                                const style = getTypeStyle(tx.type)
                                return (
                                    <div key={tx.id} className="bg-slate-900/50 border border-slate-800 rounded-xl p-4 flex flex-col sm:flex-row sm:items-center justify-between gap-3 sm:gap-0">
                                        <div className="flex items-center gap-4">
                                            <span className={`px-3 py-1.5 rounded-lg text-[10px] font-black uppercase ${style.bg} ${style.color} border ${style.border}`}>
                                                {style.label}
                                            </span>
                                            <div>
                                                <p className="font-bold text-white text-sm sm:text-base">{tx.product.name}</p>
                                                <p className="text-[10px] text-slate-500">{formatTime(tx.createdAt)}</p>
                                            </div>
                                        </div>
                                        <div className="flex items-center justify-between sm:justify-end gap-4 sm:gap-6 pl-12 sm:pl-0">
                                            {tx.note && <span className="text-xs text-slate-500 truncate max-w-[100px] hidden sm:block">{tx.note}</span>}
                                            <div className="text-right">
                                                <span className={`text-lg font-black ${tx.quantityChange > 0 ? "text-emerald-500" : "text-red-500"}`}>
                                                    {tx.quantityChange > 0 ? "+" : ""}{tx.quantityChange}
                                                </span>
                                                {tx.type === "SALE" && (
                                                    <p className="text-xs text-slate-400 font-bold">
                                                        {(Math.abs(tx.quantityChange) * (tx.snapshotPrice ?? tx.product.sellPrice)).toLocaleString()} сом
                                                    </p>
                                                )}
                                            </div>
                                        </div>
                                    </div>
                                )
                            })
                        )}
                    </div>
                </div>
            )}

            <div className="h-10" />
        </div>
    )
}
