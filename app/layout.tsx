import type { Metadata } from "next";
import "./globals.css";

// Force Rebuild Trigger: 2
export const metadata: Metadata = {
  title: "ТакЭсеп",
  description: "Современная платформа для учёта товаров и аудита склада",
};

import { Toaster } from "sonner";

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="ru">
      <head>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="anonymous" />
        <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet" />
      </head>
      <body>
        <Toaster position="bottom-right" theme="dark" richColors />
        {children}
      </body>
    </html>
  );
}
