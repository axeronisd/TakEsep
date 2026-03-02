import useSWR from "swr"

const fetcher = (url: string) => fetch(url).then(res => res.json())

// Products hook with instant cache
export function useProducts() {
    const { data, error, isLoading, mutate } = useSWR<any[]>("/api/products", fetcher, {
        revalidateOnFocus: false,
        revalidateOnReconnect: false,
        dedupingInterval: 30000, // 30 seconds cache
        keepPreviousData: true,
    })

    return {
        products: data || [],
        isLoading,
        isError: error,
        refresh: mutate
    }
}

// Analytics hook
export function useAnalytics(period: string, startDate?: Date | null, endDate?: Date | null) {
    let url = `/api/analytics?period=${period}`
    if (period === 'custom' && startDate && endDate) {
        url += `&startDate=${startDate.toISOString()}&endDate=${endDate.toISOString()}`
    }

    const { data, error, isLoading } = useSWR(url, fetcher, {
        revalidateOnFocus: false,
        dedupingInterval: 60000, // 1 minute cache
        keepPreviousData: true,
    })

    return {
        data,
        isLoading,
        isError: error
    }
}

// Audits hook
export function useAudits(current?: boolean) {
    const url = current ? "/api/audit?current=true" : "/api/audit"
    const { data, error, isLoading, mutate } = useSWR(url, fetcher, {
        revalidateOnFocus: false,
        dedupingInterval: 10000,
        keepPreviousData: true,
    })

    return {
        data,
        isLoading,
        isError: error,
        refresh: mutate
    }
}

// Transactions hook
export function useTransactions() {
    const { data, error, isLoading, mutate } = useSWR("/api/transactions", fetcher, {
        revalidateOnFocus: false,
        dedupingInterval: 30000,
        keepPreviousData: true,
    })

    return {
        transactions: data || [],
        isLoading,
        isError: error,
        refresh: mutate
    }
}

// Warehouses hook
export function useWarehouses() {
    const { data, error, isLoading } = useSWR("/api/warehouses", fetcher, {
        revalidateOnFocus: false,
        dedupingInterval: 300000, // 5 minutes cache
        keepPreviousData: true,
    })

    return {
        warehouses: Array.isArray(data) ? data : [],
        isLoading,
        isError: error
    }
}
