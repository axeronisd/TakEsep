"use client"

import { useState, useEffect } from "react"
import { useAnalytics } from "@/lib/hooks"
import { toast } from "sonner"


type TimePeriod = "today" | "yesterday" | "week" | "month" | "all" | "custom"

interface AnalyticsData {
    period: string
    dateRange: { start: string, end: string }
    kpis: {
        revenue: number
        repairRevenue: number
        totalRevenue: number
        cogs: number
        grossProfit: number
        salaryExpenses: number
        otherExpenses: number
        auditLosses: number
        netProfit: number
        margin: number
        grossMargin: number

        inventoryValue: number
        inventoryCost: number
        totalSKUs: number
        lowStockItems: number

        avgTransactionValue: number
        totalSales: number
    }
    transactionCounts: {
        sales: number
        restocks: number
        transfersIn: number
        transfersOut: number
        adjustments: number
        repairs: number
        expenses: number
    }
    topProducts: { name: string; barcode: string; quantity: number; revenue: number; cost: number; profit: number; margin: number }[]
    slowMoving: { name: string; barcode: string; quantity: number; value: number }[]
    lowStockList: { name: string; barcode: string; quantity: number; sellPrice: number }[]
}

// Detail Modal Component
const DetailModal = ({
    isOpen,
    onClose,
    title,
    type,
    startDate,
    endDate
}: {
    isOpen: boolean,
    onClose: () => void,
    title: string,
    type: 'REPAIR' | 'EXPENSE' | 'SALARY' | 'SALE' | 'PROFIT',
    startDate: Date | null,
    endDate: Date | null
}) => {
    const [data, setData] = useState<any[]>([])
    const [loading, setLoading] = useState(false)
    const [isDeleting, setIsDeleting] = useState<string | null>(null)

    const handleDelete = async (id: string) => {
        if (!confirm('Вы уверены, что хотите удалить эту выплату?')) return

        setIsDeleting(id)
        try {
            const res = await fetch(`/api/finance?id=${id}`, { method: 'DELETE' })
            if (!res.ok) throw new Error('Ошибка удаления')

            setData(prev => prev.filter(item => item.id !== id))
            toast.success('Выплата удалена')
        } catch (error) {
            toast.error('Не удалось удалить выплату')
        } finally {
            setIsDeleting(null)
        }
    }

    useEffect(() => {
        if (!isOpen) return

        setLoading(true)
        const params = new URLSearchParams()
        if (startDate) params.append("startDate", startDate.toISOString())
        if (endDate) params.append("endDate", endDate.toISOString())

        let url = ""
        if (type === 'SALE') {
            url = `/api/transactions?type=SALE&${params}`
        } else if (type === 'PROFIT') {
            // For profit, just show sales for now as a proxy or main driver
            url = `/api/transactions?type=SALE&${params}`
        } else {
            url = `/api/finance?type=${type}&${params}`
        }

        fetch(url)
            .then(res => res.json())
            .then(res => {
                if (Array.isArray(res)) setData(res)
            })
            .finally(() => setLoading(false))

    }, [isOpen, type, startDate, endDate])

    if (!isOpen) return null

    return (
        <div className="fixed inset-0 bg-black/80 backdrop-blur-sm z-[100] flex items-center justify-center p-4" onClick={onClose}>
            <div className="bg-slate-900 border border-slate-700 rounded-3xl w-full max-w-2xl max-h-[80vh] flex flex-col shadow-2xl animate-in fade-in zoom-in-95 duration-200" onClick={e => e.stopPropagation()}>
                <div className="p-6 border-b border-slate-800 flex justify-between items-center bg-slate-900/50">
                    <h3 className="text-xl font-black text-white uppercase">{title}</h3>
                    <button onClick={onClose} className="p-2 hover:bg-slate-800 rounded-full text-slate-400 hover:text-white transition-colors">
                        <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" /></svg>
                    </button>
                </div>

                <div className="flex-1 overflow-y-auto p-0 custom-scrollbar">
                    {loading ? (
                        <div className="p-10 text-center text-slate-500 font-bold uppercase tracking-widest animate-pulse">Загрузка...</div>
                    ) : data.length === 0 ? (
                        <div className="p-10 text-center text-slate-500 font-bold uppercase tracking-widest">Нет данных за период</div>
                    ) : (
                        <table className="w-full text-left border-collapse">
                            <thead className="bg-slate-950/50 sticky top-0 backdrop-blur-md">
                                <tr>
                                    <th className="p-4 text-[10px] font-black uppercase text-slate-500 tracking-widest">Дата</th>
                                    <th className="p-4 text-[10px] font-black uppercase text-slate-500 tracking-widest">Описание / Товар</th>
                                    <th className="p-4 text-[10px] font-black uppercase text-slate-500 tracking-widest text-right">Сумма</th>
                                </tr>
                            </thead>
                            <tbody className="divide-y divide-slate-800">
                                {data.map((item) => {
                                    const isFinance = 'amount' in item
                                    const date = new Date(item.createdAt).toLocaleString('ru-RU', {
                                        day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit'
                                    })

                                    // Finance logic
                                    let desc = item.description || (item.employee ? `Сотрудник: ${item.employee.name}` : '-')
                                    // Highlight description for Services (REPAIR)
                                    const isService = item.type === 'REPAIR' || item.type === 'OTHER_INCOME'

                                    let amount = item.amount
                                    let amountClass = isService ? 'text-emerald-400' : 'text-red-400'

                                    // Transaction logic (Product Sale)
                                    if (!isFinance) {
                                        desc = item.product?.name || 'Товар удален'
                                        // Calculate sale amount
                                        const price = item.snapshotPrice || item.product?.sellPrice || 0
                                        amount = price * Math.abs(item.quantityChange)
                                        amountClass = 'text-white'
                                        if (item.type !== 'SALE') amountClass = 'text-slate-400'
                                    }

                                    return (
                                        <tr key={item.id} className="hover:bg-slate-800/50 transition-colors group">
                                            <td className="p-4 text-xs font-mono text-slate-400 whitespace-nowrap">{date}</td>
                                            <td className="p-4 text-sm text-white">
                                                {isService ? (
                                                    <div className="flex flex-col">
                                                        <span className="font-bold text-base text-white">{item.description || "Без описания"}</span>
                                                        {item.employee && <span className="text-[10px] text-indigo-400 font-black uppercase mt-1">Мастер: {item.employee.name}</span>}
                                                    </div>
                                                ) : (
                                                    <>
                                                        <span className="font-bold">{desc}</span>
                                                        {item.employee && <span className="block text-[10px] text-indigo-400 font-bold uppercase mt-0.5">Мастер: {item.employee.name}</span>}
                                                    </>
                                                )}
                                            </td>
                                            <td className={`p-4 text-sm font-black text-right ${amountClass}`}>
                                                <div className="flex items-center justify-end gap-3">
                                                    <span>{amount?.toLocaleString()} c</span>
                                                    {isFinance && item.type === 'SALARY' && (
                                                        <button
                                                            onClick={(e) => { e.stopPropagation(); handleDelete(item.id); }}
                                                            disabled={isDeleting === item.id}
                                                            className="p-1 hover:bg-red-500/20 text-red-500 rounded transition-all"
                                                            title="Удалить выплату"
                                                        >
                                                            {isDeleting === item.id ? "..." : (
                                                                <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                                                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                                                                </svg>
                                                            )}
                                                        </button>
                                                    )}
                                                </div>
                                            </td>
                                        </tr>
                                    )
                                })}
                            </tbody>
                        </table>
                    )}
                </div>
            </div>
        </div>
    )
}

// Low Stock Modal Component
const LowStockModal = ({
    isOpen,
    onClose,
    items
}: {
    isOpen: boolean,
    onClose: () => void,
    items: { name: string; barcode: string; quantity: number; sellPrice: number }[]
}) => {
    if (!isOpen) return null

    return (
        <div className="fixed inset-0 bg-black/80 backdrop-blur-sm z-[100] flex items-center justify-center p-4" onClick={onClose}>
            <div className="bg-slate-900 border border-slate-700 rounded-3xl w-full max-w-lg max-h-[80vh] flex flex-col shadow-2xl animate-in fade-in zoom-in-95 duration-200" onClick={e => e.stopPropagation()}>
                <div className="p-6 border-b border-slate-800 flex justify-between items-center bg-slate-900/50">
                    <h3 className="text-xl font-black text-red-500 uppercase flex items-center gap-2">
                        <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" /></svg>
                        Заканчивается
                    </h3>
                    <button onClick={onClose} className="p-2 hover:bg-slate-800 rounded-full text-slate-400 hover:text-white transition-colors">
                        <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" /></svg>
                    </button>
                </div>

                <div className="flex-1 overflow-y-auto p-0 custom-scrollbar">
                    {items && items.length === 0 ? (
                        <div className="p-10 text-center text-slate-500 font-bold uppercase tracking-widest">На складе всё хорошо 👌</div>
                    ) : (
                        <div className="divide-y divide-slate-800/50">
                            {items?.map((item) => (
                                <div key={item.barcode} className="p-4 hover:bg-slate-800/30 transition-colors flex items-center justify-between">
                                    <div className="min-w-0 flex-1 pr-4">
                                        <h4 className="font-bold text-white text-sm truncate">{item.name}</h4>
                                        <p className="text-[10px] font-mono text-slate-500">{item.barcode}</p>
                                    </div>
                                    <div className="text-right shrink-0">
                                        <span className={`inline-block px-2 py-1 rounded text-xs font-black ${item.quantity === 0 ? 'bg-red-500/20 text-red-500' : 'bg-orange-500/20 text-orange-400'}`}>
                                            {item.quantity} шт
                                        </span>
                                        <p className="text-[10px] text-slate-600 mt-1">{item.sellPrice.toLocaleString()} с</p>
                                    </div>
                                </div>
                            ))}
                        </div>
                    )}
                </div>
            </div>
        </div>
    )
}

export default function AnalyticsPage() {
    const [period, setPeriod] = useState<TimePeriod>("today")
    const [startDate, setStartDate] = useState<Date | null>(null)
    const [endDate, setEndDate] = useState<Date | null>(null)

    // Detail Modal State
    const [detailModal, setDetailModal] = useState<{
        isOpen: boolean,
        type: 'REPAIR' | 'EXPENSE' | 'SALARY' | 'SALE' | 'PROFIT',
        title: string
    }>({ isOpen: false, type: 'REPAIR', title: '' })

    // Low Stock Modal State
    const [isLowStockModalOpen, setIsLowStockModalOpen] = useState(false)

    const openDetail = (type: 'REPAIR' | 'EXPENSE' | 'SALARY' | 'SALE' | 'PROFIT', title: string) => {
        setDetailModal({ isOpen: true, type, title })
    }

    // Custom date handling
    const handleCustomDateChange = (e: React.ChangeEvent<HTMLInputElement>, type: 'start' | 'end') => {
        const val = e.target.value ? new Date(e.target.value) : null
        if (type === 'start') setStartDate(val)
        else setEndDate(val)

        if (period !== 'custom') setPeriod('custom')
    }

    const { data, isLoading: loading } = useAnalytics(period, startDate, endDate)

    const formatMoney = (value: number) => {
        return (value || 0).toLocaleString()
    }

    if (loading) return (
        <div className="flex items-center justify-center h-[calc(100vh-5rem)] bg-slate-950 text-slate-500 font-black tracking-widest uppercase animate-pulse">
            Загрузка аналитики...
        </div>
    )

    if (!data) return (
        <div className="flex items-center justify-center h-[calc(100vh-5rem)] bg-slate-950 text-red-500 font-black tracking-widest uppercase">
            Ошибка загрузки данных
        </div>
    )

    const { kpis, transactionCounts, topProducts, slowMoving } = data as AnalyticsData

    return (
        <div className="min-h-[calc(100vh-5rem)] bg-slate-950 p-6 space-y-8 select-none pb-20">
            {/* Header */}
            <header className="flex flex-col lg:flex-row lg:items-end justify-between gap-6">
                <div>
                    <span className="text-[10px] font-black text-emerald-500 tracking-[0.4em] uppercase opacity-90">Бизнес</span>
                    <h1 className="text-2xl sm:text-3xl font-black text-white tracking-tight mt-1 uppercase">Аналитика</h1>
                    <p className="text-sm text-slate-500 mt-1">Финансы и эффективность</p>
                </div>

                {/* Period Selector */}
                <div className="flex flex-col sm:flex-row gap-4">
                    <div className="flex bg-slate-900 p-1 rounded-xl border border-slate-800">
                        {[
                            { value: "today" as TimePeriod, label: "Сегодня" },
                            { value: "yesterday" as TimePeriod, label: "Вчера" },
                            { value: "week" as TimePeriod, label: "7 дней" },
                            { value: "month" as TimePeriod, label: "30 дней" },
                            { value: "all" as TimePeriod, label: "Всё" },
                        ].map(p => (
                            <button
                                key={p.value}
                                onClick={() => { setPeriod(p.value); setStartDate(null); setEndDate(null); }}
                                className={`px-4 py-2 rounded-lg text-[10px] font-black tracking-widest uppercase transition-all ${period === p.value
                                    ? "bg-slate-800 text-white shadow-lg"
                                    : "text-slate-500 hover:text-slate-300"
                                    }`}
                            >
                                {p.label}
                            </button>
                        ))}
                    </div>

                    {/* Custom Date Inputs */}
                    <div className="flex items-center gap-2 bg-slate-900 p-1 px-3 rounded-xl border border-slate-800">
                        <input
                            type="date"
                            className="bg-transparent text-white text-xs font-bold uppercase tracking-wide outline-none [&::-webkit-calendar-picker-indicator]:invert"
                            onChange={e => handleCustomDateChange(e, 'start')}
                            value={startDate ? startDate.toISOString().split('T')[0] : ''}
                        />
                        <span className="text-slate-600">-</span>
                        <input
                            type="date"
                            className="bg-transparent text-white text-xs font-bold uppercase tracking-wide outline-none [&::-webkit-calendar-picker-indicator]:invert"
                            onChange={e => handleCustomDateChange(e, 'end')}
                            value={endDate ? endDate.toISOString().split('T')[0] : ''}
                        />
                    </div>
                </div>
            </header>

            {/* Financial Overview (Net Profit Focus) */}
            <section className="grid grid-cols-1 lg:grid-cols-3 gap-6">
                {/* Net Profit Big Card */}
                <div
                    onClick={() => openDetail('PROFIT', 'Чистая прибыль')}
                    className="lg:col-span-1 bg-gradient-to-br from-emerald-900/40 to-slate-900 border border-emerald-500/20 rounded-3xl p-6 relative overflow-hidden group cursor-pointer hover:border-emerald-500/40 transition-all active:scale-[0.98]"
                >
                    <div className="absolute top-0 right-0 p-6 opacity-10 group-hover:opacity-20 transition-opacity">
                        <svg className="w-32 h-32 text-emerald-500" fill="currentColor" viewBox="0 0 24 24"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1.41 16.09V20h-2.67v-1.93c-1.71-.36-3.15-1.46-3.32-3.49h2.84c.17.7.66 1.21 1.49 1.21.84 0 1.54-.45 1.54-1.16 0-.61-.41-1.02-1.92-1.46-2.09-.59-3-1.6-3-2.88 0-1.63 1.21-2.9 2.98-3.23V5h2.67v1.89c1.64.33 2.87 1.42 3.03 3.16h-2.77c-.12-.66-.62-1.05-1.41-1.05-.73 0-1.33.4-1.33 1.05 0 .61.43.98 2 1.44 2.12.63 2.92 1.69 2.92 2.98 0 1.84-1.28 2.98-3.04 3.32z" /></svg>
                    </div>
                    <span className="text-xs font-black text-emerald-400 uppercase tracking-widest">Чистая прибыль</span>
                    <p className={`text-4xl sm:text-5xl font-black mt-4 mb-2 tracking-tight ${kpis.netProfit >= 0 ? "text-white" : "text-red-400"}`}>
                        {formatMoney(kpis.netProfit)} <span className="text-lg text-emerald-500/50 align-top">c</span>
                    </p>
                    <div className="flex gap-4 mt-6">
                        <div>
                            <span className="text-[10px] text-emerald-400/60 uppercase font-bold block">Маржа</span>
                            <span className="text-xl font-bold text-emerald-400">{kpis.margin}%</span>
                        </div>
                        <div>
                            <span className="text-[10px] text-slate-500 uppercase font-bold block">Выручка</span>
                            <span className="text-xl font-bold text-slate-300">{formatMoney(kpis.totalRevenue)}</span>
                        </div>
                    </div>
                </div>

                {/* Revenue Breakdown */}
                <div className="lg:col-span-2 grid grid-cols-2 sm:grid-cols-4 gap-4">
                    {/* Product Sales */}
                    <div
                        onClick={() => openDetail('SALE', 'Продажи товаров')}
                        className="bg-slate-900/50 border border-slate-800 rounded-2xl p-5 hover:border-indigo-500/30 transition-all cursor-pointer hover:bg-slate-900 active:scale-[0.98]"
                    >
                        <span className="text-[10px] font-black text-indigo-400 uppercase tracking-widest">Товары</span>
                        <p className="text-2xl font-black text-white mt-2">{formatMoney(kpis.revenue)}</p>
                        <p className="text-[10px] text-slate-500 mt-1 font-bold">Продажи: {transactionCounts.sales}</p>
                    </div>

                    {/* Service Revenue */}
                    <div
                        onClick={() => openDetail('REPAIR', 'Выручка от услуг')}
                        className="bg-slate-900/50 border border-slate-800 rounded-2xl p-5 hover:border-amber-500/30 transition-all cursor-pointer hover:bg-slate-900 active:scale-[0.98]"
                    >
                        <span className="text-[10px] font-black text-amber-400 uppercase tracking-widest">Услуги</span>
                        <p className="text-2xl font-black text-white mt-2">{formatMoney(kpis.repairRevenue)}</p>
                        <p className="text-[10px] text-slate-500 mt-1 font-bold">Ремонтов: {transactionCounts.repairs}</p>
                    </div>

                    {/* Salaries */}
                    <div
                        onClick={() => openDetail('SALARY', 'Выплаты зарплат')}
                        className="bg-slate-900/50 border border-slate-800 rounded-2xl p-5 hover:border-red-500/30 transition-all cursor-pointer hover:bg-slate-900 active:scale-[0.98]"
                    >
                        <span className="text-[10px] font-black text-red-400 uppercase tracking-widest">Зарплаты</span>
                        <p className="text-2xl font-black text-white mt-2">-{formatMoney(kpis.salaryExpenses)}</p>
                        <p className="text-[10px] text-slate-500 mt-1 font-bold">Расходы</p>
                    </div>

                    {/* Other Expense/Loss */}
                    <div
                        onClick={() => openDetail('EXPENSE', 'Прочие расходы')}
                        className="bg-slate-900/50 border border-slate-800 rounded-2xl p-5 hover:border-red-500/30 transition-all cursor-pointer hover:bg-slate-900 active:scale-[0.98]"
                    >
                        <span className="text-[10px] font-black text-red-400 uppercase tracking-widest">Прочее</span>
                        <p className="text-2xl font-black text-white mt-2">-{formatMoney(kpis.otherExpenses + kpis.auditLosses)}</p>
                        <p className="text-[10px] text-slate-500 mt-1 font-bold">Потери и расходы</p>
                    </div>
                </div>
            </section>

            {/* Detailed KPIs */}
            <section className="space-y-4">
                <h2 className="text-xs font-black text-slate-500 uppercase tracking-widest">Детализация</h2>
                <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
                    <div className="bg-slate-900/30 border border-slate-800/50 rounded-xl p-4">
                        <span className="text-[10px] font-bold text-slate-500 uppercase">Валовая прибыль (Товары)</span>
                        <p className="text-xl font-black text-slate-300 mt-1">{formatMoney(kpis.grossProfit)}</p>
                    </div>
                    <div className="bg-slate-900/30 border border-slate-800/50 rounded-xl p-4">
                        <span className="text-[10px] font-bold text-slate-500 uppercase">Себестоимость (COGS)</span>
                        <p className="text-xl font-black text-slate-300 mt-1">{formatMoney(kpis.cogs)}</p>
                    </div>
                    <div className="bg-slate-900/30 border border-slate-800/50 rounded-xl p-4">
                        <span className="text-[10px] font-bold text-slate-500 uppercase">Средний чек</span>
                        <p className="text-xl font-black text-slate-300 mt-1">{formatMoney(kpis.avgTransactionValue)}</p>
                    </div>
                    <div className="bg-slate-900/30 border border-slate-800/50 rounded-xl p-4">
                        <span className="text-[10px] font-bold text-slate-500 uppercase">Потери (Ревизии)</span>
                        <p className="text-xl font-black text-red-400 mt-1">{formatMoney(kpis.auditLosses)}</p>
                    </div>
                </div>
            </section>

            {/* Inventory Status (Current Snapshot) */}
            <section className="space-y-4 pt-4 border-t border-slate-800">
                <div className="flex justify-between items-end">
                    <h2 className="text-xs font-black text-slate-500 uppercase tracking-widest">Состояние склада (Текущее)</h2>
                </div>
                <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
                    <div className="bg-slate-900/50 border border-slate-800 rounded-2xl p-5">
                        <span className="text-[10px] font-black text-blue-400 uppercase tracking-widest">Оценка (Продажа)</span>
                        <p className="text-2xl font-black text-white mt-1">{formatMoney(kpis.inventoryValue)}</p>
                    </div>
                    <div className="bg-slate-900/50 border border-slate-800 rounded-2xl p-5">
                        <span className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Оценка (Закуп)</span>
                        <p className="text-2xl font-black text-slate-300 mt-1">{formatMoney(kpis.inventoryCost)}</p>
                    </div>
                    <div className="bg-slate-900/50 border border-slate-800 rounded-2xl p-5">
                        <span className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Позиций (SKU)</span>
                        <p className="text-2xl font-black text-white mt-1">{kpis.totalSKUs}</p>
                    </div>
                    <div
                        onClick={() => setIsLowStockModalOpen(true)}
                        className={`bg-slate-900/50 border rounded-2xl p-5 transition-all cursor-pointer hover:bg-slate-900 active:scale-[0.98] ${kpis.lowStockItems > 0 ? "border-red-500/30 hover:border-red-500/50" : "border-slate-800"}`}
                    >
                        <span className={`text-[10px] font-black uppercase tracking-widest ${kpis.lowStockItems > 0 ? "text-red-400" : "text-slate-500"}`}>Мало товара</span>
                        <p className={`text-2xl font-black mt-1 ${kpis.lowStockItems > 0 ? "text-red-400" : "text-white"}`}>{kpis.lowStockItems}</p>
                    </div>
                </div>
            </section>

            {/* Top Products & Slow Moving */}
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 pt-4">
                {/* Top Products by Profit */}
                <section className="bg-slate-900/50 border border-slate-800 rounded-2xl p-6 space-y-4">
                    <div className="flex items-center justify-between">
                        <h3 className="text-xs font-black text-emerald-400 uppercase tracking-widest">Прибыльные товары</h3>
                        <span className="text-[10px] text-slate-600 font-bold">по прибыли</span>
                    </div>

                    {topProducts.length === 0 ? (
                        <p className="text-center py-10 text-slate-600 font-bold uppercase tracking-widest">Нет данных</p>
                    ) : (
                        <div className="space-y-2 max-h-[400px] overflow-y-auto custom-scrollbar pr-2">
                            {topProducts.map((p, i) => (
                                <div key={p.barcode} className="flex items-center justify-between py-3 px-4 bg-slate-950 rounded-xl">
                                    <div className="flex items-center gap-3 flex-1 min-w-0">
                                        <span className={`w-6 h-6 shrink-0 flex items-center justify-center rounded text-xs font-black ${i === 0 ? "bg-amber-500/20 text-amber-400" :
                                            i === 1 ? "bg-slate-400/20 text-slate-300" :
                                                i === 2 ? "bg-orange-500/20 text-orange-400" :
                                                    "bg-slate-800 text-slate-500"
                                            }`}>
                                            {i + 1}
                                        </span>
                                        <div className="min-w-0">
                                            <p className="font-bold text-white text-sm truncate">{p.name}</p>
                                        </div>
                                    </div>
                                    <div className="flex items-center gap-4 shrink-0 text-right">
                                        <div className="hidden sm:block">
                                            <span className="text-[9px] text-slate-600 block">Выручка</span>
                                            <span className="text-xs font-bold text-slate-300">{formatMoney(p.revenue)}</span>
                                        </div>
                                        <div>
                                            <span className="text-xs text-slate-600 block">Прибыль</span>
                                            <span className="text-sm font-black text-emerald-400">+{formatMoney(p.profit)}</span>
                                        </div>
                                    </div>
                                </div>
                            ))}
                        </div>
                    )}
                </section>

                {/* Slow Moving Products */}
                <section className="bg-slate-900/50 border border-slate-800 rounded-2xl p-6 space-y-4">
                    <div className="flex items-center justify-between">
                        <h3 className="text-xs font-black text-amber-400 uppercase tracking-widest">Неликвид</h3>
                        <span className="text-[10px] text-slate-600 font-bold">без продаж</span>
                    </div>

                    {slowMoving.length === 0 ? (
                        <p className="text-center py-10 text-slate-600 font-bold uppercase tracking-widest">Нет залежавшихся товаров</p>
                    ) : (
                        <div className="space-y-2 max-h-[400px] overflow-y-auto custom-scrollbar">
                            {slowMoving.map((p) => (
                                <div key={p.barcode} className="flex items-center justify-between py-3 px-4 bg-slate-950 rounded-xl">
                                    <div>
                                        <p className="font-bold text-white text-sm truncate max-w-[200px]">{p.name}</p>
                                        <p className="text-[10px] text-slate-600 font-mono">{p.barcode}</p>
                                    </div>
                                    <div className="text-right">
                                        <p className="font-black text-amber-400">{p.quantity} шт</p>
                                        <p className="text-[10px] text-slate-500">{formatMoney(p.value)} сом</p>
                                    </div>
                                </div>
                            ))}
                        </div>
                    )}
                </section>
            </div>

            <DetailModal
                isOpen={detailModal.isOpen}
                onClose={() => setDetailModal(prev => ({ ...prev, isOpen: false }))}
                title={detailModal.title}
                type={detailModal.type}
                startDate={data?.dateRange?.start ? new Date(data.dateRange.start) : null}
                endDate={data?.dateRange?.end ? new Date(data.dateRange.end) : null}
            />

            <LowStockModal
                isOpen={isLowStockModalOpen}
                onClose={() => setIsLowStockModalOpen(false)}
                items={(data as AnalyticsData).lowStockList || []}
            />
        </div>
    )
}
