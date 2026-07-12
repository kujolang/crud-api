# External Blockers

blockers:
  - id: typed-env-default-contract
    command: "env_int/env_float/env_bool"
    evidence: "Native typed environment accessors do not provide the local missing/blank/invalid fallback semantics required by CRUD configuration; the migration therefore uses one small native-backed default adapter."
    status: needs-contract-first
    next_action: "Add optional/default typed environment primitives or document their fallback contract, then remove the adapter and add invalid-value compatibility tests."
