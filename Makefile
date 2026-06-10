KUJO_BIN ?= kujo

.PHONY: run-api run-frontend lint test

run-api:
	$(KUJO_BIN) run main.ruff --interpreter

run-frontend:
	cd frontend && npm run dev

lint:
	./scripts/quality-check.sh

test:
	KUJO_BIN=$(KUJO_BIN) ./scripts/run-all-tests.sh
