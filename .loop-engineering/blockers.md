# External Blockers

blockers:
  - id: typed-env-default-contract
    command: "env_int/env_float/env_bool"
    evidence: "Kujo now supports env_bool(name, default) for missing/invalid values, and CRUD has migrated its pure boolean adapter. The remaining integer normalization still enforces positive bounds beyond the native default contract."
    status: needs-contract-first
    next_action: "Define a documented bounded-integer normalization contract, then migrate only paths covered by compatibility fixtures."
