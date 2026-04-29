# Production Auth Flow

## Flow

- Registration still uses the existing email activation flow.
- SMS verification is controlled from the admin panel and is disabled by default.
- When enabled, after email activation, the mobile app requires a one-time Firebase Phone Auth SMS verification.
- When SMS verification succeeds, the backend marks the account phone-verified and trusts the current secure-storage device ID.
- Password login sends the secure device ID and metadata to the backend.
- Trusted devices continue normally.
- New devices do not receive a session until the user completes the email OTP challenge. Completing the challenge registers the device as trusted.
- Trusted devices are stored server-side and can be revoked through `POST /api/auth/device/revoke`.

## Environment

Required in production:

- `AUTH_DEVICE_HASH_PEPPER`
- `AUTH_SMS_MIN_INTERVAL_SECONDS=60`
- `AUTH_SMS_PHONE_HOURLY_LIMIT=3`
- `AUTH_SMS_USER_DAILY_LIMIT=3`
- `AUTH_SMS_IP_HOURLY_LIMIT=10`
- `AUTH_SMS_IP_DAILY_LIMIT=30`
- `AUTH_SIGNUP_IP_HOURLY_LIMIT=20`
- `AUTH_DEVICE_HOURLY_LIMIT=5`
- `AUTH_BLOCK_DISPOSABLE_EMAILS=true`

Development-only:

- `AUTH_FIREBASE_PHONE_MOCK=true` allows `mock-phone:+905551112233` as a Firebase proof.

## Firebase Console Setup

- Enable Firebase Phone Authentication.
- Add development test phone numbers.
- Add iOS bundle ID and APNs key/cert.
- Add Android app with SHA-1 and SHA-256 fingerprints.
- Enable App Check.
- Use Play Integrity for Android production.
- Use App Attest with DeviceCheck fallback for iOS production.
- Enforce App Check only after debug builds and test devices are verified.
- Configure `FCM_PROJECT_ID` and service account credentials for Firebase Admin token verification.

## Test Plan

- First signup requires SMS after email activation.
- Successful SMS marks the account phone-verified and creates a trusted device.
- Same-device password login succeeds.
- New-device password login returns an email OTP challenge and does not create a session.
- Completing the email OTP challenge creates trusted-device trust and opens the session.
- SMS resend is blocked inside `AUTH_SMS_MIN_INTERVAL_SECONDS`.
- Same phone is limited by `AUTH_SMS_PHONE_HOURLY_LIMIT`.
- IP/device signup and SMS rate limits return generic user-facing errors.
- Public errors do not include OTPs, raw phone numbers, or raw device IDs.
- Reinstalling the app creates a new secure random device ID and triggers new-device verification.

## Production Checklist

- Firebase Phone Auth enabled.
- APNs configured for iOS.
- SHA-1/SHA-256 configured for Android.
- App Check enforced after testing.
- Play Integrity enabled.
- App Attest/DeviceCheck enabled.
- `AUTH_DEVICE_HASH_PEPPER` configured and rotated only with a migration plan.
- Logs do not contain OTPs, raw phone numbers, or raw device IDs.
- Abuse and audit logs are reviewed.
- Firebase test phone numbers configured for development.
