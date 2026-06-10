import { api_base_url } from "@/lib/runtime-config";
export { api_base_url };

export type ItemStatus = "draft" | "published" | "archived";

export interface Item {
	id: number;
	title: string;
	content: string;
	status: ItemStatus;
	project_id: number | null;
	project_name: string | null;
	created_at: string;
	updated_at: string;
}

export interface Project {
	id: number;
	name: string;
	description: string;
	created_at: string;
	updated_at: string;
	items_count?: number;
}

export interface ListItemsOptions {
	limit?: number;
	offset?: number;
	status?: ItemStatus;
	project_id?: number;
	sort_by?: "id" | "title" | "status" | "created_at" | "updated_at";
	sort_dir?: "asc" | "desc";
	q?: string;
	cursor?: string;
}

export interface ListItemsResponse {
	items: Item[];
	count: number;
	total: number;
	limit: number;
	offset: number;
	has_more: boolean;
	status: string;
	project_id?: number | null;
	sort_by?: string;
	sort_dir?: string;
	q?: string;
	cursor?: string;
	next_cursor?: string;
}

export interface ItemPayload {
	title: string;
	content: string;
	status: ItemStatus;
	project_id?: number | null;
}

export interface ListProjectsResponse {
	projects: Project[];
	count: number;
}

export interface ProjectItemsResponse {
	project: Project;
	items: Item[];
	count: number;
}

/**
 * Builds request headers and optionally adds bearer auth.
 *
 * @param authToken Optional bearer token for write routes
 * @param isJson Whether to include JSON content type header
 * @returns Header map for fetch
 */
function build_headers(authToken?: string, isJson?: boolean, ifUnmodifiedSince?: string): HeadersInit {
	const headers: HeadersInit = {};

	if (isJson) {
		headers["Content-Type"] = "application/json";
	}

	if (authToken && authToken.trim().length > 0) {
		headers.Authorization = "Bearer " + authToken.trim();
	}

	if (ifUnmodifiedSince && ifUnmodifiedSince.trim().length > 0) {
		headers["If-Unmodified-Since"] = ifUnmodifiedSince.trim();
	}

	return headers;
}

/**
 * Executes a request and enforces the API error contract.
 *
 * @param path API route path beginning with /
 * @param options Fetch options
 * @returns Parsed JSON payload on success
 */
async function request_json<T>(path: string, options: RequestInit = {}): Promise<T> {
	const response = await fetch(api_base_url + path, {
		...options,
		cache: "no-store"
	});

	let payload: unknown = null;
	try {
		payload = await response.json();
	} catch (err) {
		if (!response.ok) {
			throw new Error("Request failed with status " + response.status);
		}
	}

	if (!response.ok) {
		const data = payload as { error?: string } | null;
		throw new Error(data?.error || "Request failed with status " + response.status);
	}

	return payload as T;
}

/**
 * Lists items with optional filtering and pagination.
 *
 * @param options Query options
 * @returns Paginated items response
 */
export async function list_items(options: ListItemsOptions = {}): Promise<ListItemsResponse> {
	const params = new URLSearchParams();

	if (typeof options.limit === "number") {
		params.set("limit", String(options.limit));
	}

	if (typeof options.offset === "number") {
		params.set("offset", String(options.offset));
	}

	if (options.status) {
		params.set("status", options.status);
	}

	if (typeof options.project_id === "number") {
		params.set("project_id", String(options.project_id));
	}

	if (options.sort_by) {
		params.set("sort_by", options.sort_by);
	}

	if (options.sort_dir) {
		params.set("sort_dir", options.sort_dir);
	}

	if (options.q && options.q.trim().length > 0) {
		params.set("q", options.q.trim());
	}

	if (options.cursor && options.cursor.trim().length > 0) {
		params.set("cursor", options.cursor.trim());
	}

	const query = params.toString();
	const path = query.length > 0 ? "/items?" + query : "/items";
	return request_json<ListItemsResponse>(path);
}

/**
 * Gets a single item by ID.
 *
 * @param id Item ID
 * @returns Item from API
 */
export async function get_item(id: number): Promise<Item> {
	return request_json<Item>("/items/" + String(id));
}

/**
 * Lists all projects.
 *
 * @returns Project collection with relation counts
 */
export async function list_projects(): Promise<ListProjectsResponse> {
	return request_json<ListProjectsResponse>("/projects");
}

/**
 * Lists items assigned to one project.
 *
 * @param projectId Project ID
 * @returns Project and its related items
 */
export async function list_project_items(projectId: number): Promise<ProjectItemsResponse> {
	return request_json<ProjectItemsResponse>("/projects/" + String(projectId) + "/items");
}

/**
 * Creates a new item.
 *
 * @param payload Item payload
 * @param authToken Optional bearer token
 * @returns Created item
 */
export async function create_item(payload: ItemPayload, authToken?: string): Promise<Item> {
	return request_json<Item>("/items", {
		method: "POST",
		headers: build_headers(authToken, true),
		body: JSON.stringify(payload)
	});
}

/**
 * Replaces an item using PUT.
 *
 * @param id Item ID
 * @param payload Full replacement payload
 * @param authToken Optional bearer token
 * @returns Updated item
 */
export async function replace_item(id: number, payload: ItemPayload, authToken?: string, ifUnmodifiedSince?: string): Promise<Item> {
	return request_json<Item>("/items/" + String(id), {
		method: "PUT",
		headers: build_headers(authToken, true, ifUnmodifiedSince),
		body: JSON.stringify(payload)
	});
}

/**
 * Partially updates an item using PATCH.
 *
 * @param id Item ID
 * @param payload Partial payload of changed fields
 * @param authToken Optional bearer token
 * @returns Updated item
 */
export async function patch_item(id: number, payload: Partial<ItemPayload>, authToken?: string, ifUnmodifiedSince?: string): Promise<Item> {
	return request_json<Item>("/items/" + String(id), {
		method: "PATCH",
		headers: build_headers(authToken, true, ifUnmodifiedSince),
		body: JSON.stringify(payload)
	});
}

/**
 * Deletes an item by ID.
 *
 * @param id Item ID
 * @param authToken Optional bearer token
 */
export async function delete_item(id: number, authToken?: string, ifUnmodifiedSince?: string): Promise<{ deleted: boolean; id: number }> {
	return request_json<{ deleted: boolean; id: number }>("/items/" + String(id), {
		method: "DELETE",
		headers: build_headers(authToken, false, ifUnmodifiedSince)
	});
}
