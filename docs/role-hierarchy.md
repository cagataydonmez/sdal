# Role hierarchy & bootstrap

## Roles

- `root`: system owner. Has all privileges, but is blocked from normal content writes.
- `admin`: full admin capabilities except root-only role elevation.
- `mod`: scoped moderation by graduation year via `moderator_scopes`.
- `user`: default member.

## Bootstrap

- On startup, if no `root` role exists, server reads `ROOT_BOOTSTRAP_PASSWORD`.
- If present, it creates a single root account with a **hashed** password.
- If a root already exists, env bootstrap password is ignored.

## Security rules

- Role changes are root-only via `POST /admin/users/:id/role`.
- Moderator scope assignment is admin/root via `POST /admin/moderators/:id/scopes`.
- All sensitive actions are written to `audit_log`.
- Root users are excluded from common user listings and online member lists.

## Role matrix

| Action | root | admin | mod | user |
|---|---|---|---|---|
| Change roles (`/admin/users/:id/role`) | ✅ | ❌ | ❌ | ❌ |
| Assign moderator scopes | ✅ | ✅ | ❌ | ❌ |
| List moderators | ✅ | ✅ | ❌ | ❌ |
| Normal content writes | ❌ | ✅ | ✅ (scoped ops) | ✅ |
