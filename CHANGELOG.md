## 0.1.1

- Smaller package: screenshots, goldens and tooling are no longer shipped (archive 1 MB → 460 KB); README images load from GitHub.
- pub.dev metadata: description, platforms (Android, iOS, Web), screenshots, repository and issue tracker.
- `flutter_secure_storage` allows `>=9.2.0 <12.0.0`.
- Automated publishing from GitHub Actions on `v*` tags.

## 0.1.0

First public release (MVP), built on the Raselna chat API v1.

- `RaselnaChat.init(accessKey: …)`, `RaselnaChat.open(context)`, `RaselnaChatView()`, `RaselnaChat.setUser()` (stub: not in API v1 yet).
- Native bubbles, quick replies, option sheet, text/number/phone/email/date input with validation, slot picker, status/end/paused cards, typing indicator, step progress.
- "Continue in browser" card for catalog, cart, form, secret and unknown steps; resumes when the app returns.
- Offline queue with a fixed idempotency key per reply.
- Theme from the business's palette (contrast-safe) with `RaselnaChatTheme` overrides; light and dark.
- Arabic (RTL, default) and English strings; bundled Tajawal (OFL).
- `HttpTransport` on the chat API v1 contract: device registration (re-registers once on `device_not_found`), `handoff` on turns, ETag config, `Retry-After`, resume by code, logout via `DELETE /devices/current`.
- Device credential and queue in Keychain / Keystore (`flutter_secure_storage`).
- `MockTransport` with a bakery-ordering and a clinic-booking conversation.
