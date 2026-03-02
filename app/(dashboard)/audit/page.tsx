"use client"

import { useState, useEffect } from "react"
import { toast } from "sonner"
import { useBarcodeScanner } from "@/lib/useBarcodeScanner"

interface Product {
    id: string
    name: string
    barcode: string
    sellPrice: number
}

interface AuditItem {
    id?: string
    productId: string
    product: Product
    expectedQty: number
    actualQty: number | null
    discrepancy: number | null
}

interface Audit {
    id: string
    status: string
    startedAt: string
    items: AuditItem[]
    completedAt: string | null
    totalDiscrepancyValue: number | null
}

export default function AuditPage() {
    const [currentAudit, setCurrentAudit] = useState<Audit | null>(null)
    const [drafts, setDrafts] = useState<Audit[]>([])
    const [loading, setLoading] = useState(true)
    const [saving, setSaving] = useState(false)
    const [searchQuery, setSearchQuery] = useState("")
    const [showSelection, setShowSelection] = useState(false)

    useEffect(() => {
        fetchInitialData()
    }, [])

    // Barcode scanner: auto-find item and focus its input
    useBarcodeScanner({
        onScan: (barcode) => {
            if (!currentAudit) return
            const item = currentAudit.items.find(i => i.product.barcode === barcode)
            if (item) {
                setSearchQuery(barcode)
                toast.success(`📷 ${item.product.name}`)
                setTimeout(() => {
                    const input = document.querySelector(`[data-barcode="${barcode}"]`) as HTMLInputElement
                    if (input) {
                        input.focus()
                        input.select()
                    }
                }, 100)
            } else {
                toast.error(`Товар ${barcode} не найден в ревизии`)
            }
        }
    })

    const fetchInitialData = async () => {
        setLoading(true)
        try {
            // check for IN_PROGRESS audit
            const currentRes = await fetch("/api/audit?current=true").then(r => r.json())

            if (currentRes && currentRes.id && currentRes.items && currentRes.items.length > 0) {
                // Has an active audit with items — go straight to it
                setCurrentAudit(currentRes)
                setShowSelection(false)
            } else {
                // Clean up empty audits
                if (currentRes && currentRes.id && (!currentRes.items || currentRes.items.length === 0)) {
                    await fetch(`/api/audit?id=${currentRes.id}`, { method: "DELETE" })
                }
                // Show selection screen
                await fetchDrafts()
                setShowSelection(true)
            }
        } catch (e) {
            toast.error("Ошибка загрузки данных")
            setShowSelection(true)
        } finally {
            setLoading(false)
        }
    }

    const fetchDrafts = async () => {
        try {
            const res = await fetch("/api/audit?drafts=true").then(r => r.json())
            if (Array.isArray(res)) {
                setDrafts(res)
            }
        } catch (e) {
            // ignore
        }
    }

    const handleStartNew = async () => {
        setLoading(true)
        try {
            const startRes = await fetch("/api/audit", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ action: "START" })
            })
            if (startRes.ok) {
                const newAudit = await fetch("/api/audit?current=true").then(r => r.json())
                if (newAudit && newAudit.id) {
                    setCurrentAudit(newAudit)
                    setShowSelection(false)
                }
            } else {
                const err = await startRes.json()
                toast.error(err.error || "Не удалось создать ревизию")
            }
        } catch (e) {
            toast.error("Ошибка сети")
        } finally {
            setLoading(false)
        }
    }

    const handleContinueDraft = async (auditId: string) => {
        setLoading(true)
        try {
            // Reopen the draft — set status back to IN_PROGRESS
            const res = await fetch("/api/audit", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ action: "REOPEN", auditId })
            })
            if (res.ok) {
                const audit = await fetch("/api/audit?current=true").then(r => r.json())
                if (audit && audit.id) {
                    setCurrentAudit(audit)
                    setShowSelection(false)
                }
            } else {
                const err = await res.json()
                toast.error(err.error || "Не удалось открыть черновик")
            }
        } catch (e) {
            toast.error("Ошибка сети")
        } finally {
            setLoading(false)
        }
    }

    const handleDeleteDraft = async (auditId: string) => {
        if (!confirm("Удалить этот черновик ревизии?")) return
        try {
            await fetch(`/api/audit?id=${auditId}`, { method: "DELETE" })
            setDrafts(prev => prev.filter(d => d.id !== auditId))
            toast.success("Черновик удален")
        } catch (e) {
            toast.error("Ошибка удаления")
        }
    }

    const handleBackToSelection = async () => {
        // Save current as draft and pause it
        if (currentAudit) {
            await saveDraft(true)
            // Set status to DRAFT so it appears in drafts list
            await fetch("/api/audit", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ action: "PAUSE", auditId: currentAudit.id })
            })
        }
        setCurrentAudit(null)
        setShowSelection(true)
        setSearchQuery("")
        setLoading(true)
        await fetchDrafts()
        setLoading(false)
    }

    const saveDraft = async (silent = false) => {
        if (!currentAudit) return
        setSaving(true)
        try {
            const res = await fetch("/api/audit", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                    action: "SAVE",
                    auditId: currentAudit.id,
                    items: currentAudit.items.map(i => ({
                        productId: i.productId,
                        actualQty: i.actualQty,
                        expectedQty: i.expectedQty
                    }))
                })
            })
            if (res.ok) {
                if (!silent) toast.success("Черновик сохранен 💾")
            } else {
                toast.error("Ошибка сохранения")
            }
        } catch (e) {
            toast.error("Ошибка сети")
        } finally {
            setSaving(false)
        }
    }

    const saveReport = async () => {
        if (!currentAudit) return
        if (currentAudit.items.some(i => i.actualQty === null)) {
            toast.error("Заполните все позиции!")
            return
        }
        if (!confirm("Сохранить отчет ревизии? (Склад НЕ обновится автоматически)")) return

        setSaving(true)
        try {
            // First save the draft data to database
            const saveRes = await fetch("/api/audit", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                    action: "SAVE",
                    auditId: currentAudit.id,
                    items: currentAudit.items.map(i => ({
                        productId: i.productId,
                        actualQty: i.actualQty,
                        expectedQty: i.expectedQty
                    }))
                })
            })

            if (!saveRes.ok) {
                toast.error("Ошибка сохранения данных")
                return
            }

            // Then create the report
            const res = await fetch("/api/audit", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                    action: "SAVE_REPORT",
                    auditId: currentAudit.id
                })
            })
            if (res.ok) {
                toast.success("Отчет сохранен! Перейдите в раздел 'Отчеты' чтобы применить к складу 📊")
                setCurrentAudit(null)
                setTimeout(() => {
                    window.location.href = "/reports"
                }, 1500)
            } else {
                const data = await res.json()
                toast.error(data.error || "Ошибка сохранения")
            }
        } catch (e) {
            toast.error("Ошибка сети")
        } finally {
            setSaving(false)
        }
    }

    const updateItemQty = (productId: string, val: string) => {
        if (!currentAudit) return
        const newQty = val === "" ? null : parseInt(val)
        setCurrentAudit({
            ...currentAudit,
            items: currentAudit.items.map(item =>
                item.productId === productId
                    ? { ...item, actualQty: newQty, discrepancy: newQty !== null ? newQty - item.expectedQty : null }
                    : item
            )
        })
    }

    const filteredItems = currentAudit?.items.filter(item =>
        item.product.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
        item.product.barcode.includes(searchQuery)
    ) || []

    const progressCount = currentAudit?.items.filter(i => i.actualQty !== null).length || 0
    const totalCount = currentAudit?.items.length || 0
    const progressPercent = totalCount > 0 ? Math.round((progressCount / totalCount) * 100) : 0

    const totalLossGain = currentAudit?.items.reduce((acc, item) => {
        if (item.actualQty === null) return acc
        const diff = item.actualQty - item.expectedQty
        return acc + (diff * item.product.sellPrice)
    }, 0) || 0

    // --- LOADING ---
    if (loading) return (
        <div className="flex items-center justify-center h-[calc(100vh-5rem)] bg-slate-950 text-slate-500 font-black tracking-widest uppercase">
            Загрузка...
        </div>
    )

    // --- SELECTION SCREEN ---
    if (showSelection && !currentAudit) {
        const formatDate = (dateStr: string) => {
            const d = new Date(dateStr)
            return d.toLocaleDateString("ru-RU", { day: "2-digit", month: "2-digit", year: "2-digit" }) + " " +
                d.toLocaleTimeString("ru-RU", { hour: "2-digit", minute: "2-digit" })
        }

        return (
            <div className="flex flex-col h-[calc(100vh-5rem)] bg-slate-950 overflow-hidden font-sans">
                <div className="flex-1 overflow-y-auto p-4 md:p-8">
                    <div className="max-w-2xl mx-auto">
                        {/* Header */}
                        <div className="mb-8 md:mb-12">
                            <span className="text-[10px] font-black text-indigo-500 uppercase tracking-[0.3em] block mb-2">Ревизия</span>
                            <h1 className="text-2xl md:text-3xl font-black text-white tracking-tight uppercase">Askep Inventory</h1>
                            <p className="text-sm text-slate-500 mt-2">Выберите действие для начала работы</p>
                        </div>

                        {/* New Audit Button */}
                        <button
                            onClick={handleStartNew}
                            className="w-full group relative p-6 md:p-8 rounded-2xl border-2 border-dashed border-indigo-500/30 hover:border-indigo-500/60 bg-indigo-500/5 hover:bg-indigo-500/10 transition-all duration-300 mb-6"
                        >
                            <div className="flex items-center gap-4 md:gap-6">
                                <div className="w-14 h-14 md:w-16 md:h-16 rounded-2xl bg-indigo-500/10 border border-indigo-500/20 flex items-center justify-center shrink-0 group-hover:scale-110 transition-transform duration-300">
                                    <svg className="w-7 h-7 md:w-8 md:h-8 text-indigo-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
                                    </svg>
                                </div>
                                <div className="text-left">
                                    <h2 className="text-lg md:text-xl font-black text-white uppercase tracking-tight">Новая ревизия</h2>
                                    <p className="text-xs md:text-sm text-slate-500 mt-1">Создать снимок текущих остатков и начать подсчёт</p>
                                </div>
                                <svg className="w-5 h-5 text-slate-600 ml-auto shrink-0 group-hover:text-indigo-500 group-hover:translate-x-1 transition-all" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M9 5l7 7-7 7" />
                                </svg>
                            </div>
                        </button>

                        {/* Drafts Section */}
                        {drafts.length > 0 && (
                            <div>
                                <div className="flex items-center gap-3 mb-4">
                                    <span className="text-[10px] font-black text-slate-500 uppercase tracking-[0.3em]">Сохранённые черновики</span>
                                    <div className="h-px flex-1 bg-slate-800/50" />
                                    <span className="text-[10px] font-bold text-slate-600 tabular-nums">{drafts.length}</span>
                                </div>

                                <div className="space-y-3">
                                    {drafts.map(draft => {
                                        const filled = draft.items.filter(i => i.actualQty !== null).length
                                        const total = draft.items.length
                                        const pct = total > 0 ? Math.round((filled / total) * 100) : 0

                                        return (
                                            <div
                                                key={draft.id}
                                                className="group p-4 md:p-5 rounded-2xl border border-slate-800/60 bg-slate-900/50 hover:bg-slate-900 hover:border-slate-700 transition-all duration-200"
                                            >
                                                <div className="flex items-center gap-4">
                                                    {/* Icon */}
                                                    <div className="w-11 h-11 rounded-xl bg-amber-500/10 border border-amber-500/20 flex items-center justify-center shrink-0">
                                                        <svg className="w-5 h-5 text-amber-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                                                        </svg>
                                                    </div>

                                                    {/* Info */}
                                                    <div className="flex-1 min-w-0">
                                                        <div className="flex items-center gap-2 mb-1">
                                                            <span className="text-sm font-black text-white uppercase tracking-tight">#{draft.id.slice(-4).toUpperCase()}</span>
                                                            <span className="px-1.5 py-0.5 bg-amber-500/10 text-amber-500 border border-amber-500/10 rounded text-[8px] font-black uppercase tracking-wider">Черновик</span>
                                                        </div>
                                                        <div className="flex items-center gap-3 text-[10px] text-slate-500">
                                                            <span className="font-bold">{formatDate(draft.startedAt)}</span>
                                                            <span className="font-black tabular-nums text-slate-400">{filled}/{total} <span className="text-slate-600">позиций</span></span>
                                                        </div>
                                                        {/* Progress bar */}
                                                        <div className="mt-2 h-1 w-full max-w-[200px] bg-slate-800 rounded-full overflow-hidden">
                                                            <div className="h-full bg-amber-500/70 transition-all" style={{ width: `${pct}%` }} />
                                                        </div>
                                                    </div>

                                                    {/* Actions */}
                                                    <div className="flex items-center gap-2 shrink-0">
                                                        <button
                                                            onClick={() => handleDeleteDraft(draft.id)}
                                                            className="p-2.5 rounded-xl text-slate-600 hover:text-red-400 hover:bg-red-500/10 transition-all"
                                                            title="Удалить"
                                                        >
                                                            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                                                            </svg>
                                                        </button>
                                                        <button
                                                            onClick={() => handleContinueDraft(draft.id)}
                                                            className="px-5 py-2.5 rounded-xl bg-amber-500/10 hover:bg-amber-500/20 text-amber-500 text-xs font-black uppercase tracking-widest border border-amber-500/20 hover:border-amber-500/30 transition-all"
                                                        >
                                                            Продолжить
                                                        </button>
                                                    </div>
                                                </div>
                                            </div>
                                        )
                                    })}
                                </div>
                            </div>
                        )}
                    </div>
                </div>
            </div>
        )
    }

    if (!currentAudit) return (
        <div className="flex items-center justify-center h-[calc(100vh-5rem)] bg-slate-950 text-slate-500 font-black tracking-widest uppercase">
            Инициализация ревизии...
        </div>
    )

    // --- MAIN AUDIT PROCESS ---
    return (
        <div className="flex flex-col h-[calc(100vh-5rem)] bg-slate-950 overflow-hidden font-sans">
            {/* STICKY HEADER */}
            <header className="shrink-0 p-4 md:p-6 border-b border-slate-800/50 bg-slate-950/80 backdrop-blur-md z-50">
                <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4 md:gap-6">
                    <div className="flex-1 w-full md:w-auto">
                        <div className="flex items-center justify-between md:justify-start gap-3 mb-1">
                            <div className="flex items-center gap-3">
                                {/* Back button */}
                                <button
                                    onClick={handleBackToSelection}
                                    className="p-1.5 rounded-lg text-slate-500 hover:text-white hover:bg-slate-800 transition-all"
                                    title="Назад к выбору"
                                >
                                    <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M15 19l-7-7 7-7" />
                                    </svg>
                                </button>
                                <span className="px-2 py-0.5 bg-indigo-500/10 text-indigo-500 border border-indigo-500/10 rounded text-[9px] font-black uppercase tracking-widest">В процессе</span>
                                <span className="text-[10px] text-slate-500 font-bold uppercase tracking-wider">Ревизия #{currentAudit!.id.slice(-4).toUpperCase()}</span>
                            </div>
                            {/* Mobile Only: Total Diff in Header Top */}
                            <div className={`md:hidden text-sm font-black tracking-tighter ${totalLossGain < 0 ? "text-red-500" : "text-emerald-500"}`}>
                                {totalLossGain > 0 ? "+" : ""}{totalLossGain.toLocaleString()}
                            </div>
                        </div>
                        <h1 className="text-xl md:text-2xl font-black text-white tracking-tight uppercase mb-4 md:mb-0">Askep Inventory</h1>

                        <div className="mt-2 md:mt-4 flex items-center gap-4">
                            <div className="h-1.5 flex-1 max-w-[300px] bg-slate-900 rounded-full overflow-hidden">
                                <div className="h-full bg-indigo-500 transition-all duration-500 shadow-[0_0_10px_rgba(99,102,241,0.5)]" style={{ width: `${progressPercent}%` }} />
                            </div>
                            <span className="text-[10px] font-black text-white tabular-nums tracking-widest">{progressCount} / {totalCount} <span className="text-slate-600 font-bold">ПОЗИЦИЙ</span></span>
                        </div>
                    </div>

                    <div className="hidden md:flex flex-col items-end gap-2">
                        <span className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Текущая разница</span>
                        <div className={`text-2xl font-black tracking-tighter ${totalLossGain < 0 ? "text-red-500" : "text-emerald-500"}`}>
                            {totalLossGain > 0 ? "+" : ""}{totalLossGain.toLocaleString()} <span className="text-xs font-bold opacity-50">СОМ</span>
                        </div>
                    </div>

                    <div className="flex gap-3 w-full md:w-auto">
                        <button
                            onClick={() => saveDraft()}
                            disabled={saving}
                            className="flex-1 md:flex-none px-6 py-3 bg-slate-900 hover:bg-slate-800 text-slate-300 text-xs font-black tracking-widest uppercase rounded-xl border border-slate-800 transition-all flex items-center justify-center gap-2"
                        >
                            {saving ? "..." : "Черновик"}
                            <svg className="hidden md:block w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={3} d="M8 7H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-3m-1 4l-3 3m0 0l-3-3m3 3V4" /></svg>
                        </button>
                        <button
                            onClick={saveReport}
                            disabled={saving || progressCount < totalCount}
                            className="flex-[2] md:flex-none px-8 py-3 bg-emerald-600 hover:bg-emerald-500 disabled:opacity-30 disabled:grayscale text-white text-xs font-black tracking-[0.2em] uppercase rounded-xl transition-all shadow-lg shadow-emerald-500/20 flex items-center justify-center gap-2"
                        >
                            Сохранить
                            <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={3} d="M5 13l4 4L19 7" /></svg>
                        </button>
                    </div>
                </div>
            </header>

            {/* SEARCH AREA */}
            <div className="shrink-0 p-4 md:p-6 bg-slate-950">
                <div className="relative group">
                    <input
                        type="text"
                        value={searchQuery}
                        onChange={e => setSearchQuery(e.target.value)}
                        placeholder="СКАНИРУЙТЕ БАРКОД..."
                        className="w-full bg-slate-900/50 border border-slate-800/60 rounded-xl md:rounded-2xl px-4 md:px-6 py-4 md:py-5 text-base md:text-lg font-bold text-white placeholder:text-slate-700 outline-none focus:border-indigo-500/50 focus:ring-4 focus:ring-indigo-500/10 transition-all group-hover:bg-slate-900 group-hover:border-slate-700 uppercase tracking-widest text-center"
                        autoFocus
                    />
                    {searchQuery && (
                        <button onClick={() => setSearchQuery("")} className="absolute right-4 md:right-6 top-1/2 -translate-y-1/2 text-slate-600 hover:text-white transition-colors">✕</button>
                    )}
                </div>
            </div>

            {/* LIST AREA */}
            <div className="flex-1 overflow-y-auto p-4 md:p-6 pt-0 space-y-3 custom-scrollbar pb-24">
                {filteredItems.map(item => {
                    const isCompleted = item.actualQty !== null
                    return (
                        <div
                            key={item.productId}
                            className={`p-4 md:p-6 rounded-2xl border transition-all duration-300 transform ${isCompleted
                                ? "bg-slate-900/30 border-slate-800/40 opacity-70 scale-[0.98]"
                                : "bg-slate-900 border-slate-800 shadow-lg hover:border-indigo-500/30 active:scale-[0.99]"
                                }`}
                        >
                            <div className="flex flex-col lg:flex-row lg:items-center gap-4 md:gap-6">
                                {/* INFO */}
                                <div className="flex-1 min-w-0">
                                    <h3 className="text-sm md:text-base font-bold text-white uppercase tracking-tight truncate">{item.product.name}</h3>
                                    <div className="flex items-center gap-3 mt-2">
                                        <span className="text-[10px] md:text-xs font-mono text-slate-400 bg-slate-950 px-2 md:px-3 py-1 rounded-lg border border-slate-800">{item.product.barcode}</span>
                                        <span className="text-[10px] md:text-xs font-bold text-slate-500">{item.product.sellPrice.toLocaleString()} сом/шт</span>
                                    </div>
                                </div>

                                {/* VALUES ROW */}
                                <div className="flex items-center justify-between md:justify-start gap-2 md:gap-6 shrink-0 bg-slate-950/30 md:bg-transparent p-3 md:p-0 rounded-xl">
                                    {/* EXPECTED */}
                                    <div className="text-center w-16 md:w-20">
                                        <span className="text-[9px] md:text-[10px] font-bold text-slate-500 uppercase block mb-1">План</span>
                                        <p className="text-lg md:text-2xl font-black text-slate-300 tabular-nums">{item.expectedQty}</p>
                                    </div>

                                    {/* ARROW */}
                                    <span className="text-slate-700 text-lg md:text-xl">→</span>

                                    {/* INPUT */}
                                    <div className="text-center group-focus-within:text-indigo-500">
                                        <span className="text-[9px] md:text-[10px] font-bold text-slate-500 uppercase block mb-1 group-focus-within:text-indigo-400 transition-colors">Факт</span>
                                        <input
                                            type="number"
                                            value={item.actualQty ?? ""}
                                            onChange={e => updateItemQty(item.productId, e.target.value)}
                                            placeholder="—"
                                            data-barcode={item.product.barcode}
                                            className={`w-20 md:w-24 text-center text-xl md:text-2xl font-black py-2 rounded-xl border transition-all outline-none ${isCompleted
                                                ? "bg-slate-900 border-slate-800 text-white"
                                                : "bg-slate-950 border-indigo-500/50 text-white focus:border-indigo-500 focus:ring-4 focus:ring-indigo-500/10"
                                                }`}
                                        />
                                    </div>

                                    {/* EQUALS */}
                                    <span className="hidden md:inline text-slate-700 text-xl">=</span>

                                    {/* DISCREPANCY */}
                                    <div className="text-center w-20 md:w-28 pl-2 md:pl-0 border-l border-slate-800 md:border-l-0">
                                        <span className="text-[9px] md:text-[10px] font-bold text-slate-500 uppercase block mb-1">Разница</span>
                                        {item.actualQty !== null ? (
                                            <div>
                                                <p className={`text-lg md:text-2xl font-black tabular-nums ${item.discrepancy === 0 ? "text-slate-500" : item.discrepancy! < 0 ? "text-red-500" : "text-emerald-500"}`}>
                                                    {item.discrepancy! > 0 ? "+" : ""}{item.discrepancy}
                                                </p>
                                                <span className={`text-[10px] md:text-xs font-bold ${item.discrepancy! < 0 ? "text-red-400/60" : item.discrepancy! > 0 ? "text-emerald-400/60" : "text-slate-600"}`}>
                                                    {(item.discrepancy! * item.product.sellPrice).toLocaleString()}
                                                </span>
                                            </div>
                                        ) : (
                                            <p className="text-lg md:text-2xl font-black text-slate-700">—</p>
                                        )}
                                    </div>
                                </div>
                            </div>
                        </div>
                    )
                })}

                {filteredItems.length === 0 && (
                    <div className="py-20 text-center">
                        <p className="text-xs font-black text-slate-700 uppercase tracking-[0.3em]">Товары не найдены</p>
                    </div>
                )}
            </div>

            {/* BOTTOM BAR SAFE ZONE */}
            <div className="h-6 shrink-0 bg-slate-950 border-t border-slate-800/20" />
        </div>
    )
}
