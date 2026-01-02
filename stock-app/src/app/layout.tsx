import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
    title: "Taiwan Stock App",
    description: "Real-time Taiwan stock prices",
};

export default function RootLayout({
    children,
}: Readonly<{
    children: React.ReactNode;
}>) {
    return (
        <html lang="en">
            <body>
                {children}
            </body>
        </html>
    );
}
