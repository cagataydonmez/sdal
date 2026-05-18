# Shell Aliases

Suggested aliases for `~/.zshrc` or your shell profile:

```sh
alias sdal-codex-backend='./scripts/ai/sdal-codex-backend.sh'
alias sdal-codex-flutter='./scripts/ai/sdal-codex-flutter.sh'
alias sdal-codex-watchos='./scripts/ai/sdal-codex-watchos.sh'
alias sdal-codex-review='./scripts/ai/sdal-codex-review.sh'
alias sdal-codex-debug='./scripts/ai/sdal-codex-debug.sh'
alias sdal-codex-deploy='./scripts/ai/sdal-codex-deploy.sh'
alias sdal-codex-db='./scripts/ai/sdal-codex-db.sh'
alias sdal-codex-uiux='./scripts/ai/sdal-codex-uiux.sh'
```

Example use:

```sh
sdal-codex-flutter "Admin panel search input overflows on iPhone"
sdal-codex-backend "Fix notification unread count contract"
sdal-codex-review "Review current branch against main"
```

Claude command examples:

```text
/sdal-flutter Admin panel search input overflows on iPhone
/sdal-backend Fix notification unread count contract
/sdal-review Review current branch against main
/sdal-debug Push registration fails after login
/sdal-deploy DigitalOcean deploy health check times out
/sdal-db Add safe migration for user activity index
/sdal-watchos TestFlight rejects watch app icon metadata
/sdal-uiux Improve admin moderation queue density
```
