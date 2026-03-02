"use client"

import { useState, useEffect, useRef } from "react"
import { toast } from "sonner"
import { useBarcodeScanner, generateEAN13 } from "@/lib/useBarcodeScanner"

interface Product {
    id: string
    name: string
    barcode: string
    stock: number
    sellPrice: number
    buyPrice: number
}

interface CartItem {
    product: Product
    quantity: number | ""
    newBuyPrice: number | ""
    newSellPrice: number | ""
}

export default function RestockPage() {
    const [products, setProducts] = useState<Product[]>([])
    const [filteredProducts, setFilteredProducts] = useState<Product[]>([])

    // Cart State
    const [cart, setCart] = useState<CartItem[]>([])

    // UI State
    const [searchQuery, setSearchQuery] = useState("")
    const [loading, setLoading] = useState(false)
    const [showCreateModal, setShowCreateModal] = useState(false)

    const [newProductData, setNewProductData] = useState({
        name: "",
        barcode: "",
        buyPrice: "",
        sellPrice: ""
    })

    const searchInputRef = useRef<HTMLInputElement>(null)

    useEffect(() => {
        fetchProducts()
    }, [])

    // Barcode scanner: auto-add to restock cart
    useBarcodeScanner({
        onScan: (barcode) => {
            const product = products.find(p => p.barcode === barcode)
            if (product) {
                addToCart(product)
                toast.success(`📦 ${product.name} добавлен в приход`)
            } else {
                setSearchQuery(barcode)
                toast.info(`Товар не найден, создайте новый`)
            }
        }
    })

    useEffect(() => {
        const query = searchQuery.toLowerCase()
        setFilteredProducts(products.filter(p =>
            p.name.toLowerCase().includes(query) || p.barcode.includes(query)
        ))
    }, [searchQuery, products])

    const fetchProducts = async () => {
        try {
            const res = await fetch("/api/products")
            const data = await res.json()
            setProducts(data)
        } catch (e) {
            console.error(e)
        }
    }

    const addToCart = (product: Product) => {
        setCart(prev => {
            const existing = prev.find(item => item.product.id === product.id)
            if (existing) {
                return prev.map(item =>
                    item.product.id === product.id
                        ? { ...item, quantity: (Number(item.quantity) || 0) + 1 }
                        : item
                )
            }
            return [...prev, {
                product,
                quantity: 1,
                newBuyPrice: product.buyPrice || 0,
                newSellPrice: product.sellPrice || 0
            }]
        })
    }

    const removeFromCart = (productId: string) => {
        setCart(prev => prev.filter(item => item.product.id !== productId))
    }

    const updateCartItem = (productId: string, updates: Partial<CartItem>) => {
        setCart(prev => prev.map(item =>
            item.product.id === productId ? { ...item, ...updates } : item
        ))
    }

    const handleCreateProduct = async (e: React.FormEvent) => {
        e.preventDefault()
        setLoading(true)
        try {
            const res = await fetch("/api/products", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                    name: newProductData.name,
                    barcode: newProductData.barcode,
                    stock: 0,
                    buyPrice: Number(newProductData.buyPrice),
                    sellPrice: Number(newProductData.sellPrice)
                })
            })

            if (res.ok) {
                const createdProduct = await res.json()
                await fetchProducts()
                addToCart(createdProduct)
                setShowCreateModal(false)
                setNewProductData({ name: "", barcode: "", buyPrice: "", sellPrice: "" })
                setSearchQuery("")
                toast.success("Товар создан! 🎉")
            } else {
                toast.error("Ошибка при создании товара")
            }
        } catch (e) {
            toast.error("Ошибка сети")
        } finally {
            setLoading(false)
        }
    }

    const handleSubmitRestock = async () => {
        if (cart.length === 0) return
        if (!confirm(`Подтвердить приход ${cart.reduce((a, c) => a + (Number(c.quantity) || 0), 0)} товаров?`)) return

        setLoading(true)
        try {
            const payload = cart.map(item => ({
                productId: item.product.id,
                quantity: Number(item.quantity) || 0,
                buyPrice: Number(item.newBuyPrice) || 0,
                sellPrice: Number(item.newSellPrice) || 0
            }))

            const res = await fetch("/api/restock", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify(payload)
            })

            if (res.ok) {
                toast.success("Приход успешно оформлен! 📥")
                setCart([])
                await fetchProducts()
            } else {
                toast.error("Ошибка при оформлении прихода")
            }
        } catch (e) {
            toast.error("Не удалось оформить приход")
        } finally {
            setLoading(false)
        }
    }

    const openCreateModal = () => {
        const isBarcode = /^\d+$/.test(searchQuery) && searchQuery.length > 5
        setNewProductData({
            name: isBarcode ? "" : searchQuery,
            barcode: isBarcode ? searchQuery : "",
            buyPrice: "",
            sellPrice: ""
        })
        setShowCreateModal(true)
    }

    const [showCartDrawer, setShowCartDrawer] = useState(false)

    // ... (logic) ...

    const totalQuantity = cart.reduce((acc, item) => acc + (Number(item.quantity) || 0), 0)
    const totalAmount = cart.reduce((acc, item) => acc + ((Number(item.newBuyPrice) || 0) * (Number(item.quantity) || 0)), 0)

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
                            className="w-full px-4 py-3 md:px-5 md:py-4 !bg-slate-900 !border-slate-700/50 rounded-xl md:rounded-2xl text-base md:text-lg font-medium !text-white placeholder:text-slate-500 focus:outline-none focus:ring-4 focus:ring-emerald-500/20 focus:border-emerald-500 transition-all shadow-sm appearance-none"
                            autoFocus
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

                    {/* New Product Button */}
                    <button
                        onClick={openCreateModal}
                        className="bg-gradient-to-br from-emerald-600 to-teal-600 hover:from-emerald-500 hover:to-teal-500 text-white font-bold rounded-xl md:rounded-2xl px-6 py-3 md:px-8 md:py-4 shadow-lg shadow-emerald-500/20 active:scale-95 transition-all flex items-center justify-center gap-2 group whitespace-nowrap"
                    >
                        <svg className="w-5 h-5 group-hover:rotate-90 transition-transform" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M12 4v16m8-8H4" /></svg>
                        <span className="uppercase tracking-wider text-xs md:text-sm">Новый товар</span>
                    </button>
                </div>

                {/* Grid */}
                <div className="flex-1 pb-24 md:pb-24 px-1 md:px-2 md:overflow-y-auto md:custom-scrollbar">
                    <div className="grid grid-cols-2 md:grid-cols-3 xl:grid-cols-4 gap-3 md:gap-6 p-1 md:p-2">
                        {filteredProducts.map(product => {
                            const inCart = cart.some(item => item.product.id === product.id)
                            return (
                                <div
                                    key={product.id}
                                    onClick={() => addToCart(product)}
                                    role="button"
                                    className={`group relative flex flex-col text-left bg-slate-900 rounded-xl md:rounded-lg border transition-all duration-200 hover:shadow-2xl hover:shadow-emerald-500/10 active:scale-[0.98] cursor-pointer select-none ${inCart
                                        ? 'border-emerald-500 ring-1 ring-emerald-500/30 bg-slate-800/90 shadow-lg shadow-emerald-500/20'
                                        : 'border-slate-800/60 hover:border-slate-600'
                                        }`}
                                    style={{ padding: '16px' }}
                                >
                                    {/* Stock Badge */}
                                    <span className="absolute top-2 right-2 md:top-3 md:right-3 text-[9px] md:text-[10px] items-center justify-center font-bold px-1.5 py-0.5 md:px-2 md:py-1 rounded border border-slate-700 bg-slate-800 text-slate-400 z-10 flex">
                                        Ост: {product.stock}
                                    </span>

                                    {/* Barcode */}
                                    <div className="mb-2 md:mb-4 pr-12">
                                        <span className="text-[9px] md:text-[10px] font-bold tracking-wider text-slate-400 font-mono bg-slate-950/50 px-1.5 py-0.5 md:px-2 md:py-1 rounded border border-slate-800">
                                            {product.barcode}
                                        </span>
                                    </div>

                                    {/* Name */}
                                    <div className="flex-1 mb-2 md:mb-4">
                                        <h3 className="text-xs md:text-base font-semibold text-slate-200 leading-snug group-hover:text-white transition-colors line-clamp-2">
                                            {product.name}
                                        </h3>
                                    </div>

                                    {/* Prices */}
                                    <div className="pt-2 md:pt-3 w-full flex items-end justify-between border-t border-slate-800/50 mt-auto relative z-0">
                                        <div className="flex flex-col">
                                            <span className="text-[8px] md:text-[9px] uppercase text-slate-500 font-bold">Закуп</span>
                                            <span className="text-xs md:text-sm font-bold text-emerald-400">{product.buyPrice}</span>
                                        </div>
                                        <div className="flex flex-col text-right pr-4 md:pr-6">
                                            <span className="text-[8px] md:text-[9px] uppercase text-slate-500 font-bold">Продажа</span>
                                            <span className="text-xs md:text-sm font-bold text-indigo-400">{product.sellPrice}</span>
                                        </div>
                                    </div>

                                    {/* Checkmark */}
                                    {inCart && (
                                        <div className="absolute bottom-3 right-3 w-5 h-5 md:w-6 md:h-6 rounded-full bg-emerald-500 border border-emerald-400 text-white flex items-center justify-center shadow-lg shadow-emerald-500/50 animate-in zoom-in duration-200 z-20">
                                            <svg className="w-3 h-3 md:w-3.5 md:h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" strokeWidth={3}>
                                                <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                                            </svg>
                                        </div>
                                    )}
                                </div>
                            )
                        })}
                    </div>
                </div>
            </div>

            {/* === MOBILE: Sticky Bottom Bar === */}
            <div className="md:hidden fixed bottom-16 md:bottom-0 left-0 right-0 p-4 bg-slate-900 border-t border-slate-800 z-[60] flex items-center gap-4 shadow-[0_-10px_40px_rgba(0,0,0,0.5)]">
                <div className="flex items-center gap-3" onClick={() => setShowCartDrawer(true)}>
                    <div className="relative">
                        <span className={`flex items-center justify-center min-w-[3rem] h-10 px-3 rounded-xl font-bold border ${totalQuantity > 0 ? 'bg-emerald-600 text-white border-emerald-500' : 'bg-slate-800 text-slate-500 border-slate-700'}`}>
                            {totalQuantity}
                        </span>
                    </div>
                    <div>
                        <p className="text-[10px] uppercase text-slate-500 font-bold">Закупка</p>
                        <p className="text-lg font-black text-white leading-none">{totalAmount.toLocaleString()} c</p>
                    </div>
                </div>
                <button
                    onClick={() => setShowCartDrawer(true)}
                    className="flex-1 bg-white text-slate-950 font-bold py-3 rounded-xl uppercase tracking-wider text-sm active:scale-95 transition-transform"
                >
                    Смотреть
                </button>
            </div>

            {/* === MOBILE CART DRAWER === */}
            {showCartDrawer && (
                <div className="md:hidden fixed inset-0 z-[70] bg-slate-950/90 backdrop-blur-sm flex flex-col animate-in fade-in duration-200">
                    <div className="flex-1 flex flex-col bg-slate-900 mt-12 rounded-t-3xl overflow-hidden shadow-2xl border-t border-slate-800 animate-in slide-in-from-bottom duration-300">
                        {/* Header */}
                        <div className="p-6 border-b border-slate-800 flex justify-between items-center bg-slate-900">
                            <h2 className="text-xl font-black text-white uppercase">Приход</h2>
                            <button onClick={() => setShowCartDrawer(false)} className="p-2 bg-slate-800 rounded-full text-slate-400">
                                <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" /></svg>
                            </button>
                        </div>

                        {/* Content */}
                        <div className="flex-1 overflow-y-auto p-4 custom-scrollbar bg-slate-900">
                            {cart.length === 0 ? (
                                <div className="flex flex-col items-center justify-center py-12 text-slate-600 opacity-50 space-y-4">
                                    <p className="text-sm font-bold uppercase tracking-widest">Пусто</p>
                                </div>
                            ) : (
                                cart.map((item) => (
                                    <div key={item.product.id} className="bg-slate-950/50 rounded-xl p-4 border border-slate-800 mb-4">
                                        <div className="flex justify-between items-start mb-3">
                                            <div>
                                                <h4 className="text-sm font-bold text-white line-clamp-1">{item.product.name}</h4>
                                                <span className="text-[10px] font-mono text-slate-500">{item.product.barcode}</span>
                                            </div>
                                            <button onClick={() => removeFromCart(item.product.id)} className="text-red-500 p-1"><svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" /></svg></button>
                                        </div>

                                        <div className="grid grid-cols-2 gap-3 mb-3">
                                            <div>
                                                <label className="text-[9px] uppercase font-bold text-slate-500">Закупка</label>
                                                <input type="number" value={item.newBuyPrice} onChange={e => updateCartItem(item.product.id, { newBuyPrice: parseFloat(e.target.value) })} className="w-full bg-slate-900 border border-slate-700 rounded px-2 py-1 text-xs text-white" />
                                            </div>
                                            <div>
                                                <label className="text-[9px] uppercase font-bold text-slate-500">Продажа</label>
                                                <input type="number" value={item.newSellPrice} onChange={e => updateCartItem(item.product.id, { newSellPrice: parseFloat(e.target.value) })} className="w-full bg-slate-900 border border-slate-700 rounded px-2 py-1 text-xs text-white" />
                                            </div>
                                        </div>

                                        <div className="flex items-center justify-between border-t border-slate-800 pt-3">
                                            <div className="flex items-center gap-2">
                                                <button onClick={() => updateCartItem(item.product.id, { quantity: Math.max(1, (Number(item.quantity) || 0) - 1) })} className="w-8 h-8 bg-slate-800 rounded text-white">-</button>
                                                <span className="font-bold text-white w-8 text-center">{item.quantity}</span>
                                                <button onClick={() => updateCartItem(item.product.id, { quantity: (Number(item.quantity) || 0) + 1 })} className="w-8 h-8 bg-slate-800 rounded text-white">+</button>
                                            </div>
                                            <span className="font-bold text-emerald-400">{((Number(item.newBuyPrice) || 0) * (Number(item.quantity) || 0)).toLocaleString()} с</span>
                                        </div>
                                    </div>
                                ))
                            )}
                        </div>

                        {/* Footer */}
                        <div className="p-6 bg-slate-900 border-t border-slate-800">
                            <div className="flex justify-between items-center mb-6">
                                <span className="text-slate-400 font-bold uppercase text-xs">Итого закупка:</span>
                                <span className="text-3xl font-black text-white tracking-tight">{totalAmount.toLocaleString()} <span className="text-sm text-slate-500 font-bold">сом</span></span>
                            </div>
                            <button
                                onClick={() => { handleSubmitRestock(); setShowCartDrawer(false); }}
                                disabled={cart.length === 0 || loading}
                                className="w-full py-5 bg-emerald-600 text-white font-black uppercase tracking-[0.2em] rounded-2xl shadow-lg disabled:opacity-50"
                            >
                                {loading ? "..." : "Оформить"}
                            </button>
                        </div>
                    </div>
                </div>
            )}

            {/* === RIGHT: Incoming Cart (Fixed Height Behavior) - HIDDEN ON MOBILE === */}
            <div className="hidden md:flex w-[480px] shrink-0 h-full pointer-events-none flex-col justify-start pb-6">
                {/* Use max-h-full so it shrinks if empty */}
                <div className="pointer-events-auto flex flex-col bg-slate-900 border border-slate-800 rounded-3xl shadow-[0_20px_50px_-12px_rgba(0,0,0,0.5)] overflow-hidden max-h-full">

                    {/* Header */}
                    <div className="px-8 py-6 border-b border-slate-800 bg-slate-900/50 backdrop-blur sticky top-0 z-20 flex justify-between items-center shrink-0">
                        <div>
                            <h2 className="text-xl font-black text-white uppercase tracking-wide">Поступление</h2>
                            <p className="text-xs text-slate-500 mt-1">Корзина прихода</p>
                        </div>
                        <span className="bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 px-3 py-1 rounded-full text-xs font-bold font-mono">
                            {totalQuantity} шт
                        </span>
                    </div>

                    {/* Cart Items - Removed flex-1 so it does not force expand */}
                    <div className="overflow-y-auto p-6 space-y-4 custom-scrollbar min-h-0">
                        {cart.length === 0 ? (
                            <div className="flex flex-col items-center justify-center py-12 text-slate-600 opacity-50 space-y-4">
                                <p className="text-sm font-bold uppercase tracking-widest">Список пуст</p>
                            </div>
                        ) : (
                            cart.map((item, idx) => (
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

                                    {/* Controls: Buy, Sell, Qty */}
                                    <div className="grid grid-cols-[1fr_1fr_1.5fr] gap-3 mb-2">
                                        {/* Buy Price (First) */}
                                        <div className="space-y-1">
                                            <label className="text-[9px] uppercase font-bold text-slate-500">Закупка</label>
                                            <input
                                                type="number"
                                                value={item.newBuyPrice}
                                                onChange={e => updateCartItem(item.product.id, { newBuyPrice: e.target.value === "" ? "" : parseFloat(e.target.value) })}
                                                className="w-full bg-slate-900 border border-slate-700 rounded-lg px-2 py-1.5 text-xs font-bold text-emerald-400 focus:border-emerald-500 outline-none text-center"
                                            />
                                        </div>
                                        {/* Sell Price (Second) */}
                                        <div className="space-y-1">
                                            <label className="text-[9px] uppercase font-bold text-slate-500">Продажа</label>
                                            <input
                                                type="number"
                                                value={item.newSellPrice}
                                                onChange={e => updateCartItem(item.product.id, { newSellPrice: e.target.value === "" ? "" : parseFloat(e.target.value) })}
                                                className="w-full bg-slate-900 border border-slate-700 rounded-lg px-2 py-1.5 text-xs font-bold text-indigo-400 focus:border-indigo-500 outline-none text-center"
                                            />
                                        </div>
                                        {/* Qty */}
                                        <div className="space-y-1">
                                            <label className="text-[9px] uppercase font-bold text-slate-500">Кол-во</label>
                                            <div className="flex items-center">
                                                <button onClick={() => updateCartItem(item.product.id, { quantity: Math.max(1, (Number(item.quantity) || 0) - 1) })} className="w-8 h-8 bg-slate-800 rounded-l-lg text-slate-400 hover:text-white hover:bg-slate-700">-</button>
                                                <input
                                                    type="number"
                                                    value={item.quantity}
                                                    onChange={e => updateCartItem(item.product.id, { quantity: e.target.value === "" ? "" : parseInt(e.target.value) })}
                                                    className="w-full h-8 bg-slate-900 border-y border-slate-700 text-center text-sm font-black text-white outline-none"
                                                />
                                                <button onClick={() => updateCartItem(item.product.id, { quantity: (Number(item.quantity) || 0) + 1 })} className="w-8 h-8 bg-slate-800 rounded-r-lg text-slate-400 hover:text-white hover:bg-slate-700">+</button>
                                            </div>
                                        </div>
                                    </div>
                                    <div className="text-right">
                                        <span className="text-[10px] text-slate-500">Сумма закупки: </span>
                                        <span className="text-xs font-bold text-emerald-500">{((Number(item.newBuyPrice) || 0) * (Number(item.quantity) || 0)).toLocaleString()} сом</span>
                                    </div>
                                </div>
                            ))
                        )}
                    </div>

                    {/* Footer - Fixed Bottom */}
                    <div className="p-6 bg-slate-900 border-t border-slate-800 shrink-0">
                        <div className="flex justify-between items-center mb-6">
                            <span className="text-slate-400 font-bold uppercase text-xs">Итого закупка:</span>
                            <span className="text-2xl font-black text-white">{totalAmount.toLocaleString()} <span className="text-sm text-slate-500 font-bold">сом</span></span>
                        </div>
                        <button
                            onClick={handleSubmitRestock}
                            disabled={cart.length === 0 || loading}
                            className="w-full py-5 bg-emerald-600 hover:bg-emerald-500 text-white font-black uppercase tracking-[0.2em] rounded-2xl shadow-lg shadow-emerald-500/20 disabled:opacity-50 disabled:cursor-not-allowed transition-all active:scale-[0.98] hover:-translate-y-1"
                        >
                            {loading ? "Обработка..." : "Оформить приход"}
                        </button>
                    </div>
                </div>
            </div>

            {/* === Modal: Create Product (Refined - No Icons, Less Rounded) === */}
            {showCreateModal && (
                <div className="fixed inset-0 z-[100] flex items-center justify-center p-4 bg-black/60 backdrop-blur-md animate-in fade-in duration-200">
                    <div className="bg-slate-900 w-full max-w-lg rounded-xl border border-slate-700 shadow-2xl p-0 overflow-hidden animate-in zoom-in-95 duration-200">
                        {/* Header */}
                        <div className="bg-slate-900 border-b border-slate-800 p-6 flex justify-between items-center">
                            <h2 className="text-xl font-bold text-white uppercase tracking-wide">
                                Новый товар
                            </h2>
                            <button onClick={() => setShowCreateModal(false)} className="text-slate-500 hover:text-white transition-colors">
                                <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" /></svg>
                            </button>
                        </div>

                        {/* Body */}
                        <form onSubmit={handleCreateProduct} className="p-8 space-y-6 bg-slate-950/30">
                            <div className="space-y-4">
                                <div className="space-y-1.5">
                                    <label className="text-[11px] font-bold text-slate-400 uppercase tracking-widest pl-1">Название товара</label>
                                    <input
                                        type="text"
                                        value={newProductData.name}
                                        onChange={e => setNewProductData({ ...newProductData, name: e.target.value })}
                                        className="w-full px-4 py-4 bg-slate-950 border border-slate-800 rounded-lg text-white outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500/20 transition-all font-semibold text-lg placeholder:text-slate-700"
                                        placeholder="Введите название"
                                        required
                                        autoFocus
                                    />
                                </div>

                                <div className="space-y-1.5">
                                    <label className="text-[11px] font-bold text-slate-400 uppercase tracking-widest pl-1">Штрих-код</label>
                                    <div className="flex gap-2">
                                        <input
                                            type="text"
                                            value={newProductData.barcode}
                                            onChange={e => setNewProductData({ ...newProductData, barcode: e.target.value })}
                                            className="flex-1 px-4 py-4 bg-slate-950 border border-slate-800 rounded-lg text-white font-mono outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500/20 transition-all font-medium placeholder:text-slate-700"
                                            placeholder="Введите или сгенерируйте"
                                            required
                                        />
                                        <button
                                            type="button"
                                            onClick={() => setNewProductData({ ...newProductData, barcode: generateEAN13() })}
                                            className="px-4 py-4 bg-emerald-600/20 hover:bg-emerald-600 text-emerald-400 hover:text-white border border-emerald-500/30 rounded-lg text-xs font-black uppercase tracking-wider transition-all whitespace-nowrap"
                                        >
                                            Генерация
                                        </button>
                                    </div>
                                </div>

                                <div className="grid grid-cols-2 gap-6">
                                    <div className="space-y-1.5">
                                        <label className="text-[11px] font-bold text-slate-400 uppercase tracking-widest pl-1">Цена Закупки</label>
                                        <div className="relative">
                                            <input
                                                type="number"
                                                value={newProductData.buyPrice}
                                                onChange={e => setNewProductData({ ...newProductData, buyPrice: e.target.value })}
                                                className="w-full pl-4 pr-12 py-4 bg-slate-950 border border-slate-800 rounded-lg text-emerald-400 font-bold text-xl outline-none focus:border-emerald-500 transition-all placeholder:text-slate-800"
                                                placeholder="0"
                                                required
                                            />
                                            <span className="absolute right-4 top-1/2 -translate-y-1/2 text-slate-600 font-bold text-xs uppercase">сом</span>
                                        </div>
                                    </div>
                                    <div className="space-y-1.5">
                                        <label className="text-[11px] font-bold text-slate-400 uppercase tracking-widest pl-1">Цена Продажи</label>
                                        <div className="relative">
                                            <input
                                                type="number"
                                                value={newProductData.sellPrice}
                                                onChange={e => setNewProductData({ ...newProductData, sellPrice: e.target.value })}
                                                className="w-full pl-4 pr-12 py-4 bg-slate-950 border border-slate-800 rounded-lg text-indigo-400 font-bold text-xl outline-none focus:border-indigo-500 transition-all placeholder:text-slate-800"
                                                placeholder="0"
                                                required
                                            />
                                            <span className="absolute right-4 top-1/2 -translate-y-1/2 text-slate-600 font-bold text-xs uppercase">сом</span>
                                        </div>
                                    </div>
                                </div>
                            </div>

                            <div className="pt-6 flex gap-4">
                                <button type="button" onClick={() => setShowCreateModal(false)} className="flex-1 py-4 bg-slate-800 hover:bg-slate-700 text-slate-300 font-bold rounded-lg transition-colors uppercase text-sm tracking-wider">Отмена</button>
                                <button type="submit" disabled={loading} className="flex-[2] py-4 bg-emerald-600 hover:bg-emerald-500 text-white font-bold rounded-lg transition-all uppercase text-sm tracking-wider shadow-lg shadow-emerald-500/25 disabled:opacity-50 hover:-translate-y-0.5 active:translate-y-0">
                                    {loading ? "Создаем..." : "Создать товар"}
                                </button>
                            </div>
                        </form>
                    </div>
                </div>
            )}
        </div>
    )
}
