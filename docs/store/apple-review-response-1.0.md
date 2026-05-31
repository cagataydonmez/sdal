# App Review – Response & Resubmission Guide (SDAL Sosyal 1.0)

Submission ID: 22f1177b-b4f2-4551-867b-3f29f93e7462

---

## PART A — Message to paste into App Store Connect → App Review (Reply)

> Hello, and thank you for the detailed review. We have addressed all three points
> in this new build. Please find our responses below.
>
> **Guideline 2.3.10 – Accurate Metadata (Android references)**
> We have removed all references to Android / Google Play from the App Store
> description. The app itself contains no third-party-platform references in its
> UI. The description now describes only the iOS experience.
>
> **Guideline 3.1.1 – In-App Purchase (license keys)**
> There are no license keys and no externally-unlocked functionality in the app,
> and nothing in the app is paid. The screen the reviewer saw asks for an
> "activation code", which is simply a **free, one-time email-verification code**
> that we email to the user during sign-up to confirm ownership of their email
> address — exactly like a standard "verify your email" code. It does not unlock
> any feature or content and involves no purchase of any kind. To remove any
> ambiguity, we have **relabeled this screen and all related text from
> "Activation code" to "Email verification code"** in this build. SDAL Sosyal is a
> free alumni-community app with no paid tiers, subscriptions, or unlockable
> content.
>
> **Guideline 1.2 – User-Generated Content**
> We have implemented the full set of required precautions:
> - **EULA with zero tolerance for objectionable content and abusive users.** It
>   is presented (a) as a required, must-accept checkbox during registration and
>   (b) as a one-time full-screen acceptance screen on first login for existing
>   users. Users cannot reach any user-generated content until they accept it. The
>   EULA text is available at: https://<YOUR_PUBLIC_DOMAIN>/kullanim-kosullari
> - **Filtering of objectionable content** via our profanity/word filters plus
>   moderator review tools.
> - **A mechanism to flag objectionable content.** Every post and comment has a
>   "Report" action that lets the user choose a reason; the report is recorded and
>   our moderators are notified.
> - **A mechanism to block abusive users.** Users can block another user from any
>   post, comment, or that user's profile. Blocking **instantly removes that
>   user's posts and comments from the blocker's feed** (enforced server-side) and
>   **notifies our team**.
> - **24-hour action commitment.** Our moderators review reports and remove
>   offending content / eject offending users within 24 hours using our admin
>   moderation tools.
>
> **Reviewer login note (email device verification):** The previous build asked the
> review account to complete an email "new device verification" step, which the
> review team could not receive. We have added the review test account to a
> verification-bypass list, so it now logs in directly without any email step.
> Test credentials: **username `test`, password `12345!`**.
>
> A screen recording demonstrating the EULA agreement, the report flow, and the
> block flow is attached in the App Review Information notes.
>
> Thank you again — we're happy to provide anything else you need.

---

## PART B — Demo video to record (physical device) and attach in App Review notes
Record one continuous clip showing:
1. **EULA before use** — fresh registration showing the required "Terms of Use
   (EULA)" checkbox, then (with an existing account) the one-time `/eula`
   acceptance screen on first login.
2. **Flag content** — open a post → "⋯" menu → **Report** → pick a reason →
   confirmation.
3. **Block a user** — "⋯" menu on a post/comment (or the member profile ⋯) →
   **Block user** → confirm → that user's posts disappear from the feed.

---

## PART C — Your action items
1. **App Store Connect → Description:** remove any "Android"/"Google Play" lines.
2. **Record & attach** the demo video above in App Review Information → Notes.
3. **Configure the device-verification bypass** for the review account (Part D).
4. **Deploy** this build's backend (new endpoints/tables) and ship the new IPA.

---

## PART D — Device-verification bypass setup (fixes the "cihaz doğrulama" email step)

The login flow already supports a bypass list; we made it match by **username or
email, case-insensitively**. To exempt the App Review test account:

1. SSH to the production server and edit the env file:
   `/etc/sdal/sdal.env`
2. Add (or extend) this line with the review account's username (the App Review
   test account is **`test`**):
   ```
   TEST_BYPASS_DEVICE_CHECK_USERNAMES=test
   ```
   (comma-separated; you can list more usernames/emails for other QA accounts)
3. Restart the API service:
   ```
   sudo systemctl restart sdal-api.service
   ```

The `test` account will then log in without the email new-device verification
challenge. Reviewer credentials on file: **username `test` / password `12345!`**.
Code: `server/src/http/controllers/authController.js` (`_isDeviceCheckBypassed`).

---

## PART E — Implementation reference (for the team)
- **Email-verification relabel (3.1.1):** `lib/l10n/app_tr.arb`, `app_en.arb`,
  `features/auth/presentation/auth_pages.dart`, `auth_action_controller.dart`.
- **EULA:** served by `server/routes/userSafetyRoutes.js` at `/kullanim-kosullari`;
  Flutter gate `features/legal/presentation/eula_acceptance_page.dart`, router
  `core/routing/app_router.dart` (`/eula`), session wiring in
  `core/session/session_repository.dart` + `session_models.dart`.
- **Report/Block:** backend `server/routes/userSafetyRoutes.js`
  (`/api/new/posts/:id/report`, `/api/new/users/:id/block`, …), feed/comment
  filtering in `server/src/services/feedService.js` and
  `server/src/http/controllers/postController.js`; Flutter
  `features/safety/*`, `feed_page.dart`, `post_detail_page.dart`,
  `explore/presentation/member_detail_page.dart`. Admin review:
  `GET /api/new/admin/content-reports`.
- **New tables** (`user_legal_acceptances`, `content_reports`, `user_blocks`) are
  created at runtime via portable `ensureSchema()` (SQLite + Postgres) — no
  numbered migration required.
