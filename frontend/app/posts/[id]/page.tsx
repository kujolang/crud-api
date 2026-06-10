import Link from "next/link";
import { notFound } from "next/navigation";
import { format_timestamp } from "@/lib/format";
import { get_item, list_items, type Item } from "@/lib/api";

export const dynamic = "force-dynamic";

type PostPageProps = {
	params: Promise<{
		id: string;
	}>;
};

export default async function PostPage({ params }: PostPageProps) {
	const resolved_params = await params;
	const parsed_id = Number(resolved_params.id);
	if (!Number.isFinite(parsed_id) || parsed_id < 1) {
		notFound();
	}

	let item: Item | null = null;
	let load_error = "";
	let related_items: Item[] = [];

	try {
		const loaded_item = await get_item(parsed_id);
		item = loaded_item;
		const related_response = await list_items({
			status: "published",
			limit: 6,
			offset: 0,
			project_id: loaded_item.project_id === null ? undefined : loaded_item.project_id
		});
		related_items = related_response.items.filter((related_item) => related_item.id !== parsed_id).slice(0, 4);
	} catch (err) {
		load_error = err instanceof Error ? err.message : "Unable to load this post.";
	}

	if (load_error.length > 0 || !item) {
		return (
			<section className="single-card card">
				<div className="feedback error">{load_error || "Post not found."}</div>
				<Link href="/" className="link-button">
					Back to playground
				</Link>
			</section>
		);
	}

	return (
		<section className="card single-card">
			<Link href="/" className="link-button ghost-link">
				Back to playground
			</Link>

			<article>
				<p className="kicker">Item #{item.id}</p>
				<h1>{item.title}</h1>
				<div className="meta-row">
					<span className={"badge " + item.status}>{item.status}</span>
					<span className="small">Project: {item.project_name || "No project"}</span>
					<span className="small">Updated: {format_timestamp(item.updated_at)}</span>
				</div>
				<div className="detail-content">
					<p>{item.content}</p>
				</div>
			</article>

			{related_items.length > 0 ? (
				<div className="card nested-card">
					<h3>Related Items</h3>
					<div className="related-list">
						{related_items.map((related_item) => (
							<Link key={related_item.id} href={"/posts/" + String(related_item.id)} className="related-item">
								<strong>{related_item.title}</strong>
								<span className="small">{format_timestamp(related_item.updated_at)}</span>
							</Link>
						))}
					</div>
				</div>
			) : null}
		</section>
	);
}
