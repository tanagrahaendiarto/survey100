import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Top Survey · Welcoming Party G-SPARK",
  description: "Permainan survei interaktif untuk Welcoming Party G-SPARK.",
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="id">
      <body>{children}</body>
    </html>
  );
}
