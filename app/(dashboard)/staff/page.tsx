"use client"

import { useState, useEffect } from "react"
import { toast } from "sonner"

type Employee = {
    id: string
    name: string
    role: string
    phone: string | null
    salary: number
}

// Modal Components
const AddEmployeeModal = ({ isOpen, onClose, onAdd }: { isOpen: boolean, onClose: () => void, onAdd: () => void }) => {
    const [loading, setLoading] = useState(false)
    const [name, setName] = useState("")
    const [role, setRole] = useState("staff")
    const [phone, setPhone] = useState("")
    const [salary, setSalary] = useState("")

    if (!isOpen) return null

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault()
        setLoading(true)
        try {
            const res = await fetch("/api/employees", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ name, role, phone, salary: parseFloat(salary) || 0 })
            })
            if (!res.ok) throw new Error("Ошибка при создании")
            toast.success("Сотрудник добавлен")
            onAdd()
            onClose()
            setName(""); setPhone(""); setSalary("")
        } catch (e) {
            toast.error("Не удалось добавить сотрудника")
        } finally {
            setLoading(false)
        }
    }

    return (
        <div className="fixed inset-0 bg-black/70 backdrop-blur-sm z-50 flex items-center justify-center p-4" onClick={onClose}>
            <div className="bg-slate-900 border border-slate-700 rounded-2xl p-6 w-full max-w-sm" onClick={e => e.stopPropagation()}>
                <h3 className="text-lg font-black text-white uppercase tracking-wide mb-4">Новый сотрудник</h3>
                <form onSubmit={handleSubmit} className="space-y-3">
                    <input autoFocus placeholder="Имя Фамилия" value={name} onChange={e => setName(e.target.value)} required className="w-full bg-slate-800 border-slate-700 rounded-xl px-4 py-3" />
                    <select value={role} onChange={e => setRole(e.target.value)} className="w-full bg-slate-800 border-slate-700 rounded-xl px-4 py-3">
                        <option value="staff">Сотрудник</option>
                        <option value="manager">Менеджер</option>
                        <option value="driver">Водитель</option>
                    </select>
                    <input placeholder="Телефон" value={phone} onChange={e => setPhone(e.target.value)} className="w-full bg-slate-800 border-slate-700 rounded-xl px-4 py-3" />
                    <input type="number" placeholder="Оклад (сом)" value={salary} onChange={e => setSalary(e.target.value)} className="w-full bg-slate-800 border-slate-700 rounded-xl px-4 py-3" />
                    <button disabled={loading} className="w-full bg-emerald-600 hover:bg-emerald-500 text-white font-bold py-3 rounded-xl uppercase tracking-widest transition-colors mt-2">
                        {loading ? "..." : "Добавить"}
                    </button>
                </form>
            </div>
        </div>
    )
}

const EditEmployeeModal = ({ employee, isOpen, onClose, onUpdate }: { employee: Employee | null, isOpen: boolean, onClose: () => void, onUpdate: () => void }) => {
    const [loading, setLoading] = useState(false)
    const [deleting, setDeleting] = useState(false)
    const [name, setName] = useState("")
    const [role, setRole] = useState("staff")
    const [phone, setPhone] = useState("")
    const [salary, setSalary] = useState("")

    useEffect(() => {
        if (employee) {
            setName(employee.name)
            setRole(employee.role)
            setPhone(employee.phone || "")
            setSalary(employee.salary.toString())
        }
    }, [employee])

    if (!isOpen || !employee) return null

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault()
        setLoading(true)
        try {
            const res = await fetch(`/api/employees/${employee.id}`, {
                method: "PUT",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ name, role, phone, salary: parseFloat(salary) || 0 })
            })
            if (!res.ok) throw new Error("Ошибка при обновлении")
            toast.success("Сотрудник обновлен")
            onUpdate()
            onClose()
        } catch (e) {
            toast.error("Не удалось обновить сотрудника")
        } finally {
            setLoading(false)
        }
    }

    const handleDelete = async () => {
        if (!confirm("Вы уверены, что хотите удалить этого сотрудника?")) return
        setDeleting(true)
        try {
            const res = await fetch(`/api/employees/${employee.id}`, { method: "DELETE" })
            if (!res.ok) throw new Error("Ошибка при удалении")
            toast.success("Сотрудник удален")
            onUpdate()
            onClose()
        } catch (e) {
            toast.error("Не удалось удалить сотрудника")
        } finally {
            setDeleting(false)
        }
    }

    return (
        <div className="fixed inset-0 bg-black/70 backdrop-blur-sm z-50 flex items-center justify-center p-4" onClick={onClose}>
            <div className="bg-slate-900 border border-slate-700 rounded-2xl p-6 w-full max-w-sm" onClick={e => e.stopPropagation()}>
                <div className="flex justify-between items-center mb-4">
                    <h3 className="text-lg font-black text-white uppercase tracking-wide">РЕДАКТИРОВАТЬ</h3>
                    <button onClick={handleDelete} disabled={deleting} className="p-2 text-red-500 hover:bg-red-500/20 rounded-lg transition-colors" title="Удалить сотрудника">
                        <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" /></svg>
                    </button>
                </div>
                <form onSubmit={handleSubmit} className="space-y-3">
                    <input autoFocus placeholder="Имя Фамилия" value={name} onChange={e => setName(e.target.value)} required className="w-full bg-slate-800 border-slate-700 rounded-xl px-4 py-3 text-white" />
                    <select value={role} onChange={e => setRole(e.target.value)} className="w-full bg-slate-800 border-slate-700 rounded-xl px-4 py-3 text-white">
                        <option value="staff">Сотрудник</option>
                        <option value="manager">Менеджер</option>
                        <option value="driver">Водитель</option>
                    </select>
                    <input placeholder="Телефон" value={phone} onChange={e => setPhone(e.target.value)} className="w-full bg-slate-800 border-slate-700 rounded-xl px-4 py-3 text-white" />
                    <input type="number" placeholder="Оклад (сом)" value={salary} onChange={e => setSalary(e.target.value)} className="w-full bg-slate-800 border-slate-700 rounded-xl px-4 py-3 text-white" />
                    <button disabled={loading || deleting} className="w-full bg-indigo-600 hover:bg-indigo-500 text-white font-bold py-3 rounded-xl uppercase tracking-widest transition-colors mt-2">
                        {loading ? "..." : "Сохранить"}
                    </button>
                </form>
            </div>
        </div>
    )
}

const PaySalaryModal = ({ employee, isOpen, onClose }: { employee: Employee | null, isOpen: boolean, onClose: () => void }) => {
    const [loading, setLoading] = useState(false)
    const [amount, setAmount] = useState("")
    const [note, setNote] = useState("Зарплата")

    useEffect(() => {
        if (employee) setAmount(employee.salary.toString())
    }, [employee])

    if (!isOpen || !employee) return null

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault()
        setLoading(true)
        try {
            const res = await fetch("/api/finance", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                    amount: parseFloat(amount),
                    type: "SALARY",
                    description: `${note} - ${employee.name}`,
                    employeeId: employee.id
                })
            })
            if (!res.ok) throw new Error("Ошибка")
            toast.success(`Выплачено ${amount} сом пользователю ${employee.name}`)
            onClose()
        } catch {
            toast.error("Ошибка при выплате")
        } finally {
            setLoading(false)
        }
    }

    return (
        <div className="fixed inset-0 bg-black/70 backdrop-blur-sm z-50 flex items-center justify-center p-4" onClick={onClose}>
            <div className="bg-slate-900 border border-slate-700 rounded-2xl p-6 w-full max-w-sm" onClick={e => e.stopPropagation()}>
                <h3 className="text-lg font-black text-white uppercase tracking-wide mb-1">Выплата зарплаты</h3>
                <p className="text-slate-500 text-sm mb-4">{employee.name}</p>
                <form onSubmit={handleSubmit} className="space-y-3">
                    <div className="space-y-1">
                        <label className="text-[10px] font-bold text-slate-500 uppercase tracking-widest">Сумма</label>
                        <input type="number" value={amount} onChange={e => setAmount(e.target.value)} className="w-full bg-slate-800 border-slate-700 rounded-xl px-4 py-3 text-xl font-bold text-white" />
                    </div>
                    <div className="space-y-1">
                        <label className="text-[10px] font-bold text-slate-500 uppercase tracking-widest">Примечание</label>
                        <input value={note} onChange={e => setNote(e.target.value)} className="w-full bg-slate-800 border-slate-700 rounded-xl px-4 py-3" />
                    </div>
                    <button disabled={loading} className="w-full bg-indigo-600 hover:bg-indigo-500 text-white font-bold py-3 rounded-xl uppercase tracking-widest transition-colors mt-2">
                        {loading ? "..." : "Выплатить"}
                    </button>
                </form>
            </div>
        </div>
    )
}

export default function StaffPage() {
    const [employees, setEmployees] = useState<Employee[]>([])
    const [loading, setLoading] = useState(true)
    const [isAddOpen, setIsAddOpen] = useState(false)
    const [payEmployee, setPayEmployee] = useState<Employee | null>(null)
    const [editEmployee, setEditEmployee] = useState<Employee | null>(null)

    const fetchEmployees = async () => {
        try {
            const res = await fetch("/api/employees")
            const data = await res.json()
            if (Array.isArray(data)) setEmployees(data)
        } catch (e) {
            console.error(e)
        } finally {
            setLoading(false)
        }
    }

    useEffect(() => {
        fetchEmployees()
    }, [])

    return (
        <div className="min-h-[calc(100vh-5rem)] bg-slate-950 p-6 space-y-6">
            <header className="flex items-center justify-between">
                <div>
                    <span className="text-[10px] font-black text-indigo-500 tracking-[0.4em] uppercase opacity-90">Команда</span>
                    <h1 className="text-2xl sm:text-3xl font-black text-white tracking-tight mt-1 uppercase">Сотрудники</h1>
                </div>
                <button
                    onClick={() => setIsAddOpen(true)}
                    className="bg-indigo-600 hover:bg-indigo-500 text-white px-5 py-2.5 rounded-xl font-bold text-xs uppercase tracking-widest transition-all hover:scale-105 active:scale-95 shadow-lg shadow-indigo-500/20"
                >
                    + Добавить
                </button>
            </header>

            {loading ? (
                <div className="text-slate-500 font-bold uppercase tracking-widest text-center py-20">Загрузка...</div>
            ) : employees.length === 0 ? (
                <div className="text-slate-600 font-bold uppercase tracking-widest text-center py-20 border border-dashed border-slate-800 rounded-3xl">Сотрудников нет</div>
            ) : (
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                    {employees.map(emp => (
                        <div key={emp.id} className="bg-slate-900 border border-slate-800 rounded-2xl p-5 hover:border-slate-700 transition-colors group">
                            <div className="flex justify-between items-start mb-4">
                                <div>
                                    <h3 className="font-bold text-lg text-white">{emp.name}</h3>
                                    <p className="text-xs font-bold text-indigo-400 uppercase tracking-widest mt-1">{emp.role}</p>
                                </div>
                                <div className="flex items-center gap-2">
                                    <button
                                        onClick={() => setEditEmployee(emp)}
                                        className="p-2 bg-slate-800 hover:bg-slate-700 rounded-full text-slate-400 hover:text-white transition-colors"
                                        title="Редактировать"
                                    >
                                        <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" /></svg>
                                    </button>
                                    <div className="w-10 h-10 rounded-full bg-slate-800 flex items-center justify-center text-slate-400 font-bold">
                                        {emp.name.charAt(0)}
                                    </div>
                                </div>
                            </div>

                            <div className="space-y-2 mb-6">
                                <div className="flex justify-between text-sm">
                                    <span className="text-slate-500">Телефон</span>
                                    <span className="text-slate-300 font-mono">{emp.phone || "-"}</span>
                                </div>
                                <div className="flex justify-between text-sm">
                                    <span className="text-slate-500">Оклад</span>
                                    <span className="text-emerald-400 font-mono font-bold">{emp.salary.toLocaleString()}</span>
                                </div>
                            </div>

                            <button
                                onClick={() => setPayEmployee(emp)}
                                className="w-full py-2 bg-slate-800 hover:bg-emerald-600 hover:text-white text-slate-400 font-bold text-xs uppercase tracking-widest rounded-lg transition-all"
                            >
                                Выплатить
                            </button>
                        </div>
                    ))}
                </div>
            )}

            <AddEmployeeModal isOpen={isAddOpen} onClose={() => setIsAddOpen(false)} onAdd={fetchEmployees} />
            <PaySalaryModal employee={payEmployee} isOpen={!!payEmployee} onClose={() => setPayEmployee(null)} />
            <EditEmployeeModal employee={editEmployee} isOpen={!!editEmployee} onClose={() => setEditEmployee(null)} onUpdate={fetchEmployees} />
        </div>
    )
}
