import Link from "next/link";

export default function AdminPage() {
	return (
		<section className="card single-card">
			<h2>Single Surface Demo</h2>
			<p>
				The showcase now uses one page for all CRUD operations so developers can quickly
				understand and extend the API workflow.
			</p>
			<Link href="/" className="link-button">
				Go to CRUD playground
			</Link>
		</section>
	);
}
