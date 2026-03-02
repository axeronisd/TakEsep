"use client"

import { useEffect, useRef, useCallback } from "react"

interface UseBarcodeOptions {
    onScan: (barcode: string) => void
    minLength?: number      // Minimum barcode length (default: 4)
    maxDelay?: number       // Max ms between keystrokes for scanner input (default: 50)
    enabled?: boolean       // Enable/disable the hook (default: true)
}

/**
 * Hook to detect barcode scanner input.
 * Barcode scanners emulate keyboard input — they type characters very fast
 * and press Enter at the end. This hook distinguishes scanner input from
 * regular typing by measuring the time between keystrokes.
 */
export function useBarcodeScanner({
    onScan,
    minLength = 4,
    maxDelay = 100,
    enabled = true,
}: UseBarcodeOptions) {
    const bufferRef = useRef("")
    const lastKeyTimeRef = useRef(0)
    const onScanRef = useRef(onScan)

    // Keep callback ref updated
    onScanRef.current = onScan

    const resetBuffer = useCallback(() => {
        bufferRef.current = ""
    }, [])

    useEffect(() => {
        if (!enabled) return

        const handleKeyDown = (e: KeyboardEvent) => {
            const now = Date.now()
            const timeSinceLastKey = now - lastKeyTimeRef.current
            lastKeyTimeRef.current = now

            // If too much time passed, reset buffer (user is typing manually)
            if (timeSinceLastKey > maxDelay && bufferRef.current.length > 0) {
                resetBuffer()
            }

            if (e.key === "Enter") {
                const barcode = bufferRef.current.trim()
                if (barcode.length >= minLength) {
                    // Only prevent default if we have a valid scanned barcode
                    // (fast sequential input that looks like scanner data)
                    e.preventDefault()
                    e.stopPropagation()
                    onScanRef.current(barcode)
                }
                resetBuffer()
                return
            }

            // Only collect printable characters (digits, letters)
            if (e.key.length === 1 && !e.ctrlKey && !e.altKey && !e.metaKey) {
                // Check if an input/textarea is focused — if so, let them handle it
                const active = document.activeElement
                const isInputFocused = active instanceof HTMLInputElement ||
                    active instanceof HTMLTextAreaElement ||
                    active instanceof HTMLSelectElement

                if (isInputFocused) {
                    // Still collect for scanner detection but don't prevent
                    bufferRef.current += e.key
                } else {
                    bufferRef.current += e.key
                }
            }
        }

        document.addEventListener("keydown", handleKeyDown, true)

        return () => {
            document.removeEventListener("keydown", handleKeyDown, true)
        }
    }, [enabled, maxDelay, minLength, resetBuffer])

    return { resetBuffer }
}

/**
 * Generate a valid EAN-13 barcode.
 */
export function generateEAN13(): string {
    // Generate 12 random digits
    const digits: number[] = []
    for (let i = 0; i < 12; i++) {
        digits.push(Math.floor(Math.random() * 10))
    }

    // Calculate check digit
    let sum = 0
    for (let i = 0; i < 12; i++) {
        sum += digits[i] * (i % 2 === 0 ? 1 : 3)
    }
    const checkDigit = (10 - (sum % 10)) % 10
    digits.push(checkDigit)

    return digits.join("")
}
