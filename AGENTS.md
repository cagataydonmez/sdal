# AGENTS.md

## Repository profile
- Stack: Node.js / React / Postgres
- Goal: minimize context usage while preserving correctness

## Discovery order
1. package.json / workspace config
2. app entrypoints
3. routes / controllers
4. services / domain logic
5. db schema / migrations / queries
6. tests
7. shared types / config

## Editing rules
- Never load the whole repo without a strong reason.
- Summarize relevant files before editing.
- Prefer symbol-level reads and small snippets.
- Reuse prior findings instead of rereading.

## Validation rules
- Run the narrowest test or typecheck that can verify the change.
- Mention commands run and unverified risks.
