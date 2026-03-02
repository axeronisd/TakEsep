import { redirect } from 'next/navigation'

export default function RootPage() {
    // This page is protected by middleware.
    // If we reach here, we are authenticated, so redirect to the main dashboard (Sales).
    redirect('/sales')
}
