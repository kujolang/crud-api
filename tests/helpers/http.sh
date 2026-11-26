# A fixture may stop only the child it started.
require_free_port() {
	if lsof -nP -iTCP:"$1" -sTCP:LISTEN -t >/dev/null; then
		echo "Test port $1 is already in use" >&2
		exit 1
	fi
}
