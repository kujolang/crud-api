import type { Metadata } from "next";
import Link from "next/link";
import { Manrope } from "next/font/google";
import { api_base_url } from "@/lib/runtime-config";
import "./globals.css";

const body_font = Manrope({
	subsets: ["latin"],
	weight: ["400", "500", "600", "700"],
	variable: "--font-body"
});

const heading_font = Manrope({
	subsets: ["latin"],
	weight: ["600", "700"],
	variable: "--font-heading"
});

export const metadata: Metadata = {
	title: "Kujo CRUD API Showcase",
	description: "A stripped-back CRUD playground for Kujo APIs"
};

export default function RootLayout({
	children
}: Readonly<{
	children: React.ReactNode;
}>) {
	return (
		<html lang="en">
			<body className={heading_font.variable + " " + body_font.variable}>
				<div className="app-shell">
					<header className="topbar">
						<div>
							<p className="kicker">Kujo Example</p>
							<h1>CRUD API Playground</h1>
						</div>
						<nav className="topbar-nav">
							<Link href="/">Playground</Link>
							<a href={api_base_url} target="_blank" rel="noreferrer">
								API Root
							</a>
						</nav>
					</header>
					<main>{children}</main>
				</div>
			</body>
		</html>
	);
}
