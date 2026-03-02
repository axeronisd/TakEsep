"use client"

import { useState, useEffect, useRef } from "react"
import { toast } from "sonner"
import { useBarcodeScanner } from "@/lib/useBarcodeScanner"

interface Product {
    id: string
    name: string
    barcode: string
    stock: number
    sellPrice: number
}

interface CartItem {
    product: Product
    quantity: number
    discount: number
    discountType: 'percent' | 'fixed' // 'percent' = %, 'fixed' = soms
}


// Repair Modal
const RepairModal = ({ isOpen, onClose }: { isOpen: boolean, onClose: () => void }) => {
    const [loading, setLoading] = useState(false)
    const [amount, setAmount] = useState("")
    const [description, setDescription] = useState("")
    const [employees, setEmployees] = useState<{ id: string, name: string }[]>([])
    const [selectedEmployeeId, setSelectedEmployeeId] = useState("")

    useEffect(() => {
        if (isOpen) {
            fetch("/api/employees")
                .then(res => res.json())
                .then(data => {
                    if (Array.isArray(data)) setEmployees(data)
                })
                .catch(console.error)
        }
    }, [isOpen])

    if (!isOpen) return null

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault()
        setLoading(true)
        try {
            const res = await fetch("/api/finance", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                    amount: parseFloat(amount),
                    type: "REPAIR",
                    description: description || "Ремонт/Услуга",
                    employeeId: selectedEmployeeId || undefined
                })
            })
            if (!res.ok) throw new Error("Ошибка")
            toast.success("Услуга записана")
            onClose()
            setAmount(""); setDescription(""); setSelectedEmployeeId("")
        } catch {
            toast.error("Ошибка записи")
        } finally {
            setLoading(false)
        }
    }

    return (
        <div className="fixed inset-0 bg-black/70 backdrop-blur-sm z-[80] flex items-center justify-center p-4" onClick={onClose}>
            <div className="bg-slate-900 border border-slate-700 rounded-2xl p-6 w-full max-w-sm" onClick={e => e.stopPropagation()}>
                <h3 className="text-lg font-black text-white uppercase tracking-wide mb-4">Запись услуги</h3>
                <form onSubmit={handleSubmit} className="space-y-3">
                    <div className="space-y-1">
                        <label className="text-[10px] font-bold text-slate-500 uppercase tracking-widest">Сумма</label>
                        <input type="number" autoFocus value={amount} onChange={e => setAmount(e.target.value)} required className="w-full bg-slate-800 border-slate-700 rounded-xl px-4 py-3 text-xl font-bold text-white placeholder:text-slate-600" placeholder="0" />
                    </div>

                    <div className="space-y-1">
                        <label className="text-[10px] font-bold text-slate-500 uppercase tracking-widest">Сотрудник (кто сделал)</label>
                        <select
                            value={selectedEmployeeId}
                            onChange={e => setSelectedEmployeeId(e.target.value)}
                            className="w-full bg-slate-800 border-slate-700 rounded-xl px-4 py-3 text-white font-bold outline-none appearance-none"
                        >
                            <option value="">-- Не выбрано --</option>
                            {employees.map(emp => (
                                <option key={emp.id} value={emp.id}>{emp.name}</option>
                            ))}
                        </select>
                    </div>

                    <div className="space-y-1">
                        <label className="text-[10px] font-bold text-slate-500 uppercase tracking-widest">Описание работы</label>
                        <textarea value={description} onChange={e => setDescription(e.target.value)} rows={3} className="w-full bg-slate-800 border-slate-700 rounded-xl px-4 py-3 text-white placeholder:text-slate-600" placeholder="Замена камеры, ремонт..." />
                    </div>
                    <button disabled={loading} className="w-full bg-indigo-600 hover:bg-indigo-500 text-white font-bold py-3 rounded-xl uppercase tracking-widest transition-colors mt-2">
                        {loading ? "..." : "Записать"}
                    </button>
                </form>
            </div>
        </div>
    )
}

export default function SalesPage() {
    const [cart, setCart] = useState<CartItem[]>([])
    const [products, setProducts] = useState<Product[]>([])
    const [loading, setLoading] = useState(false)
    const [searchQuery, setSearchQuery] = useState("")
    const [isRepairOpen, setIsRepairOpen] = useState(false)
    const searchInputRef = useRef<HTMLInputElement>(null)

    useEffect(() => {
        fetch("/api/products")
            .then(res => res.json())
            .then(data => {
                if (Array.isArray(data)) setProducts(data)
                else setProducts([])
            })
            .catch(() => setProducts([]))
    }, [])

    // Barcode scanner: auto-add to cart when scanned
    useBarcodeScanner({
        onScan: (barcode) => {
            const product = products.find(p => p.barcode === barcode)
            if (product) {
                addToCart(product)
                toast.success(`✅ ${product.name} добавлен`)
            } else {
                setSearchQuery(barcode)
                toast.error(`Товар с кодом ${barcode} не найден`)
            }
        }
    })

    const addToCart = (product: Product) => {
        if (product.stock <= 0) {
            toast.error("Товара нет в наличии")
            return
        }

        const existing = cart.find(item => item.product.id === product.id)
        if (existing) {
            setCart(cart.map(item =>
                item.product.id === product.id
                    ? { ...item, quantity: item.quantity + 1 }
                    : item
            ))
        } else {
            setCart([...cart, { product, quantity: 1, discount: 0, discountType: 'fixed' }])
        }
    }

    const updateQuantity = (productId: string, value: number | string) => {
        setCart(cart.map(item => {
            if (item.product.id === productId) {
                let newQty = typeof value === "number" ? item.quantity + value : parseInt(value)
                if (isNaN(newQty)) return item
                newQty = Math.max(0, newQty)
                return { ...item, quantity: newQty }
            }
            return item
        }).filter(item => item.quantity > 0))
    }

    const updateDiscount = (productId: string, value: string) => {
        setCart(cart.map(item => {
            if (item.product.id === productId) {
                const newDisc = parseFloat(value)
                if (isNaN(newDisc)) return { ...item, discount: 0 }
                const maxDiscount = item.discountType === 'percent' ? 100 : item.product.sellPrice * item.quantity
                return { ...item, discount: Math.min(maxDiscount, Math.max(0, newDisc)) }
            }
            return item
        }))
    }

    const toggleDiscountType = (productId: string) => {
        setCart(cart.map(item => {
            if (item.product.id === productId) {
                return { ...item, discount: 0, discountType: item.discountType === 'percent' ? 'fixed' : 'percent' }
            }
            return item
        }))
    }

    const removeFromCart = (productId: string) => {
        setCart(cart.filter(item => item.product.id !== productId))
    }

    const getItemTotal = (item: CartItem) => {
        const subtotal = item.product.sellPrice * item.quantity
        if (item.discountType === 'fixed') {
            return subtotal - item.discount
        }
        return subtotal - (subtotal * item.discount / 100)
    }

    const getTotal = () => {
        return cart.reduce((sum, item) => sum + getItemTotal(item), 0)
    }

    const completeSale = async () => {
        if (cart.length === 0) return
        setLoading(true)

        try {
            const response = await fetch("/api/sales", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                    items: cart.map(item => {
                        // Calculate actual price per unit after discount
                        const totalDiscount = item.discountType === 'fixed'
                            ? item.discount
                            : (item.product.sellPrice * item.quantity * item.discount / 100)
                        const actualTotal = item.product.sellPrice * item.quantity - totalDiscount
                        const actualPricePerUnit = actualTotal / item.quantity

                        return {
                            productId: item.product.id,
                            quantity: item.quantity,
                            discount: item.discount,
                            discountType: item.discountType,
                            price: actualPricePerUnit
                        }
                    })
                })
            })

            if (response.ok) {
                setCart([])
                const updated = await fetch("/api/products").then(r => r.json())
                setProducts(updated)
                toast.success("Продажа оформлена! 🎉")
            } else {
                toast.error("Ошибка оформления")
            }
        } catch {
            toast.error("Ошибка сети")
        } finally {
            setLoading(false)
        }
    }

    const [isMobileCartOpen, setIsMobileCartOpen] = useState(false)

    const filteredProducts = Array.isArray(products) ? products.filter(p =>
        p.stock > 0 &&
        (p.name.toLowerCase().includes(searchQuery.toLowerCase()) || p.barcode.includes(searchQuery))
    ) : []

    const isInCart = (productId: string) => cart.some(item => item.product.id === productId)
    const totalQuantity = cart.reduce((a, c) => a + c.quantity, 0)
    const totalAmount = getTotal()

    return (
        <div className="flex h-[calc(100vh-8rem)] md:h-[calc(100vh-5rem)] bg-slate-950 flex-col md:flex-row p-2 md:p-6 gap-2 md:gap-6 font-sans relative mt-28 md:mt-0 overflow-y-auto md:overflow-hidden">
            {/* === LEFT: Product Selector === */}
            <div className="flex-1 flex flex-col min-w-0 gap-4 md:gap-6">
                {/* Search & Actions */}
                <div className="bg-slate-900/30 rounded-2xl md:rounded-3xl border border-slate-800/50 backdrop-blur-sm p-4 md:p-6 shrink-0 shadow-sm relative z-10 flex flex-col md:flex-row gap-4">
                    <div className="relative flex-1">
                        <input
                            ref={searchInputRef}
                            type="text"
                            value={searchQuery}
                            onChange={(e) => setSearchQuery(e.target.value)}
                            placeholder="Поиск..."
                            className="w-full px-4 py-3 md:px-5 md:py-4 !bg-slate-900 !border-slate-700/50 rounded-xl md:rounded-2xl text-base md:text-lg font-medium !text-white placeholder:text-slate-500 focus:outline-none focus:ring-4 focus:ring-indigo-500/20 focus:border-indigo-500 transition-all shadow-sm appearance-none"
                        />
                        {searchQuery && (
                            <button
                                onClick={() => setSearchQuery('')}
                                className="absolute right-4 top-1/2 -translate-y-1/2 text-slate-500 hover:text-white transition-colors"
                            >
                                <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" /></svg>
                            </button>
                        )}
                    </div>
                    <button
                        onClick={() => setIsRepairOpen(true)}
                        className="bg-indigo-600 hover:bg-indigo-500 text-white font-bold px-6 py-3 rounded-xl uppercase tracking-widest shadow-lg shadow-indigo-500/20 active:scale-95 transition-all flex items-center gap-2 justify-center"
                    >
                        <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" /><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" /></svg>
                        <span>Услуга</span>
                    </button>
                </div>

                {/* Grid */}
                <div className="flex-1 pb-24 md:pb-24 px-1 md:px-2 md:overflow-y-auto md:custom-scrollbar">
                    <div className="grid grid-cols-2 md:grid-cols-3 xl:grid-cols-4 gap-3 md:gap-6 p-1 md:p-2">
                        {filteredProducts.map(product => {
                            const inCart = isInCart(product.id)
                            return (
                                <div
                                    key={product.id}
                                    onClick={() => addToCart(product)}
                                    role="button"
                                    className={`group relative flex flex-col justify-between text-left bg-slate-900 rounded-xl md:rounded-2xl border transition-all duration-200 cursor-pointer select-none overflow-hidden hover:bg-slate-800 ${inCart
                                        ? 'border-indigo-500 shadow-[0_0_15px_rgba(99,102,241,0.5)] ring-1 ring-indigo-500 bg-slate-800'
                                        : 'border-slate-800/60 hover:border-slate-600 hover:shadow-lg hover:shadow-indigo-500/5'
                                        }`}
                                    style={{ height: '180px' }}
                                >
                                    {/* Top Row: Barcode & Stock */}
                                    <div className="flex justify-between items-start pt-3 px-3 md:pt-4 md:px-4 relative z-10 w-full">
                                        <span className="text-[9px] md:text-[10px] font-bold tracking-wider text-slate-400 font-mono bg-slate-950/80 px-1.5 py-0.5 md:px-2 md:py-1 rounded-md border border-slate-800/50 backdrop-blur-sm max-w-[50%] truncate transition-colors group-hover:bg-slate-950">
                                            {product.barcode}
                                        </span>
                                        <span className={`text-[9px] md:text-[10px] font-bold px-1.5 py-0.5 md:px-2 md:py-1 rounded-md border backdrop-blur-sm whitespace-nowrap ${product.stock <= 5
                                            ? 'bg-red-500/10 border-red-500/20 text-red-500'
                                            : 'bg-emerald-500/10 border-emerald-500/20 text-emerald-400'
                                            }`}>
                                            {product.stock} шт
                                        </span>
                                    </div>

                                    {/* Middle: Name */}
                                    <div className="px-3 md:px-4 flex-1 flex flex-col justify-center w-full">
                                        <h3 className="text-xs md:text-sm font-bold text-slate-200 leading-snug group-hover:text-white transition-colors line-clamp-3 text-center break-words">
                                            {product.name}
                                        </h3>
                                    </div>

                                    {/* Bottom: Price Section */}
                                    <div className="mt-auto p-3 pt-2 md:p-4 md:pt-3 bg-gradient-to-t from-slate-950/80 to-transparent border-t border-slate-800/30 flex items-center justify-center relative w-full">
                                        <div className="flex items-baseline gap-1 md:gap-1.5 duration-300 origin-bottom">
                                            <span className="text-xl md:text-2xl font-black text-white tracking-tight drop-shadow-lg group-hover:text-indigo-200 transition-colors">
                                                {product.sellPrice.toLocaleString()}
                                            </span>
                                            <span className="text-[8px] md:text-[10px] uppercase text-slate-500 font-bold tracking-widest mb-1">
                                                сом
                                            </span>
                                        </div>
                                    </div>
                                </div>
                            )
                        })}
                    </div>
                </div>
            </div>

            {/* === MOBILE: Bottom Sticky Bar === */}
            <div className="md:hidden fixed bottom-0 left-0 right-0 p-4 bg-slate-900 border-t border-slate-800 z-[60] flex items-center gap-4 shadow-[0_-10px_40px_rgba(0,0,0,0.5)] safe-area-bottom">
                <div className="flex items-center gap-3" onClick={() => setIsMobileCartOpen(true)}>
                    <div className="relative">
                        <span className={`flex items-center justify-center min-w-[3rem] h-10 px-3 rounded-xl font-bold border ${totalQuantity > 0 ? 'bg-indigo-600 text-white border-indigo-500' : 'bg-slate-800 text-slate-500 border-slate-700'}`}>
                            {totalQuantity}
                        </span>
                    </div>
                    <div>
                        <p className="text-[10px] uppercase text-slate-500 font-bold">Итого</p>
                        <p className="text-lg font-black text-white leading-none">{totalAmount.toLocaleString()} c</p>
                    </div>
                </div>
                <button
                    onClick={() => setIsMobileCartOpen(true)}
                    className="flex-1 bg-white text-slate-950 font-bold py-3 rounded-xl uppercase tracking-wider text-sm active:scale-95 transition-transform"
                >
                    Открыть
                </button>
            </div>

            {/* === MOBILE CART DRAWER (Modal) === */}
            {isMobileCartOpen && (
                <div className="md:hidden fixed inset-0 z-[70] bg-slate-950/90 backdrop-blur-sm flex flex-col animate-in fade-in duration-200">
                    <div className="flex-1 flex flex-col bg-slate-900 mt-12 rounded-t-3xl overflow-hidden shadow-2xl border-t border-slate-800 animate-in slide-in-from-bottom duration-300">
                        {/* Drawer Header */}
                        <div className="p-6 border-b border-slate-800 flex justify-between items-center bg-slate-900">
                            <h2 className="text-xl font-black text-white uppercase">Корзина</h2>
                            <button onClick={() => setIsMobileCartOpen(false)} className="p-2 bg-slate-800 rounded-full text-slate-400">
                                <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" /></svg>
                            </button>
                        </div>

                        {/* Drawer Content (Reusing Cart Logic) */}
                        <div className="flex-1 overflow-y-auto p-4 custom-scrollbar bg-slate-900">
                            {/* ... Same cart items mapping as desktop ... */}
                            {cart.length === 0 ? (
                                <div className="flex flex-col items-center justify-center py-12 text-slate-600 opacity-50 space-y-4">
                                    <p className="text-sm font-bold uppercase tracking-widest">Список пуст</p>
                                </div>
                            ) : (
                                cart.map((item) => (
                                    <div key={item.product.id} className="bg-slate-950/50 rounded-xl p-4 border border-slate-800 mb-4">
                                        <div className="flex justify-between items-start mb-3 pr-2">
                                            <h4 className="text-sm font-bold text-white line-clamp-1">{item.product.name}</h4>
                                            <button onClick={() => removeFromCart(item.product.id)} className="text-red-500 p-1"><svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" /></svg></button>
                                        </div>
                                        <div className="grid grid-cols-[1.5fr_1fr] gap-4 mb-2">
                                            <div className="space-y-1">
                                                <label className="text-[9px] uppercase font-bold text-slate-500">Кол-во</label>
                                                <div className="flex items-center">
                                                    <button onClick={() => updateQuantity(item.product.id, -1)} className="w-10 h-10 bg-slate-800 rounded-l-lg text-white font-bold">−</button>
                                                    <input type="number" readOnly value={item.quantity} className="w-full h-10 bg-slate-900 text-center text-white" />
                                                    <button onClick={() => updateQuantity(item.product.id, 1)} className="w-10 h-10 bg-slate-800 rounded-r-lg text-white font-bold">+</button>
                                                </div>
                                            </div>
                                            <div className="space-y-1">
                                                <div className="flex justify-between items-center">
                                                    <label className="text-[9px] uppercase font-bold text-slate-500">Скидка</label>
                                                </div>
                                                <div className="flex gap-1">
                                                    <button
                                                        onClick={() => toggleDiscountType(item.product.id)}
                                                        className={`h-10 px-3 rounded-lg font-bold text-xs flex items-center gap-1 transition-all ${item.discountType === 'percent' ? 'bg-emerald-600 text-white' : 'bg-amber-600 text-white'}`}
                                                    >
                                                        {item.discountType === 'percent' ? '%' : 'сом'}
                                                        <svg className="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 9l4-4 4 4m0 6l-4 4-4-4" /></svg>
                                                    </button>
                                                    <input type="number" value={item.discount} onChange={e => updateDiscount(item.product.id, e.target.value)} className="flex-1 h-10 bg-slate-900 text-center text-emerald-400 border border-slate-700 rounded-lg" />
                                                </div>
                                            </div>
                                        </div>
                                        <div className="text-right pt-2 border-t border-slate-800/50">
                                            <span className="text-base font-black text-white">{getItemTotal(item).toLocaleString()} с</span>
                                        </div>
                                    </div>
                                ))
                            )}
                        </div>

                        {/* Drawer Footer */}
                        <div className="p-6 bg-slate-900 border-t border-slate-800">
                            <div className="flex justify-between items-center mb-6">
                                <span className="text-slate-400 font-bold uppercase text-xs">Итого к оплате:</span>
                                <span className="text-3xl font-black text-white tracking-tight">{totalAmount.toLocaleString()} сом</span>
                            </div>
                            <button
                                onClick={() => { completeSale(); setIsMobileCartOpen(false); }}
                                disabled={cart.length === 0 || loading}
                                className="w-full py-5 bg-gradient-to-r from-indigo-600 to-violet-600 text-white font-black uppercase tracking-[0.2em] rounded-2xl shadow-lg disabled:opacity-50"
                            >
                                {loading ? "..." : "Оплатить"}
                            </button>
                        </div>
                    </div>
                </div>
            )}


            {/* === RIGHT: Cart (Desktop Sidebar - UNCHANGED) === */}
            <div className="hidden md:flex w-[480px] shrink-0 h-full pointer-events-none flex-col justify-start pb-6">
                {/* Cart Container */}
                <div className="pointer-events-auto flex flex-col bg-slate-900 border border-slate-800 rounded-3xl shadow-[0_20px_50px_-12px_rgba(0,0,0,0.5)] overflow-hidden max-h-full">

                    {/* Header */}
                    <div className="px-8 py-6 border-b border-slate-800 bg-slate-900/50 backdrop-blur sticky top-0 z-20 flex justify-between items-center shrink-0">
                        <div>
                            <h2 className="text-xl font-black text-white uppercase tracking-wide">Корзина</h2>
                            <p className="text-xs text-slate-500 mt-1">Оформление продажи</p>
                        </div>
                        <span className={`px-3 py-1 rounded-full text-xs font-bold font-mono border ${totalQuantity > 0 ? 'bg-indigo-500/10 text-indigo-400 border-indigo-500/20' : 'bg-slate-800 text-slate-500 border-slate-700'}`}>
                            {totalQuantity} шт
                        </span>
                    </div>

                    {/* Cart Items */}
                    <div className="overflow-y-auto p-6 space-y-4 custom-scrollbar min-h-0 bg-slate-900">
                        {cart.length === 0 ? (
                            <div className="flex flex-col items-center justify-center py-12 text-slate-600 opacity-50 space-y-4">
                                <p className="text-sm font-bold uppercase tracking-widest">Список пуст</p>
                            </div>
                        ) : (
                            cart.map((item) => (
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

                                    <div className="grid grid-cols-[1.5fr_1fr] gap-4 mb-2">
                                        {/* Qty */}
                                        <div className="space-y-1">
                                            <label className="text-[9px] uppercase font-bold text-slate-500">Кол-во</label>
                                            <div className="flex items-center">
                                                <button onClick={() => updateQuantity(item.product.id, -1)} className="w-10 h-9 bg-slate-800 rounded-l-lg text-slate-400 hover:text-white hover:bg-slate-700 text-lg font-bold flex items-center justify-center pb-1">−</button>
                                                <input
                                                    type="number"
                                                    value={item.quantity}
                                                    onChange={e => updateQuantity(item.product.id, e.target.value)}
                                                    className="w-full h-9 bg-slate-900 border-y border-slate-700 text-center text-sm font-black text-white outline-none"
                                                />
                                                <button onClick={() => updateQuantity(item.product.id, 1)} className="w-10 h-9 bg-slate-800 rounded-r-lg text-slate-400 hover:text-white hover:bg-slate-700 text-lg font-bold flex items-center justify-center pb-1">+</button>
                                            </div>
                                        </div>

                                        {/* Discount */}
                                        <div className="space-y-1">
                                            <label className="text-[9px] uppercase font-bold text-slate-500">Скидка</label>
                                            <div className="flex items-center gap-1">
                                                <button
                                                    onClick={() => toggleDiscountType(item.product.id)}
                                                    className={`h-9 px-3 rounded-lg font-bold text-xs flex items-center gap-1 transition-all shrink-0 ${item.discountType === 'percent' ? 'bg-emerald-600 text-white hover:bg-emerald-500' : 'bg-amber-600 text-white hover:bg-amber-500'}`}
                                                >
                                                    {item.discountType === 'percent' ? '%' : 'сом'}
                                                    <svg className="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 9l4-4 4 4m0 6l-4 4-4-4" /></svg>
                                                </button>
                                                <button onClick={() => updateDiscount(item.product.id, String(Math.max(0, item.discount - (item.discountType === 'percent' ? 1 : 10))))} className="w-8 h-9 bg-slate-800 rounded-l-lg text-slate-400 hover:text-white hover:bg-slate-700 flex items-center justify-center pb-1">−</button>
                                                <input
                                                    type="number"
                                                    value={item.discount}
                                                    onChange={e => updateDiscount(item.product.id, e.target.value)}
                                                    className="w-full h-9 bg-slate-900 border-y border-slate-700 text-center text-sm font-bold text-emerald-400 outline-none"
                                                />
                                                <button onClick={() => updateDiscount(item.product.id, String(item.discount + (item.discountType === 'percent' ? 1 : 10)))} className="w-8 h-9 bg-slate-800 rounded-r-lg text-slate-400 hover:text-white hover:bg-slate-700 flex items-center justify-center pb-1">+</button>
                                            </div>
                                        </div>
                                    </div>

                                    <div className="text-right pt-2 border-t border-slate-800/50">
                                        <span className="text-base font-black text-white">{getItemTotal(item).toLocaleString()} <span className="text-[10px] text-slate-500 font-bold uppercase">сом</span></span>
                                    </div>
                                </div>
                            ))
                        )}
                    </div>

                    {/* Footer */}
                    <div className="p-6 bg-slate-900 border-t border-slate-800 shrink-0">
                        <div className="flex justify-between items-center mb-6">
                            <span className="text-slate-400 font-bold uppercase text-xs">Итого к оплате:</span>
                            <span className="text-3xl font-black text-white tracking-tight">{totalAmount.toLocaleString()} <span className="text-sm text-slate-500 font-bold">сом</span></span>
                        </div>
                        <button
                            onClick={completeSale}
                            disabled={cart.length === 0 || loading}
                            className="w-full py-5 bg-gradient-to-r from-indigo-600 to-violet-600 hover:from-indigo-500 hover:to-violet-500 text-white font-black uppercase tracking-[0.2em] rounded-2xl shadow-lg shadow-indigo-500/20 disabled:opacity-50 disabled:cursor-not-allowed transition-all active:scale-[0.98] hover:-translate-y-1"
                        >
                            {loading ? "..." : "Оформить продажу"}
                        </button>
                    </div>
                </div>
            </div>

            <RepairModal isOpen={isRepairOpen} onClose={() => setIsRepairOpen(false)} />
        </div>
    )
}
