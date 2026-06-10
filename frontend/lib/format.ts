/**
 * Converts API timestamp values into a readable local date string.
 */
export function format_timestamp(value: string): string {
	const as_number = Number(value);
	if (!Number.isNaN(as_number)) {
		const milliseconds = as_number > 1000000000000 ? as_number : as_number * 1000;
		return new Date(milliseconds).toLocaleString();
	}

	const parsed = new Date(value);
	if (!Number.isNaN(parsed.getTime())) {
		return parsed.toLocaleString();
	}

	return value;
}
