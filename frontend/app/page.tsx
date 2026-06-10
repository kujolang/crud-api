"use client";

import { FormEvent, useEffect, useMemo, useState } from "react";
import { format_timestamp } from "@/lib/format";
import {
	api_base_url,
	create_item,
	delete_item,
	list_items,
	list_projects,
	patch_item,
	replace_item,
	type Item,
	type ItemPayload,
	type ItemStatus,
	type ListItemsResponse,
	type Project
} from "@/lib/api";

const STATUS_VALUES: Array<ItemStatus> = ["draft", "published", "archived"];

type EditableItem = {
	title: string;
	content: string;
	status: ItemStatus;
	project_id_text: string;
};

function project_id_text_to_value(project_id_text: string): number | null {
	if (project_id_text === "none") {
		return null;
	}

	const parsed = Number(project_id_text);
	if (!Number.isFinite(parsed) || parsed < 1) {
		return null;
	}

	return parsed;
}

function to_editable_item(item: Item): EditableItem {
	return {
		title: item.title,
		content: item.content,
		status: item.status,
		project_id_text: item.project_id === null ? "none" : String(item.project_id)
	};
}

function build_patch_payload(original: Item, draft: EditableItem): Partial<ItemPayload> {
	const payload: Partial<ItemPayload> = {};
	if (draft.title !== original.title) {
		payload.title = draft.title;
	}
	if (draft.content !== original.content) {
		payload.content = draft.content;
	}
	if (draft.status !== original.status) {
		payload.status = draft.status;
	}

	const draft_project_id = project_id_text_to_value(draft.project_id_text);
	if (draft_project_id !== original.project_id) {
		payload.project_id = draft_project_id;
	}
	return payload;
}

export default function HomePage() {
	const [auth_token, set_auth_token] = useState("");
	const [status_filter, set_status_filter] = useState<"all" | ItemStatus>("all");
	const [project_filter_text, set_project_filter_text] = useState("all");
	const [limit_text, set_limit_text] = useState("50");
	const [offset_text, set_offset_text] = useState("0");

	const [projects, set_projects] = useState<Project[]>([]);
	const [items, set_items] = useState<Item[]>([]);
	const [drafts, set_drafts] = useState<Record<number, EditableItem>>({});
	const [list_meta, set_list_meta] = useState<ListItemsResponse | null>(null);
	const [selected_item_id, set_selected_item_id] = useState<number | null>(null);

	const [create_title, set_create_title] = useState("");
	const [create_content, set_create_content] = useState("");
	const [create_status, set_create_status] = useState<ItemStatus>("draft");
	const [create_project_id_text, set_create_project_id_text] = useState("none");

	const [is_loading, set_is_loading] = useState(false);
	const [error_text, set_error_text] = useState("");
	const [success_text, set_success_text] = useState("");

	const normalized_auth_token = useMemo(() => auth_token.trim(), [auth_token]);

	const selected_item = useMemo(() => {
		if (selected_item_id === null) {
			return null;
		}
		return items.find((item) => item.id === selected_item_id) || null;
	}, [items, selected_item_id]);

	const selected_draft = useMemo(() => {
		if (!selected_item) {
			return null;
		}
		return drafts[selected_item.id] || to_editable_item(selected_item);
	}, [drafts, selected_item]);

	useEffect(() => {
		if (typeof window === "undefined") {
			return;
		}
		const saved_token = window.localStorage.getItem("kujo_crud_token") || window.localStorage.getItem("kujo_crud_token") || "";
		set_auth_token(saved_token);
	}, []);

	const load_projects = async () => {
		const response = await list_projects();
		set_projects(response.projects);
	};

	const load_items = async () => {
		set_is_loading(true);
		set_error_text("");
		set_success_text("");

		try {
			const parsed_limit = Number(limit_text);
			const parsed_offset = Number(offset_text);
			if (!Number.isFinite(parsed_limit) || parsed_limit < 1) {
				throw new Error("limit must be a number greater than 0");
			}
			if (!Number.isFinite(parsed_offset) || parsed_offset < 0) {
				throw new Error("offset must be a number greater than or equal to 0");
			}

			const project_filter =
				project_filter_text === "all" || project_filter_text === "none"
					? undefined
					: Number(project_filter_text);

			const response = await list_items({
				status: status_filter === "all" ? undefined : status_filter,
				project_id: typeof project_filter === "number" ? project_filter : undefined,
				limit: parsed_limit,
				offset: parsed_offset
			});

			const filtered_items =
				project_filter_text === "none"
					? response.items.filter((item) => item.project_id === null)
					: response.items;

			set_items(filtered_items);
			set_list_meta(response);
			set_drafts(
				filtered_items.reduce<Record<number, EditableItem>>((acc, item) => {
					acc[item.id] = to_editable_item(item);
					return acc;
				}, {})
			);

			set_selected_item_id((current) => {
				if (current !== null && filtered_items.some((item) => item.id === current)) {
					return current;
				}
				if (filtered_items.length > 0) {
					return filtered_items[0].id;
				}
				return null;
			});
		} catch (err) {
			set_error_text(err instanceof Error ? err.message : "Failed to load items");
		} finally {
			set_is_loading(false);
		}
	};

	useEffect(() => {
		void (async () => {
			try {
				await load_projects();
				await load_items();
			} catch (err) {
				set_error_text(err instanceof Error ? err.message : "Failed to load dashboard data");
			}
		})();
		// eslint-disable-next-line react-hooks/exhaustive-deps
	}, []);

	const save_auth_token = () => {
		if (typeof window === "undefined") {
			return;
		}
		window.localStorage.setItem("kujo_crud_token", normalized_auth_token);
		set_success_text("Saved bearer token in local storage");
	};

	const on_create_submit = async (event: FormEvent) => {
		event.preventDefault();
		set_error_text("");
		set_success_text("");

		try {
			const created = await create_item(
				{
					title: create_title,
					content: create_content,
					status: create_status,
					project_id: project_id_text_to_value(create_project_id_text)
				},
				normalized_auth_token.length > 0 ? normalized_auth_token : undefined
			);

			set_create_title("");
			set_create_content("");
			set_create_status("draft");
			set_create_project_id_text("none");
			set_success_text("Created item #" + String(created.id));
			await load_items();
			set_selected_item_id(created.id);
		} catch (err) {
			set_error_text(err instanceof Error ? err.message : "Failed to create item");
		}
	};

	const update_draft_field = (id: number, field: keyof EditableItem, value: string) => {
		set_drafts((current) => ({
			...current,
			[id]: {
				...current[id],
				[field]: value
			}
		}));
	};

	const save_replace = async () => {
		if (!selected_item || !selected_draft) {
			return;
		}

		set_error_text("");
		set_success_text("");

		try {
			const updated = await replace_item(
				selected_item.id,
				{
					title: selected_draft.title,
					content: selected_draft.content,
					status: selected_draft.status,
					project_id: project_id_text_to_value(selected_draft.project_id_text)
				},
				normalized_auth_token.length > 0 ? normalized_auth_token : undefined,
				selected_item.updated_at
			);

			set_items((current) => current.map((item) => (item.id === updated.id ? updated : item)));
			set_drafts((current) => ({ ...current, [updated.id]: to_editable_item(updated) }));
			set_success_text("Replaced item #" + String(updated.id));
		} catch (err) {
			set_error_text(err instanceof Error ? err.message : "Failed to replace item");
		}
	};

	const save_patch = async () => {
		if (!selected_item || !selected_draft) {
			return;
		}

		set_error_text("");
		set_success_text("");

		try {
			const patch_payload = build_patch_payload(selected_item, selected_draft);
			if (Object.keys(patch_payload).length === 0) {
				throw new Error("No field changes detected");
			}

			const updated = await patch_item(
				selected_item.id,
				patch_payload,
				normalized_auth_token.length > 0 ? normalized_auth_token : undefined,
				selected_item.updated_at
			);

			set_items((current) => current.map((item) => (item.id === updated.id ? updated : item)));
			set_drafts((current) => ({ ...current, [updated.id]: to_editable_item(updated) }));
			set_success_text("Patched item #" + String(updated.id));
		} catch (err) {
			set_error_text(err instanceof Error ? err.message : "Failed to patch item");
		}
	};

	const delete_selected = async () => {
		if (!selected_item) {
			return;
		}

		set_error_text("");
		set_success_text("");

		try {
			await delete_item(selected_item.id, normalized_auth_token.length > 0 ? normalized_auth_token : undefined, selected_item.updated_at);
			set_success_text("Deleted item #" + String(selected_item.id));
			await load_items();
		} catch (err) {
			set_error_text(err instanceof Error ? err.message : "Failed to delete item");
		}
	};

	return (
		<section className="playground">
			<div className="card intro-card">
				<h2>Extendable CRUD Example</h2>
				<p>
					This frontend is intentionally minimal. It focuses on showing API behavior for listing,
					creating, replacing, patching, and deleting records with sample data.
				</p>
			</div>

			<div className="card controls-grid">
				<div>
					<label htmlFor="api-url">API Base URL</label>
					<input id="api-url" readOnly value={api_base_url} />
				</div>
				<div>
					<label htmlFor="auth-token">Bearer Token (optional)</label>
					<input
						id="auth-token"
						type="password"
						value={auth_token}
						onChange={(event) => set_auth_token(event.target.value)}
					/>
				</div>
				<div className="control-actions">
					<button type="button" className="secondary" onClick={save_auth_token}>
						Save Token
					</button>
					<button type="button" className="secondary" onClick={() => void load_items()} disabled={is_loading}>
						{is_loading ? "Refreshing..." : "Refresh List"}
					</button>
				</div>
			</div>

			{error_text.length > 0 ? <div className="feedback error">{error_text}</div> : null}
			{success_text.length > 0 ? <div className="feedback success">{success_text}</div> : null}

			<div className="playground-grid">
				<section className="card">
					<h3>Create Item</h3>
					<form className="form-grid" onSubmit={on_create_submit}>
						<div>
							<label htmlFor="create-title">Title</label>
							<input
								id="create-title"
								required
								maxLength={200}
								value={create_title}
								onChange={(event) => set_create_title(event.target.value)}
							/>
						</div>
						<div>
							<label htmlFor="create-content">Content</label>
							<textarea
								id="create-content"
								required
								maxLength={50000}
								value={create_content}
								onChange={(event) => set_create_content(event.target.value)}
							/>
						</div>
						<div>
							<label htmlFor="create-status">Status</label>
							<select
								id="create-status"
								value={create_status}
								onChange={(event) => set_create_status(event.target.value as ItemStatus)}
							>
								{STATUS_VALUES.map((status) => (
									<option key={status} value={status}>
										{status}
									</option>
								))}
							</select>
						</div>
						<div>
							<label htmlFor="create-project">Project</label>
							<select
								id="create-project"
								value={create_project_id_text}
								onChange={(event) => set_create_project_id_text(event.target.value)}
							>
								<option value="none">No project</option>
								{projects.map((project) => (
									<option key={project.id} value={String(project.id)}>
										{project.name}
									</option>
								))}
							</select>
						</div>
						<button className="primary" type="submit">
							Create
						</button>
					</form>
				</section>

				<section className="card">
					<div className="section-head">
						<h3>Items</h3>
						<p>
							{list_meta
								? "Showing " + String(items.length) + " of " + String(list_meta.total)
								: "Loading..."}
						</p>
					</div>
					<div className="list-filters">
						<div>
							<label htmlFor="status-filter">Status</label>
							<select
								id="status-filter"
								value={status_filter}
								onChange={(event) => set_status_filter(event.target.value as "all" | ItemStatus)}
							>
								<option value="all">all</option>
								{STATUS_VALUES.map((status) => (
									<option key={status} value={status}>
										{status}
									</option>
								))}
							</select>
						</div>
						<div>
							<label htmlFor="project-filter">Project</label>
							<select id="project-filter" value={project_filter_text} onChange={(event) => set_project_filter_text(event.target.value)}>
								<option value="all">all projects</option>
								<option value="none">unassigned</option>
								{projects.map((project) => (
									<option key={project.id} value={String(project.id)}>
										{project.name}
									</option>
								))}
							</select>
						</div>
						<div>
							<label htmlFor="limit">Limit</label>
							<input id="limit" type="number" min={1} max={200} value={limit_text} onChange={(event) => set_limit_text(event.target.value)} />
						</div>
						<div>
							<label htmlFor="offset">Offset</label>
							<input id="offset" type="number" min={0} value={offset_text} onChange={(event) => set_offset_text(event.target.value)} />
						</div>
					</div>
					<div className="item-list">
						{items.map((item) => (
							<button
								type="button"
								key={item.id}
								className={"item-row" + (item.id === selected_item_id ? " active" : "")}
								onClick={() => set_selected_item_id(item.id)}
							>
								<div>
									<strong>{item.title}</strong>
									<p>#{item.id} • {item.project_name || "No project"}</p>
									<p>{format_timestamp(item.updated_at)}</p>
								</div>
								<span className={"badge " + item.status}>{item.status}</span>
							</button>
						))}
						{items.length === 0 ? <p className="empty-note">No items found.</p> : null}
					</div>
				</section>

				<section className="card">
					<h3>Edit Selected Item</h3>
					{selected_item && selected_draft ? (
						<div className="form-grid">
							<div>
								<label htmlFor="edit-title">Title</label>
								<input
									id="edit-title"
									maxLength={200}
									value={selected_draft.title}
									onChange={(event) => update_draft_field(selected_item.id, "title", event.target.value)}
								/>
							</div>
							<div>
								<label htmlFor="edit-content">Content</label>
								<textarea
									id="edit-content"
									maxLength={50000}
									value={selected_draft.content}
									onChange={(event) => update_draft_field(selected_item.id, "content", event.target.value)}
								/>
							</div>
							<div>
								<label htmlFor="edit-status">Status</label>
								<select
									id="edit-status"
									value={selected_draft.status}
									onChange={(event) => update_draft_field(selected_item.id, "status", event.target.value)}
								>
									{STATUS_VALUES.map((status) => (
										<option key={status} value={status}>
											{status}
										</option>
									))}
								</select>
							</div>
							<div>
								<label htmlFor="edit-project">Project</label>
								<select
									id="edit-project"
									value={selected_draft.project_id_text}
									onChange={(event) => update_draft_field(selected_item.id, "project_id_text", event.target.value)}
								>
									<option value="none">No project</option>
									{projects.map((project) => (
										<option key={project.id} value={String(project.id)}>
											{project.name}
										</option>
									))}
								</select>
							</div>
							<div className="control-actions">
								<button type="button" className="primary" onClick={() => void save_replace()}>
									PUT Replace
								</button>
								<button type="button" className="secondary" onClick={() => void save_patch()}>
									PATCH Update
								</button>
								<button type="button" className="danger" onClick={() => void delete_selected()}>
									DELETE
								</button>
							</div>
							<p className="meta-note">
								Project {selected_item.project_name || "No project"} • Created {format_timestamp(selected_item.created_at)} • Updated {format_timestamp(selected_item.updated_at)}
							</p>
						</div>
					) : (
						<p className="empty-note">Select an item to edit it.</p>
					)}
				</section>
			</div>
		</section>
	);
}
