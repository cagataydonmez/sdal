# SDAL Native iOS Starter

Native SwiftUI starter app for the SDAL backend.

- Backend host: `https://sdalsosyal.mywire.org`
- API base: `https://sdalsosyal.mywire.org/api`
- Server IP (deployment reference): `79.76.102.130`
- Auth style: cookie session (`/api/auth/login`, `/api/session`)

## Included

- `App`: app lifecycle and tab navigation
- `Core`: API client, configuration, shared app state
- `Features`: Login, Feed, Explore, Messages, Profile
- `UI`: reusable design tokens and components

## Quick setup in Xcode

1. Open `/Users/cagataydonmez/Desktop/SDAL/ios-native/SDALNative.xcodeproj` in Xcode.
2. Select your Apple Team in Signing settings and set your bundle id.
3. Build and run.

## Initial API coverage

- Login: `POST /api/auth/login`
- Session: `GET /api/session`
- Logout: `POST /api/auth/logout`
- Feed: `GET /api/new/feed?limit&offset&scope`
- Create post: `POST /api/new/posts` and `POST /api/new/posts/upload`
- Suggestions: `GET /api/new/explore/suggestions?limit&offset`
- Messages: `GET /api/messages?box&page&pageSize`
- Profile: `GET /api/profile`
- Stories list/upload/view: `GET /api/new/stories`, `POST /api/new/stories/upload`, `POST /api/new/stories/:id/view`
- Push registration hook: `POST /api/new/push/register` (gracefully ignored if unavailable)

## Notes

- The backend response schema may vary by endpoint. Models are intentionally tolerant with optional fields.
- Cookies are persisted through `HTTPCookieStorage.shared` to support session-based auth.
