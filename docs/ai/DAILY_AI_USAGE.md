# Daily AI Usage

Use these short prompts instead of pasting the full SDAL workflow every time.

## Codex

Run from repo root:

```sh
./scripts/ai/sdal-codex-backend.sh "Fix login session expiry after password reset"
./scripts/ai/sdal-codex-flutter.sh "Admin user search layout breaks on small phones"
./scripts/ai/sdal-codex-review.sh "Review current branch against main"
```

## Claude

Use project slash commands if Claude exposes `.claude/commands`:

```text
/sdal-backend Fix login session expiry after password reset
/sdal-flutter Admin user search layout breaks on small phones
/sdal-review Review current branch against main
```

If slash command arguments are not expanded in your Claude version, run the command and paste the task underneath it.

## Short Examples

- Backend bug fix: `/sdal-backend <bug>` or `$sdal-backend-change <bug>`
- Backend API change: `/sdal-backend <endpoint/payload change>`
- Flutter UI change: `/sdal-flutter <screen/task>`
- Flutter admin panel change: `/sdal-flutter <admin task>`
- watchOS/TestFlight issue: `/sdal-watchos <issue>`
- Deployment issue: `/sdal-deploy <issue>`
- Database migration issue: `/sdal-db <schema/query task>`
- Review-only task: `/sdal-review <what to review>`
- Debug task: `/sdal-debug <symptom>`
- UI/UX design task: `/sdal-uiux <screen/workflow>`

## Daily Rule Of Thumb

- Use Codex scripts when you want repo-local implementation with repeatable guardrails.
- Use Claude slash commands when you are already in Claude and want the same guardrails.
- Use review/debug commands when you want investigation first.
- Never ask either tool to scan the whole repo; these shortcuts already tell them to search first and read focused files.
