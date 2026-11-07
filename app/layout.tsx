import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Top Survey UNPAD × IPB",
  description: "Permainan survei interaktif untuk Studi Banding UNPAD × IPB.",
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
