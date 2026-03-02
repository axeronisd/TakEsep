"use client"

import { useState, useEffect, useRef } from "react"
import { toast } from "sonner"

interface Product {
    id: string
    name: string
    stock: number
    barcode: string
    sellPrice: number
}

interface Warehouse {
    id: string
    name: string
    groupId?: string
}

interface TransferCartItem {
    product: Product
    quantity: number
}

interface Transfer {
    id: string
    productId: string
    product: Product
    fromWarehouseId: string
    fromWarehouse: { name: string }
    toWarehouseId: string
    toWarehouse: { name: string }
    quantity: number
    status: string
    createdAt: string
    note?: string
}

function IncomingTransferCard({ transfer, onAccept, onReject, loading }: { transfer: Transfer, onAccept: (id: string, data?: any) => void, onReject: (id: string) => void, loading: boolean }) {
    const [expanded, setExpanded] = useState(false)
    const [formData, setFormData] = useState({
        name: transfer.product.name,
        barcode: transfer.product.barcode,
        sellPrice: transfer.product.sellPrice
    })

    const isModified = formData.barcode !== transfer.product.barcode || formData.name !== transfer.product.name

    const handleAcceptClick = (e: React.MouseEvent) => {
        e.stopPropagation()
        if (isModified) {
            if (!confirm(`Принять как НОВЫЙ товар/измененную позицию?\n\nНовое название: ${formData.name}\nШтрих-код: ${formData.barcode}`)) return
            onAccept(transfer.id, {
                newName: formData.name,
                newBarcode: formData.barcode,
                newSellPrice: formData.sellPrice
            })
        } else {
            onAccept(transfer.id)
        }
    }

    return (
        <div
            onClick={() => setExpanded(!expanded)}
            className={`bg-slate-900 border transition-all duration-300 rounded-2xl overflow-hidden cursor-pointer group hover:shadow-2xl ${expanded ? "border-indigo-500/50 shadow-indigo-500/10 ring-1 ring-indigo-500/20" : "border-slate-800 hover:border-slate-700"
                }`}
        >
            {/* Header / Summary View */}
            <div className="p-6 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-6 relative">
                {/* Status Line */}
                <div className={`absolute left-0 top-0 bottom-0 w-1 transition-colors ${expanded ? "bg-indigo-500" : "bg-amber-500"}`} />

                <div className="pl-2">
                    <div className="flex items-center gap-3 mb-2">
                        <span className={`px-2 py-0.5 border rounded text-[10px] font-bold uppercase tracking-wider ${expanded
                            ? "bg-indigo-500/10 text-indigo-400 border-indigo-500/20"
                            : "bg-amber-500/10 text-amber-500 border-amber-500/20"
                            }`}>
                            {expanded ? "Редактирование" : "Ожидает приема"}
                        </span>
                        <span className="text-xs text-slate-500">{new Date(transfer.createdAt).toLocaleString()}</span>
                    </div>
                    <h3 className="text-lg font-bold text-white mb-1 group-hover:text-indigo-200 transition-colors">
                        {transfer.product.name}
                    </h3>
                    <p className="text-sm text-slate-400">
                        От: <span className="text-slate-200 font-semibold">{transfer.fromWarehouse.name}</span>
                        {transfer.note && <span className="ml-2 italic opacity-70">"{transfer.note}"</span>}
                    </p>
                </div>

                <div className="flex items-center gap-6 w-full sm:w-auto justify-end">
                    <div className="text-right">
                        <span className="block text-[10px] font-bold text-slate-500 uppercase">Количество</span>
                        <span className="text-2xl font-black text-white">{transfer.quantity} <span className="text-xs text-slate-600 font-bold">шт</span></span>
                    </div>
                    {/* Collapsed Actions */}
                    {!expanded && (
                        <div className="flex gap-2">
                            <button
                                onClick={handleAcceptClick}
                                disabled={loading}
                                className="px-4 py-2 bg-emerald-600 hover:bg-emerald-500 text-white font-bold rounded-lg text-xs uppercase tracking-wider shadow-lg shadow-emerald-500/20"
                            >
                                Принять
                            </button>
                        </div>
                    )}
                </div>
            </div>

            {/* Expanded Editor */}
            {expanded && (
                <div className="px-6 pb-6 pt-0 animate-in slide-in-from-top-2 duration-200" onClick={e => e.stopPropagation()}>
                    <div className="h-px w-full bg-slate-800/50 mb-6" />

                    <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
                        <div className="space-y-1.5">
                            <label className="text-[10px] font-bold text-slate-500 uppercase tracking-widest pl-1">Название</label>
                            <input
                                value={formData.name}
                                onChange={e => setFormData({ ...formData, name: e.target.value })}
                                className="w-full bg-slate-950 border border-slate-700 rounded-xl px-4 py-3 text-sm font-bold text-white focus:border-indigo-500 outline-none transition-colors"
                            />
                        </div>
                        <div className="space-y-1.5">
                            <label className="text-[10px] font-bold text-slate-500 uppercase tracking-widest pl-1">Штрих-код</label>
                            <input
                                value={formData.barcode}
                                onChange={e => setFormData({ ...formData, barcode: e.target.value })}
                                className="w-full bg-slate-950 border border-slate-700 rounded-xl px-4 py-3 text-sm font-mono text-white focus:border-indigo-500 outline-none transition-colors"
                            />
                        </div>
                        <div className="space-y-1.5">
                            <label className="text-[10px] font-bold text-slate-500 uppercase tracking-widest pl-1">Цена продажи</label>
                            <input
                                type="number"
                                value={formData.sellPrice}
                                onChange={e => setFormData({ ...formData, sellPrice: Number(e.target.value) })}
                                className="w-full bg-slate-950 border border-slate-700 rounded-xl px-4 py-3 text-sm font-bold text-white focus:border-indigo-500 outline-none transition-colors"
                            />
                        </div>
                    </div>

                    <div className="flex justify-end gap-3">
                        <button
                            onClick={() => onReject(transfer.id)}
                            disabled={loading}
                            className="px-6 py-3 bg-slate-800 hover:bg-red-900/20 text-slate-400 hover:text-red-400 border border-slate-700 hover:border-red-500/30 font-bold rounded-xl text-xs uppercase tracking-widest transition-all"
                        >
                            Отклонить
                        </button>
                        <button
                            onClick={handleAcceptClick}
                            disabled={loading}
                            className={`px-8 py-3 font-black rounded-xl text-xs uppercase tracking-widest transition-all shadow-lg flex items-center gap-2 ${isModified
                                ? "bg-indigo-600 hover:bg-indigo-500 text-white shadow-indigo-500/25"
                                : "bg-emerald-600 hover:bg-emerald-500 text-white shadow-emerald-500/25"
                                }`}
                        >
                            {isModified ? "Сохранить и Принять" : "Принять без изменений"}
                            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M5 13l4 4L19 7" /></svg>
                        </button>
                    </div>

                    {isModified && (
                        <div className="mt-4 p-3 bg-indigo-500/10 border border-indigo-500/20 rounded-lg flex items-center gap-3 text-xs text-indigo-300">
                            <svg className="w-5 h-5 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
                            <p>Вы изменили данные. Система определит это как <b>новую позицию</b> (или обновит существующую с таким штрих-кодом).</p>
                        </div>
                    )}
                </div>
            )}
        </div>
    )
}

export default function TransfersPage() {
    const [products, setProducts] = useState<Product[]>([])
    const [warehouses, setWarehouses] = useState<Warehouse[]>([])
    const [incomingTransfers, setIncomingTransfers] = useState<Transfer[]>([])
    const [history, setHistory] = useState<Transfer[]>([])
    const [currentWarehouseId, setCurrentWarehouseId] = useState<string | null>(null)

    // UI State
    const [activeTab, setActiveTab] = useState<"send" | "incoming" | "history">("send")
    const [searchQuery, setSearchQuery] = useState("")
    const [cart, setCart] = useState<TransferCartItem[]>([])
    const [targetWarehouse, setTargetWarehouse] = useState("")
    const [loading, setLoading] = useState(false)
    const [note, setNote] = useState("")

    useEffect(() => {
        // Fetch session for warehouseId
        fetch("/api/auth/session")
            .then(res => res.json())
            .then(data => {
                if (data?.user?.warehouseId) {
                    setCurrentWarehouseId(data.user.warehouseId)
                }
            })
            .catch(console.error)
        fetchData()
    }, [])

    const fetchData = async () => {
        try {
            const [productsRes, warehousesRes, incomingRes, historyRes] = await Promise.all([
                fetch("/api/products").then(r => r.json()),
                fetch("/api/warehouses").then(r => r.json()),
                fetch("/api/transfers/incoming").then(r => r.json()),
                fetch("/api/transfers").then(r => r.json())
            ])
            setProducts(Array.isArray(productsRes) ? productsRes : [])
            setWarehouses(Array.isArray(warehousesRes) ? warehousesRes : [])
            setIncomingTransfers(Array.isArray(incomingRes) ? incomingRes : [])
            setHistory(Array.isArray(historyRes) ? historyRes : [])
        } catch (e) {
            console.error(e)
        }
    }

    const filteredProducts = products.filter(p =>
        (p.name.toLowerCase().includes(searchQuery.toLowerCase()) || p.barcode.includes(searchQuery)) &&
        p.stock > 0
    )

    // Cart Logic
    const addToCart = (product: Product) => {
        setCart(prev => {
            const existing = prev.find(item => item.product.id === product.id)
            if (existing) {
                // Check stock limit
                if (existing.quantity >= product.stock) return prev
                return prev.map(item => item.product.id === product.id ? { ...item, quantity: item.quantity + 1 } : item)
            }
            return [...prev, { product, quantity: 1 }]
        })
    }

    const removeFromCart = (productId: string) => {
        setCart(prev => prev.filter(item => item.product.id !== productId))
    }

    const updateQuantity = (productId: string, newQty: number) => {
        setCart(prev => prev.map(item => {
            if (item.product.id === productId) {
                return { ...item, quantity: Math.min(item.product.stock, Math.max(1, newQty)) }
            }
            return item
        }))
    }

    const handleSendTransfer = async () => {
        if (!targetWarehouse || cart.length === 0) return

        // Removed native confirm for better UX as per request for "beautiful toasts"
        // But for safety, let's keep a quick confirm or just make the TOAST the feedback.
        // I will keep confirm for safety but make it cleaner if possible in future. 
        if (!confirm(`Отправить ${cart.reduce((a, c) => a + c.quantity, 0)} товаров?`)) return

        setLoading(true)
        try {
            const res = await fetch("/api/transfers", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                    toWarehouseId: targetWarehouse,
                    items: cart.map(i => ({ productId: i.product.id, quantity: i.quantity })),
                    note
                })
            })

            if (res.ok) {
                toast.success("Перемещение успешно создано! 🚀")
                setCart([])
                setNote("")
                setTargetWarehouse("")
                fetchData()
            } else {
                const err = await res.json()
                toast.error(err.error || "Ошибка при создании перемещения")
            }
        } catch (e) {
            toast.error("Ошибка сети")
        } finally {
            setLoading(false)
        }
    }

    const handleAccept = async (transferId: string, newData?: any) => {
        if (!newData && !confirm("Принять перемещение?")) return
        setLoading(true)
        try {
            const res = await fetch("/api/transfers/accept", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ transferId, ...newData })
            })

            if (!res.ok) {
                const data = await res.json()
                throw new Error(data.error || "Ошибка сервера")
            }

            toast.success("Товар успешно принят! 🎉")
            fetchData()
        } catch (e: any) {
            toast.error(e.message || "Ошибка при приеме")
        } finally { setLoading(false) }
    }

    const handleReject = async (transferId: string) => {
        if (!confirm("Отклонить перемещение?")) return
        setLoading(true)
        try {
            await fetch("/api/transfers/reject", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ transferId })
            })
            fetchData()
        } finally { setLoading(false) }
    }

    const [showCartDrawer, setShowCartDrawer] = useState(false)

    // ... (logic) ...

    const totalQuantity = cart.reduce((acc, item) => acc + item.quantity, 0)
    const currentWarehouseName = warehouses.find(w => w.id === currentWarehouseId)?.name || "Склад"

    return (
        <div className="flex flex-col h-[calc(100vh-5rem)] bg-slate-950 font-sans overflow-y-auto md:overflow-hidden">

            {/* === Top Navigation Tabs === */}
            <div className="shrink-0 px-4 md:px-6 pt-4 md:pt-6 pb-2 flex items-center justify-between overflow-x-auto no-scrollbar">
                <div className="flex gap-2 bg-slate-900/50 p-1.5 rounded-2xl border border-slate-800/50 backdrop-blur-sm shrink-0">
                    <button
                        onClick={() => setActiveTab("send")}
                        className={`px-4 md:px-6 py-2.5 rounded-xl text-xs font-black tracking-widest uppercase transition-all ${activeTab === "send"
                            ? "bg-indigo-600 text-white shadow-lg shadow-indigo-500/20"
                            : "text-slate-500 hover:text-slate-300 hover:bg-slate-800/50"
                            }`}
                    >
                        Создать
                    </button>
                    <button
                        onClick={() => setActiveTab("incoming")}
                        className={`px-4 md:px-6 py-2.5 rounded-xl text-xs font-black tracking-widest uppercase transition-all relative ${activeTab === "incoming"
                            ? "bg-amber-500 text-white shadow-lg shadow-amber-500/20"
                            : "text-slate-500 hover:text-slate-300 hover:bg-slate-800/50"
                            }`}
                    >
                        Входящие
                        {incomingTransfers.length > 0 && (
                            <span className="absolute -top-1 -right-1 w-4 h-4 bg-red-500 rounded-full border-2 border-slate-950 flex items-center justify-center text-[8px] text-white">
                                {incomingTransfers.length}
                            </span>
                        )}
                    </button>
                    <button
                        onClick={() => setActiveTab("history")}
                        className={`px-4 md:px-6 py-2.5 rounded-xl text-xs font-black tracking-widest uppercase transition-all ${activeTab === "history"
                            ? "bg-slate-700 text-white shadow-lg"
                            : "text-slate-500 hover:text-slate-300 hover:bg-slate-800/50"
                            }`}
                    >
                        История
                    </button>
                </div>

                <div className="text-right hidden sm:block">
                    <p className="text-[10px] text-slate-500 font-bold uppercase tracking-wider">Ваш склад</p>
                    <p className="text-sm font-black text-white">{currentWarehouseName}</p>
                </div>
            </div>

            {/* === Content Area === */}
            <div className="flex-1 min-h-0 relative">

                {/* VIEW: SEND TRANSFER (Split Layout) */}
                {activeTab === "send" && (
                    <div className="absolute inset-0 flex flex-col md:flex-row p-2 md:p-6 gap-2 md:gap-6 pt-2">
                        {/* LEFT: Product Grid */}
                        <div className="flex-1 flex flex-col min-w-0 gap-4 md:gap-6">

                            {/* Search & Actions */}
                            <div className="bg-slate-900/30 rounded-2xl md:rounded-3xl border border-slate-800/50 backdrop-blur-sm p-4 md:p-6 shrink-0 shadow-sm relative z-10 flex gap-4">
                                <div className="relative flex-1">
                                    <input
                                        type="text"
                                        value={searchQuery}
                                        onChange={(e) => setSearchQuery(e.target.value)}
                                        placeholder="Поиск..."
                                        className="w-full px-4 py-3 md:px-5 md:py-4 !bg-slate-900 !border-slate-700/50 rounded-xl md:rounded-2xl text-base md:text-lg font-medium !text-white placeholder:text-slate-500 focus:outline-none focus:ring-4 focus:ring-indigo-500/20 focus:border-indigo-500 transition-all shadow-sm appearance-none"
                                        autoFocus
                                    />
                                    {searchQuery && (
                                        <button onClick={() => setSearchQuery('')} className="absolute right-4 top-1/2 -translate-y-1/2 text-slate-500 hover:text-white transition-colors">
                                            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" /></svg>
                                        </button>
                                    )}
                                </div>
                            </div>

                            {/* Grid */}
                            <div className="flex-1 pb-24 md:pb-24 px-1 md:px-2 md:overflow-y-auto md:custom-scrollbar">
                                <div className="grid grid-cols-2 md:grid-cols-3 xl:grid-cols-4 gap-3 md:gap-6 p-1 md:p-2">
                                    {filteredProducts.map(product => {
                                        const inCart = cart.find(i => i.product.id === product.id)
                                        const qtyInCart = inCart ? inCart.quantity : 0
                                        const available = product.stock - qtyInCart

                                        return (
                                            <div
                                                key={product.id}
                                                onClick={() => available > 0 && addToCart(product)}
                                                role="button"
                                                className={`group relative flex flex-col text-left bg-slate-900 rounded-xl md:rounded-lg border transition-all duration-200 hover:shadow-2xl hover:shadow-indigo-500/10 active:scale-[0.98] cursor-pointer select-none ${inCart
                                                    ? 'border-indigo-500 ring-1 ring-indigo-500/30 bg-slate-800/90 shadow-lg shadow-indigo-500/20'
                                                    : available > 0
                                                        ? 'border-slate-800/60 hover:border-slate-600'
                                                        : 'border-slate-800/30 opacity-60 cursor-not-allowed'
                                                    }`}
                                                style={{ padding: '16px' }}
                                            >
                                                {/* Stock Badge */}
                                                <span className={`absolute top-2 right-2 md:top-3 md:right-3 text-[9px] md:text-[10px] items-center justify-center font-bold px-1.5 py-0.5 md:px-2 md:py-1 rounded border z-10 flex ${available > 0 ? "bg-slate-800 text-slate-400 border-slate-700" : "bg-red-900/20 text-red-500 border-red-500/20"
                                                    }`}>
                                                    Дост: {available}
                                                </span>

                                                {/* Barcode */}
                                                <div className="mb-2 md:mb-4 pr-12">
                                                    <span className="text-[9px] md:text-[10px] font-bold tracking-wider text-slate-400 font-mono bg-slate-950/50 px-1.5 py-0.5 md:px-2 md:py-1 rounded border border-slate-800">
                                                        {product.barcode}
                                                    </span>
                                                </div>

                                                {/* Name */}
                                                <div className="flex-1 mb-2 md:mb-4 h-10 md:h-12">
                                                    <h3 className="text-xs md:text-base font-semibold text-slate-200 leading-snug group-hover:text-white transition-colors line-clamp-2">
                                                        {product.name}
                                                    </h3>
                                                </div>

                                                {inCart && (
                                                    <div className="absolute bottom-3 right-3 w-5 h-5 md:w-6 md:h-6 rounded-full bg-indigo-500 border border-indigo-400 text-white flex items-center justify-center shadow-lg shadow-indigo-500/50 animate-in zoom-in duration-200 z-10">
                                                        <span className="text-xs font-bold">{inCart.quantity}</span>
                                                    </div>
                                                )}
                                            </div>
                                        )
                                    })}
                                </div>
                            </div>
                        </div>

                        {/* === MOBILE: Sticky Bottom Bar (Send) === */}
                        <div className="md:hidden fixed bottom-16 md:bottom-0 left-0 right-0 p-4 bg-slate-900 border-t border-slate-800 z-[60] flex items-center gap-4 shadow-[0_-10px_40px_rgba(0,0,0,0.5)]">
                            <div className="flex items-center gap-3" onClick={() => setShowCartDrawer(true)}>
                                <div className="relative">
                                    <span className={`flex items-center justify-center min-w-[3rem] h-10 px-3 rounded-xl font-bold border ${totalQuantity > 0 ? 'bg-indigo-600 text-white border-indigo-500' : 'bg-slate-800 text-slate-500 border-slate-700'}`}>
                                        {totalQuantity}
                                    </span>
                                </div>
                                <div className="text-[10px] uppercase text-slate-500 font-bold">
                                    К отправке
                                </div>
                            </div>
                            <button
                                onClick={() => setShowCartDrawer(true)}
                                className="flex-1 bg-white text-slate-950 font-bold py-3 rounded-xl uppercase tracking-wider text-sm active:scale-95 transition-transform"
                            >
                                Перейти
                            </button>
                        </div>

                        {/* === MOBILE CART DRAWER (Send) === */}
                        {showCartDrawer && (
                            <div className="md:hidden fixed inset-0 z-[70] bg-slate-950/90 backdrop-blur-sm flex flex-col animate-in fade-in duration-200">
                                <div className="flex-1 flex flex-col bg-slate-900 mt-12 rounded-t-3xl overflow-hidden shadow-2xl border-t border-slate-800 animate-in slide-in-from-bottom duration-300">
                                    {/* Header */}
                                    <div className="p-6 border-b border-slate-800 flex justify-between items-center bg-slate-900">
                                        <h2 className="text-xl font-black text-white uppercase">Отправка</h2>
                                        <button onClick={() => setShowCartDrawer(false)} className="p-2 bg-slate-800 rounded-full text-slate-400">
                                            <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" /></svg>
                                        </button>
                                    </div>

                                    {/* Warehouse Select in Drawer */}
                                    <div className="p-4 bg-slate-950/50 border-b border-slate-800">
                                        <label className="text-[10px] font-bold text-slate-500 uppercase tracking-widest mb-2 block">Куда отправить</label>
                                        <select
                                            value={targetWarehouse}
                                            onChange={e => setTargetWarehouse(e.target.value)}
                                            className="w-full bg-slate-900 border border-slate-700 rounded-xl px-4 py-3 text-white text-sm font-bold focus:border-indigo-500 outline-none transition-colors appearance-none"
                                        >
                                            <option value="">-- Выберите склад --</option>
                                            {warehouses
                                                .filter(w => {
                                                    if (!currentWarehouseId) return false
                                                    if (w.id === currentWarehouseId) return false
                                                    // Only show warehouses from the same group
                                                    const currentWh = warehouses.find(wh => wh.id === currentWarehouseId)
                                                    if (currentWh?.groupId && w.groupId) {
                                                        return w.groupId === currentWh.groupId
                                                    }
                                                    return false
                                                })
                                                .map(w => (
                                                    <option key={w.id} value={w.id}>{w.name}</option>
                                                ))}
                                        </select>
                                    </div>

                                    {/* Content */}
                                    <div className="flex-1 overflow-y-auto p-4 custom-scrollbar bg-slate-900">
                                        {cart.length === 0 ? (
                                            <div className="flex flex-col items-center justify-center py-12 text-slate-600 opacity-50 space-y-4">
                                                <p className="text-sm font-bold uppercase tracking-widest text-center">Пусто</p>
                                            </div>
                                        ) : (
                                            cart.map(item => (
                                                <div key={item.product.id} className="bg-slate-950/50 rounded-xl p-4 border border-slate-800 mb-4">
                                                    <div className="flex justify-between items-start mb-3">
                                                        <div>
                                                            <h4 className="text-sm font-bold text-white line-clamp-1">{item.product.name}</h4>
                                                            <span className="text-[10px] font-mono text-slate-500">{item.product.barcode}</span>
                                                        </div>
                                                        <button onClick={() => removeFromCart(item.product.id)} className="text-red-500 p-1"><svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" /></svg></button>
                                                    </div>

                                                    <div className="flex items-center justify-between border-t border-slate-800 pt-3">
                                                        <div className="flex items-center gap-2">
                                                            <button onClick={() => updateQuantity(item.product.id, item.quantity - 1)} className="w-8 h-8 bg-slate-800 rounded text-white">-</button>
                                                            <span className="font-bold text-white w-8 text-center">{item.quantity}</span>
                                                            <button onClick={() => updateQuantity(item.product.id, item.quantity + 1)} className="w-8 h-8 bg-slate-800 rounded text-white">+</button>
                                                        </div>
                                                    </div>
                                                </div>
                                            ))
                                        )}
                                    </div>

                                    {/* Footer */}
                                    <div className="p-6 bg-slate-900 border-t border-slate-800 space-y-4">
                                        <input
                                            placeholder="Примечание..."
                                            value={note}
                                            onChange={e => setNote(e.target.value)}
                                            className="w-full bg-slate-950 border-b border-slate-800 text-sm text-white px-2 py-3 placeholder:text-slate-600 focus:border-indigo-500 outline-none transition-colors"
                                        />
                                        <button
                                            onClick={() => { handleSendTransfer(); setShowCartDrawer(false); }}
                                            disabled={loading || cart.length === 0 || !targetWarehouse}
                                            className="w-full py-4 bg-indigo-600 hover:bg-indigo-500 text-white font-black uppercase tracking-widest rounded-xl disabled:opacity-50"
                                        >
                                            {loading ? "..." : "Отправить"}
                                        </button>
                                    </div>
                                </div>
                            </div>
                        )}

                        {/* RIGHT: Transfer Cart (Desktop) */}
                        <div className="hidden md:flex w-[480px] shrink-0 h-full flex-col justify-start pb-6">
                            <div className="bg-slate-900 border border-slate-800 rounded-xl shadow-[0_20px_50px_-12px_rgba(0,0,0,0.5)] overflow-hidden flex flex-col max-h-full">
                                {/* Format Header */}
                                <div className="p-6 border-b border-slate-800 bg-slate-950/30">
                                    <label className="text-[10px] font-bold text-slate-500 uppercase tracking-widest mb-2 block">Куда отправить</label>
                                    <select
                                        value={targetWarehouse}
                                        onChange={e => setTargetWarehouse(e.target.value)}
                                        className="w-full bg-slate-950 border border-slate-700/50 rounded-lg px-4 py-3 text-white text-sm font-bold focus:border-indigo-500 outline-none transition-colors appearance-none cursor-pointer hover:border-slate-600 focus:ring-1 focus:ring-indigo-500/20"
                                    >
                                        <option value="">-- Выберите склад --</option>
                                        {warehouses
                                            .filter(w => {
                                                if (!currentWarehouseId) return false
                                                if (w.id === currentWarehouseId) return false
                                                const currentWh = warehouses.find(wh => wh.id === currentWarehouseId)
                                                if (currentWh?.groupId && w.groupId) {
                                                    return w.groupId === currentWh.groupId
                                                }
                                                return false
                                            })
                                            .map(w => (
                                                <option key={w.id} value={w.id}>{w.name}</option>
                                            ))}
                                    </select>
                                </div>

                                {/* Items List */}
                                <div className="overflow-y-auto p-6 space-y-4 custom-scrollbar min-h-0">
                                    {cart.length === 0 ? (
                                        <div className="flex flex-col items-center justify-center py-12 text-slate-600 opacity-50 space-y-4">
                                            <p className="text-sm font-bold uppercase tracking-widest text-center">Переместите товары<br />в эту область</p>
                                        </div>
                                    ) : (
                                        cart.map(item => (
                                            <div key={item.product.id} className="bg-slate-950/50 rounded-xl p-4 border border-slate-800 hover:border-slate-700 transition-colors group relative select-none">
                                                <button
                                                    onClick={() => removeFromCart(item.product.id)}
                                                    className="absolute -right-2 -top-2 w-6 h-6 bg-slate-800 hover:bg-red-500 text-slate-400 hover:text-white rounded-full flex items-center justify-center shadow-lg transition-colors border border-slate-700 opacity-0 group-hover:opacity-100 z-10"
                                                >
                                                    <svg className="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" /></svg>
                                                </button>

                                                <div className="flex justify-between items-start mb-3 pr-2">
                                                    <h4 className="text-sm font-bold text-white line-clamp-1">{item.product.name}</h4>
                                                    <span className="text-[10px] font-mono text-slate-500 bg-slate-900 px-1.5 py-0.5 rounded border border-slate-800">{item.product.barcode}</span>
                                                </div>

                                                <div className="flex items-center justify-between">
                                                    <span className="text-[10px] font-bold text-slate-500 uppercase">Количество</span>
                                                    <div className="flex items-center">
                                                        <button onClick={() => updateQuantity(item.product.id, item.quantity - 1)} className="w-8 h-8 bg-slate-800 rounded-l-lg text-slate-400 hover:text-white hover:bg-slate-700">-</button>
                                                        <div className="w-12 h-8 bg-slate-900 border-y border-slate-700 text-center flex items-center justify-center text-sm font-black text-white">{item.quantity}</div>
                                                        <button onClick={() => updateQuantity(item.product.id, item.quantity + 1)} className="w-8 h-8 bg-slate-800 rounded-r-lg text-slate-400 hover:text-white hover:bg-slate-700">+</button>
                                                    </div>
                                                </div>
                                            </div>
                                        ))
                                    )}
                                </div>

                                {/* Footer */}
                                <div className="p-6 bg-slate-900 border-t border-slate-800 shrink-0 space-y-4">
                                    <input
                                        placeholder="Примечание к перемещению..."
                                        value={note}
                                        onChange={e => setNote(e.target.value)}
                                        className="w-full bg-slate-950 border-b border-slate-800 text-xs text-white px-0 py-2 placeholder:text-slate-600 focus:border-indigo-500 outline-none transition-colors"
                                    />
                                    <div className="flex justify-between items-center">
                                        <span className="text-xs font-bold text-slate-500 uppercase">Всего товаров</span>
                                        <span className="text-xl font-black text-white">{totalQuantity} <span className="text-xs text-slate-600">шт</span></span>
                                    </div>
                                    <button
                                        onClick={handleSendTransfer}
                                        disabled={loading || cart.length === 0 || !targetWarehouse}
                                        className="w-full py-4 bg-indigo-600 hover:bg-indigo-500 text-white font-black uppercase tracking-widest rounded-xl transition-all shadow-lg shadow-indigo-500/20 disabled:opacity-50 disabled:cursor-not-allowed active:scale-[0.98]"
                                    >
                                        {loading ? "Отправка..." : "Отправить"}
                                    </button>
                                </div>
                            </div>
                        </div>
                    </div>
                )}

                {/* VIEW: INCOMING (Same as previous) */}
                {activeTab === "incoming" && (
                    <div className="absolute inset-0 overflow-y-auto p-2 sm:p-12 custom-scrollbar pb-24">
                        <div className="max-w-4xl mx-auto space-y-4 md:space-y-6">
                            <h2 className="text-xl md:text-2xl font-black text-white uppercase tracking-tight mb-4 md:mb-8 px-2 md:px-0">Входящие перемещения</h2>
                            {/* No major changes needed for Card component, relying on its internal flex layout */}
                            {incomingTransfers.length === 0 ? (
                                <div className="text-center py-20 opacity-30">
                                    <p className="text-xl font-bold text-slate-100 uppercase">Нет новых поступлений</p>
                                </div>
                            ) : (
                                incomingTransfers.map(t => (
                                    <IncomingTransferCard
                                        key={t.id}
                                        transfer={t}
                                        onAccept={handleAccept}
                                        onReject={handleReject}
                                        loading={loading}
                                    />
                                ))
                            )}
                        </div>
                    </div>
                )}

                {/* VIEW: HISTORY (Cards for Mobile, Table for Desktop) */}
                {activeTab === "history" && (
                    <div className="absolute inset-0 overflow-y-auto p-2 md:p-6 custom-scrollbar pb-24">
                        <div className="max-w-5xl mx-auto bg-slate-900/50 md:bg-slate-900 border-none md:border md:border-slate-800 rounded-3xl overflow-hidden">
                            {/* Desktop Table */}
                            <table className="hidden md:table w-full">
                                <thead className="bg-slate-950 border-b border-slate-800">
                                    <tr>
                                        <th className="text-left text-[10px] font-black text-slate-500 uppercase tracking-widest p-6">Товар</th>
                                        <th className="text-left text-[10px] font-black text-slate-500 uppercase tracking-widest p-6 hidden sm:table-cell">Маршрут</th>
                                        <th className="text-center text-[10px] font-black text-slate-500 uppercase tracking-widest p-6">Кол-во</th>
                                        <th className="text-center text-[10px] font-black text-slate-500 uppercase tracking-widest p-6">Статус</th>
                                        <th className="text-right text-[10px] font-black text-slate-500 uppercase tracking-widest p-6">Дата</th>
                                    </tr>
                                </thead>
                                <tbody className="divide-y divide-slate-800/50">
                                    {history.map(t => (
                                        <tr key={t.id} className="hover:bg-slate-800/30 transition-colors">
                                            <td className="p-6">
                                                <div className="font-bold text-slate-200 text-sm">{t.product.name}</div>
                                                <div className="sm:hidden text-xs text-slate-500 mt-1">{t.fromWarehouse.name} → {t.toWarehouse.name}</div>
                                            </td>
                                            <td className="p-6 hidden sm:table-cell">
                                                <div className="flex items-center gap-2 text-xs text-slate-400">
                                                    <span>{t.fromWarehouse.name}</span>
                                                    <svg className="w-3 h-3 text-slate-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 8l4 4m0 0l-4 4m4-4H3" /></svg>
                                                    <span>{t.toWarehouse.name}</span>
                                                </div>
                                            </td>
                                            <td className="p-6 text-center font-bold text-white">{t.quantity}</td>
                                            <td className="p-6 text-center">
                                                <span className={`inline-block px-3 py-1 rounded-full text-[10px] font-black uppercase tracking-wider border ${t.status === "COMPLETED" ? "bg-emerald-500/10 text-emerald-500 border-emerald-500/20" :
                                                    t.status === "PENDING" ? "bg-amber-500/10 text-amber-500 border-amber-500/20" :
                                                        "bg-red-500/10 text-red-500 border-red-500/20"
                                                    }`}>
                                                    {t.status === "COMPLETED" ? "Принят" : t.status === "PENDING" ? "В пути" : "Отмена"}
                                                </span>
                                            </td>
                                            <td className="p-6 text-right text-xs text-slate-500 font-mono">
                                                {new Date(t.createdAt).toLocaleDateString()}
                                            </td>
                                        </tr>
                                    ))}
                                </tbody>
                            </table>

                            {/* Mobile List Cards */}
                            <div className="md:hidden space-y-4">
                                {history.map(t => (
                                    <div key={t.id} className="bg-slate-900 p-4 rounded-2xl border border-slate-800 shadow-sm">
                                        <div className="flex justify-between items-start mb-3">
                                            <div>
                                                <span className={`inline-block px-2 py-0.5 mb-2 rounded text-[9px] font-black uppercase tracking-wider border ${t.status === "COMPLETED" ? "bg-emerald-500/10 text-emerald-500 border-emerald-500/20" :
                                                    t.status === "PENDING" ? "bg-amber-500/10 text-amber-500 border-amber-500/20" :
                                                        "bg-red-500/10 text-red-500 border-red-500/20"
                                                    }`}>
                                                    {t.status === "COMPLETED" ? "Принят" : t.status === "PENDING" ? "В пути" : "Отмена"}
                                                </span>
                                                <h4 className="font-bold text-white text-sm line-clamp-2">{t.product.name}</h4>
                                            </div>
                                            <span className="text-xs font-mono text-slate-500">{new Date(t.createdAt).toLocaleDateString()}</span>
                                        </div>
                                        <div className="flex justify-between items-center text-xs text-slate-400 bg-slate-950/50 p-3 rounded-xl">
                                            <div className="flex items-center gap-2">
                                                <span>{t.fromWarehouse.name}</span>
                                                <span>→</span>
                                                <span>{t.toWarehouse.name}</span>
                                            </div>
                                            <span className="font-black text-white text-sm">{t.quantity} шт</span>
                                        </div>
                                    </div>
                                ))}
                            </div>

                            {history.length === 0 && <div className="p-12 text-center text-slate-600 font-bold uppercase tracking-widest text-xs">История пуста</div>}
                        </div>
                    </div>
                )}
            </div>
        </div>
    )
}
