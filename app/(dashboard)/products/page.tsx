"use client"

import { useState, useEffect } from "react"
import { toast } from "sonner"
import { useBarcodeScanner, generateEAN13 } from "@/lib/useBarcodeScanner"

interface Product {
    id: string
    name: string
    barcode: string
    stock: number
    buyPrice: number
    sellPrice: number
}

type SortKey = "name" | "barcode" | "stock" | "buyPrice" | "sellPrice" | "margin"
type SortDirection = "asc" | "desc"

export default function ProductsPage() {
    const [products, setProducts] = useState<Product[]>([])
    const [showForm, setShowForm] = useState(false)
    const [editingProduct, setEditingProduct] = useState<Product | null>(null)
    const [loading, setLoading] = useState(true)
    const [search, setSearch] = useState("")
    const [sortConfig, setSortConfig] = useState<{ key: SortKey; direction: SortDirection }>({ key: "name", direction: "asc" })
    const [deleteConfirmId, setDeleteConfirmId] = useState<string | null>(null)
    const [deleting, setDeleting] = useState(false)

    const [formData, setFormData] = useState<{
        name: string
        barcode: string
        stock: number | ""
        buyPrice: number | ""
        sellPrice: number | ""
    }>({
        name: "",
        barcode: "",
        stock: 0,
        buyPrice: 0,
        sellPrice: 0
    })

    useEffect(() => {
        fetchProducts()
    }, [])

    // Barcode scanner: auto-search when scanned
    useBarcodeScanner({
        onScan: (barcode) => {
            setSearch(barcode)
            toast.info(`🔍 Сканирован: ${barcode}`)
        }
    })

    const fetchProducts = async () => {
        try {
            const res = await fetch("/api/products")
            const data = await res.json()
            setProducts(Array.isArray(data) ? data : [])
        } catch (e) {
            toast.error("Ошибка загрузки данных")
        } finally {
            setLoading(false)
        }
    }

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault()
        try {
            const url = editingProduct ? `/api/products/${editingProduct.id}` : "/api/products"
            const res = await fetch(url, {
                method: editingProduct ? "PUT" : "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify(formData)
            })
            if (res.ok) {
                fetchProducts()
                resetForm()
                toast.success(editingProduct ? "Товар обновлен! 📝" : "Товар создан! 🎉")
            } else {
                toast.error("Ошибка сохранения")
            }
        } catch (e) {
            toast.error("Ошибка сети")
        }
    }

    const handleEdit = (product: Product) => {
        setEditingProduct(product)
        setFormData({
            name: product.name,
            barcode: product.barcode,
            stock: product.stock,
            buyPrice: product.buyPrice,
            sellPrice: product.sellPrice
        })
        setShowForm(true)
    }

    const handleDelete = async (id: string) => {
        setDeleting(true)
        try {
            const res = await fetch(`/api/products/${id}`, { method: "DELETE" })
            if (res.ok) {
                fetchProducts()
                toast.success("Товар удален 🗑️")
            } else {
                toast.error("Ошибка удаления")
            }
        } catch (e) {
            toast.error("Ошибка сети")
        } finally {
            setDeleting(false)
            setDeleteConfirmId(null)
        }
    }

    const resetForm = () => {
        setShowForm(false)
        setEditingProduct(null)
        setFormData({ name: "", barcode: "", stock: 0, buyPrice: 0, sellPrice: 0 })
    }

    const handleSort = (key: SortKey) => {
        setSortConfig(current => ({
            key,
            direction: current.key === key && current.direction === "asc" ? "desc" : "asc"
        }))
    }

    const sortedProducts = [...products].sort((a, b) => {
        const { key, direction } = sortConfig
        const modifier = direction === "asc" ? 1 : -1

        if (key === "margin") {
            const marginA = a.sellPrice - a.buyPrice
            const marginB = b.sellPrice - b.buyPrice
            return (marginA - marginB) * modifier
        }

        if (typeof a[key as keyof Product] === "string") {
            return (a[key as keyof Product] as string).localeCompare(b[key as keyof Product] as string) * modifier
        }

        return ((a[key as keyof Product] as number) - (b[key as keyof Product] as number)) * modifier
    })

    const filteredProducts = sortedProducts.filter(p =>
        p.name.toLowerCase().includes(search.toLowerCase()) || p.barcode.includes(search)
    )

    // Owner KPIs
    const totalCostValue = products.reduce((sum, p) => sum + (p.stock * p.buyPrice), 0)
    const totalSellValue = products.reduce((sum, p) => sum + (p.stock * p.sellPrice), 0)
    const potentialProfit = totalSellValue - totalCostValue

    if (loading) return (
        <div className="flex items-center justify-center h-[calc(100vh-5rem)] bg-slate-950 text-slate-500 font-bold tracking-widest uppercase">
            Загрузка склада...
        </div>
    )

    return (
        <div className="min-h-[calc(100vh-5rem)] bg-slate-950 p-6 space-y-8 font-sans text-slate-200">
            {/* Header */}
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-6 pb-2 border-b border-slate-800/50">
                <div>
                    <span className="text-[10px] font-black text-indigo-500 tracking-[0.4em] uppercase opacity-90 glow-text-indigo">Панель Владельца</span>
                    <h1 className="text-3xl font-black text-white tracking-tight mt-1 uppercase">Склад</h1>
                </div>
                <button
                    onClick={() => setShowForm(true)}
                    className="px-6 py-3 bg-gradient-to-r from-indigo-600 to-indigo-500 hover:from-indigo-500 hover:to-indigo-400 text-white text-xs font-black tracking-widest uppercase rounded-xl transition-all active:scale-95 shadow-lg shadow-indigo-500/20 select-none"
                >
                    + Новый товар
                </button>
            </div>

            {/* KPI Cards (Owner's View) - UPDATED & SHARP */}
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-6">
                {/* 1. Cost Value */}
                <div className="bg-slate-900/50 backdrop-blur p-6 border border-slate-800 group hover:border-slate-700 transition-colors select-none">
                    <div className="flex justify-between items-start mb-4">
                        <span className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Оценка (Закупка)</span>
                    </div>
                    <p className="text-3xl font-black text-slate-300 tracking-tight">{totalCostValue.toLocaleString()} <span className="text-sm font-bold text-slate-600">сом</span></p>
                    <p className="text-[10px] text-slate-600 mt-2 font-mono uppercase tracking-wider">Себестоимость скл.</p>
                </div>

                {/* 2. Total Valuation (Sell Price) */}
                <div className="bg-slate-900/50 backdrop-blur p-6 border border-indigo-500/20 group hover:border-indigo-500/40 transition-colors select-none">
                    <div className="flex justify-between items-start mb-4">
                        <span className="text-[10px] font-black text-indigo-400 uppercase tracking-widest">Оценка (Продажа)</span>
                    </div>
                    <p className="text-3xl font-black text-white tracking-tight">{totalSellValue.toLocaleString()} <span className="text-sm font-bold text-slate-500">сом</span></p>
                    <p className="text-[10px] text-slate-500 mt-2 font-mono uppercase tracking-wider">Розничная цена скл.</p>
                </div>

                {/* 3. Potential Profit */}
                <div className="bg-slate-900/50 backdrop-blur p-6 border border-emerald-500/20 shadow-[0_0_20px_-5px_rgba(16,185,129,0.1)] group hover:border-emerald-500/40 transition-colors select-none">
                    <div className="flex justify-between items-start mb-4">
                        <span className="text-[10px] font-black text-emerald-400 uppercase tracking-widest">Потенц. Прибыль</span>
                    </div>
                    <p className="text-3xl font-black text-white tracking-tight">{potentialProfit.toLocaleString()} <span className="text-sm font-bold text-slate-500">сом</span></p>
                    <p className="text-[10px] text-slate-500 mt-2 font-mono uppercase tracking-wider">После реализации</p>
                </div>
            </div>

            {/* Search Tool - NO ICON, MORE SPACING */}
            <div className="py-2">
                <input
                    type="text"
                    value={search}
                    onChange={(e) => setSearch(e.target.value)}
                    placeholder="ПОИСК ПО НАЗВАНИЮ ИЛИ ШТРИХ-КОДУ..."
                    className="w-full bg-transparent border-b border-slate-800 py-3 md:py-4 text-base md:text-xl font-bold text-white placeholder:text-slate-700 outline-none focus:border-indigo-500 transition-colors text-center uppercase tracking-widest"
                />
            </div>

            {/* === DESKTOP: Data Table === */}
            <div className="hidden md:block overflow-x-auto pb-20">
                <table className="w-full text-left text-sm border-collapse">
                    <thead>
                        <tr className="border-b border-slate-800">
                            <th onClick={() => handleSort("name")} className="px-6 py-4 text-[10px] font-black text-slate-500 uppercase tracking-widest cursor-pointer hover:text-white transition-colors select-none text-left">
                                Название {sortConfig.key === "name" && (sortConfig.direction === "asc" ? "↑" : "↓")}
                            </th>
                            <th onClick={() => handleSort("barcode")} className="px-6 py-4 text-[10px] font-black text-slate-500 uppercase tracking-widest cursor-pointer hover:text-white transition-colors select-none text-left">
                                Штрих-код {sortConfig.key === "barcode" && (sortConfig.direction === "asc" ? "↑" : "↓")}
                            </th>
                            <th onClick={() => handleSort("stock")} className="px-6 py-4 text-[10px] font-black text-slate-500 uppercase tracking-widest cursor-pointer hover:text-white transition-colors select-none text-right">
                                Количество {sortConfig.key === "stock" && (sortConfig.direction === "asc" ? "↑" : "↓")}
                            </th>
                            <th onClick={() => handleSort("buyPrice")} className="px-6 py-4 text-[10px] font-black text-slate-500 uppercase tracking-widest cursor-pointer hover:text-white transition-colors select-none text-right">
                                Закупка {sortConfig.key === "buyPrice" && (sortConfig.direction === "asc" ? "↑" : "↓")}
                            </th>
                            <th onClick={() => handleSort("sellPrice")} className="px-6 py-4 text-[10px] font-black text-slate-500 uppercase tracking-widest cursor-pointer hover:text-white transition-colors select-none text-right">
                                Продажа {sortConfig.key === "sellPrice" && (sortConfig.direction === "asc" ? "↑" : "↓")}
                            </th>
                            <th onClick={() => handleSort("margin")} className="px-6 py-4 text-[10px] font-black text-slate-500 uppercase tracking-widest cursor-pointer hover:text-white transition-colors select-none text-right">
                                Маржа {sortConfig.key === "margin" && (sortConfig.direction === "asc" ? "↑" : "↓")}
                            </th>
                            <th className="px-6 py-4 text-[10px] font-black text-slate-500 uppercase tracking-widest text-right select-none">
                                Действия
                            </th>
                        </tr>
                    </thead>
                    <tbody className="divide-y divide-slate-800/50">
                        {filteredProducts.map((product) => {
                            const margin = product.sellPrice - product.buyPrice;
                            const marginPercent = product.buyPrice > 0
                                ? ((margin / product.buyPrice) * 100).toFixed(0) + "%"
                                : (product.sellPrice > 0 ? "∞" : "0%");

                            return (
                                <tr key={product.id} className="hover:bg-slate-900/40 transition-colors group">
                                    <td className="px-6 py-5 font-bold text-slate-200">
                                        {product.name}
                                        {product.stock <= 5 && (
                                            <span className="ml-2 inline-flex items-center px-2 py-0.5 rounded text-[9px] font-black bg-red-500/10 text-red-500 border border-red-500/20 uppercase tracking-wider select-none">Low</span>
                                        )}
                                    </td>
                                    <td className="px-6 py-5 text-slate-500 font-mono text-xs select-all w-fit">
                                        <span className="bg-slate-900 px-2 py-1 rounded">{product.barcode}</span>
                                    </td>
                                    <td className="px-6 py-5 text-right">
                                        <span className={`font-bold ${product.stock <= 5 ? "text-red-400" : "text-white"}`}>
                                            {product.stock}
                                        </span>
                                    </td>
                                    <td className="px-6 py-5 text-right text-slate-500">{product.buyPrice.toLocaleString()}</td>
                                    <td className="px-6 py-5 text-right font-bold text-white">{product.sellPrice.toLocaleString()}</td>
                                    <td className="px-6 py-5 text-right">
                                        <div className="flex flex-col items-end">
                                            <span className="font-bold text-emerald-400">+{margin.toLocaleString()}</span>
                                            <span className="text-[10px] font-bold text-emerald-600 bg-emerald-950/30 px-1 rounded">{marginPercent}</span>
                                        </div>
                                    </td>
                                    <td className="px-6 py-5 text-right">
                                        <div className="flex items-center justify-end gap-2">
                                            <button onClick={() => handleEdit(product)} className="text-indigo-400 hover:text-white text-xs font-bold px-3 py-1.5 rounded-lg hover:bg-indigo-600/20 transition-colors select-none bg-slate-800/50">
                                                Изменить
                                            </button>
                                            <button onClick={() => setDeleteConfirmId(product.id)} className="text-white bg-red-600/20 hover:bg-red-600 hover:shadow-[0_0_15px_-3px_rgba(220,38,38,0.5)] text-xs font-bold px-3 py-1.5 rounded-lg transition-all select-none border border-red-500/30">
                                                Удалить
                                            </button>
                                        </div>
                                    </td>
                                </tr>
                            )
                        })}
                    </tbody>
                </table>
            </div>

            {/* === MOBILE: Card List === */}
            <div className="md:hidden space-y-4 pb-24">
                {filteredProducts.map((product) => {
                    const margin = product.sellPrice - product.buyPrice;
                    const marginPercent = product.buyPrice > 0
                        ? ((margin / product.buyPrice) * 100).toFixed(0) + "%"
                        : (product.sellPrice > 0 ? "∞" : "0%");

                    return (
                        <div key={product.id} className="bg-slate-900 rounded-xl p-4 border border-slate-800 shadow-sm relative overflow-hidden">
                            {/* Top Row: Name & Barcode */}
                            <div className="flex justify-between items-start mb-3">
                                <div className="pr-4">
                                    <h3 className="text-white font-bold text-sm line-clamp-2 leading-snug">{product.name}</h3>
                                    <span className="inline-block mt-1 text-[10px] font-mono text-slate-500 bg-slate-950 px-1.5 py-0.5 rounded border border-slate-800/50">{product.barcode}</span>
                                </div>
                                <div className={`shrink-0 flex flex-col items-end px-2 py-1 rounded-lg border ${product.stock <= 5 ? 'bg-red-500/10 border-red-500/20' : 'bg-slate-800 border-slate-700'}`}>
                                    <span className={`text-base font-black ${product.stock <= 5 ? 'text-red-500' : 'text-white'}`}>{product.stock}</span>
                                    <span className="text-[9px] uppercase font-bold text-slate-500">шт</span>
                                </div>
                            </div>

                            {/* Middle Row: Prices Grid */}
                            <div className="grid grid-cols-3 gap-2 mb-4 bg-slate-950/50 rounded-lg p-3 border border-slate-800/50">
                                <div className="flex flex-col">
                                    <span className="text-[9px] text-slate-500 uppercase font-bold tracking-wider">Закуп</span>
                                    <span className="text-xs font-bold text-slate-300">{product.buyPrice.toLocaleString()}</span>
                                </div>
                                <div className="flex flex-col text-center">
                                    <span className="text-[9px] text-slate-500 uppercase font-bold tracking-wider">Маржа</span>
                                    <span className="text-xs font-bold text-emerald-400">+{margin.toLocaleString()}</span>
                                    <span className="text-[9px] text-emerald-600">{marginPercent}</span>
                                </div>
                                <div className="flex flex-col text-right">
                                    <span className="text-[9px] text-slate-500 uppercase font-bold tracking-wider">Продажа</span>
                                    <span className="text-sm font-black text-indigo-400">{product.sellPrice.toLocaleString()}</span>
                                </div>
                            </div>

                            {/* Bottom Row: Actions */}
                            <div className="flex gap-2">
                                <button onClick={() => handleEdit(product)} className="flex-1 py-2.5 bg-indigo-600/10 hover:bg-indigo-600/20 text-indigo-400 font-bold text-xs rounded-lg uppercase tracking-wider border border-indigo-500/20">
                                    Изменить
                                </button>
                                <button onClick={() => setDeleteConfirmId(product.id)} className="flex-1 py-2.5 bg-red-600/10 hover:bg-red-600/20 text-red-500 font-bold text-xs rounded-lg uppercase tracking-wider border border-red-500/20">
                                    Удалить
                                </button>
                            </div>
                        </div>
                    )
                })}
            </div>

            {filteredProducts.length === 0 && (
                <div className="text-center py-12 md:py-24 opacity-40">
                    <p className="text-lg font-bold text-slate-300 uppercase tracking-widest mb-1">Пусто</p>
                    <p className="text-xs text-slate-500">Товары не найдены</p>
                </div>
            )}

            {/* Modal */}
            {showForm && (
                <div className="fixed inset-0 bg-slate-950/80 backdrop-blur-sm flex items-center justify-center z-[200] p-4">
                    <div className="bg-slate-900 w-full max-w-lg shadow-2xl border border-slate-800 p-6 sm:p-8 animate-in zoom-in-95 duration-200">
                        <div className="flex justify-between items-center mb-6">
                            <h2 className="text-xl font-black text-white uppercase tracking-tight">
                                {editingProduct ? "Редактирование" : "Новый товар"}
                            </h2>
                            <button onClick={resetForm} className="w-10 h-10 flex items-center justify-center text-slate-500 hover:text-white hover:bg-slate-800 transition-colors">✕</button>
                        </div>

                        <form onSubmit={handleSubmit} className="space-y-5">
                            <div>
                                <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest block mb-2 px-1">Название</label>
                                <input
                                    type="text"
                                    value={formData.name}
                                    onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                                    required
                                    className="w-full bg-slate-950 border border-slate-800 text-sm px-4 py-4 text-white focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500/20 outline-none transition-all placeholder:text-slate-700 font-bold"
                                    placeholder="Например: Камера 26x2.125"
                                />
                            </div>

                            <div>
                                <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest block mb-2 px-1">Штрих-код</label>
                                <div className="flex gap-2">
                                    <input
                                        type="text"
                                        value={formData.barcode}
                                        onChange={(e) => setFormData({ ...formData, barcode: e.target.value })}
                                        required
                                        className="flex-1 bg-slate-950 border border-slate-800 text-sm px-4 py-4 text-white focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500/20 outline-none transition-all font-mono placeholder:text-slate-700"
                                        placeholder="Введите или сгенерируйте"
                                    />
                                    <button
                                        type="button"
                                        onClick={() => setFormData({ ...formData, barcode: generateEAN13() })}
                                        className="px-4 py-4 bg-indigo-600/20 hover:bg-indigo-600 text-indigo-400 hover:text-white border border-indigo-500/30 text-xs font-black uppercase tracking-wider transition-all whitespace-nowrap"
                                    >
                                        Генерация
                                    </button>
                                </div>
                            </div>

                            <div className="grid grid-cols-3 gap-4">
                                <div>
                                    <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest block mb-2 px-1">Количество</label>
                                    <input
                                        type="number"
                                        value={formData.stock}
                                        onChange={(e) => setFormData({ ...formData, stock: e.target.value === "" ? "" : parseInt(e.target.value) })}
                                        className="w-full bg-slate-950 border border-slate-800 text-sm px-4 py-4 text-white focus:border-indigo-500 outline-none transition-all text-center font-bold"
                                    />
                                </div>
                                <div>
                                    <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest block mb-2 px-1">Закупка</label>
                                    <input
                                        type="number"
                                        value={formData.buyPrice}
                                        onChange={(e) => setFormData({ ...formData, buyPrice: e.target.value === "" ? "" : parseFloat(e.target.value) })}
                                        className="w-full bg-slate-950 border border-slate-800 text-sm px-4 py-4 text-white focus:border-indigo-500 outline-none transition-all text-center font-bold"
                                    />
                                </div>
                                <div>
                                    <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest block mb-2 px-1">Продажа</label>
                                    <input
                                        type="number"
                                        value={formData.sellPrice}
                                        onChange={(e) => setFormData({ ...formData, sellPrice: e.target.value === "" ? "" : parseFloat(e.target.value) })}
                                        className="w-full bg-slate-950 border border-slate-800 text-sm px-4 py-4 text-white focus:border-indigo-500 outline-none transition-all text-center font-bold"
                                    />
                                </div>
                            </div>

                            <div className="flex gap-3 pt-4">
                                <button type="button" onClick={resetForm} className="flex-1 py-4 bg-slate-800 hover:bg-slate-700 text-slate-400 hover:text-white text-xs font-black tracking-widest uppercase transition-all">
                                    Отмена
                                </button>
                                <button type="submit" className="flex-1 py-4 bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-black tracking-widest uppercase transition-all shadow-lg shadow-indigo-500/20">
                                    Сохранить
                                </button>
                            </div>
                        </form>
                    </div>
                </div>
            )}
            {/* Delete Confirmation Modal */}
            {deleteConfirmId && (
                <div className="fixed inset-0 bg-slate-950/80 backdrop-blur-sm flex items-center justify-center z-[300] p-4" onClick={() => setDeleteConfirmId(null)}>
                    <div className="bg-slate-900 w-full max-w-sm shadow-2xl border border-red-500/30 p-6 rounded-2xl animate-in zoom-in-95" onClick={e => e.stopPropagation()}>
                        <div className="text-center mb-6">
                            <div className="w-16 h-16 bg-red-600/20 rounded-full flex items-center justify-center mx-auto mb-4">
                                <svg className="w-8 h-8 text-red-500" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth="2">
                                    <path strokeLinecap="round" strokeLinejoin="round" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                                </svg>
                            </div>
                            <h3 className="text-lg font-black text-white uppercase tracking-tight">Удалить товар?</h3>
                            <p className="text-sm text-slate-400 mt-2">Это действие нельзя отменить</p>
                        </div>
                        <div className="flex gap-3">
                            <button
                                onClick={() => setDeleteConfirmId(null)}
                                className="flex-1 py-4 bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs font-black tracking-widest uppercase rounded-xl transition-all"
                            >
                                Отмена
                            </button>
                            <button
                                onClick={() => handleDelete(deleteConfirmId)}
                                disabled={deleting}
                                className="flex-1 py-4 bg-red-600 hover:bg-red-500 text-white text-xs font-black tracking-widest uppercase rounded-xl transition-all shadow-lg shadow-red-500/20 disabled:opacity-50"
                            >
                                {deleting ? "..." : "Удалить"}
                            </button>
                        </div>
                    </div>
                </div>
            )}
        </div>
    )
}
