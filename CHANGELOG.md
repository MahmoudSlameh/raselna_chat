## 0.2.0

Rich steps are native: the app no longer opens a browser except for secret questions.

- **Catalogue** (`product_list`): in-chat card and a sheet with search, category tabs, product rows (picture, price, unit, sold out), a product sheet with option groups and a quantity stepper that follows the product's step; cart count and total in a bottom bar. The sheet stays open between adds.
- **Cart** (`cart`): lines with options and the server's totals, −/+ steppers (bin at the minimum), add more, confirm.
- **Checkout form** (`form`): opens by itself; choice (with hints), text, textarea and phone fields, `show_if`, required and phone checks on the device, the server's per-field errors.
- **Product finder**: results (`product_list`, mode `pick`) as swipeable cards with a details sheet and gallery; price range (`form`, mode `range`).
- New `ActionReply` (rich-step actions) and `RaselnaChatController.act()`; actions go through the offline queue with a fixed idempotency key like any reply.
- `X-Raselna-Capabilities: product_list,product_list.pick,cart,form,form.range,slots` (chat API 1.1, `raselnaCapabilities`); an unknown mode of a known kind hands off.
- The server's `handoff` decides: with the declared capabilities it sends none for these kinds; `secret` always opens the system browser (never a WebView, never native); unknown kinds and modes still open the browser.
- New `RaselnaShopStrings` (Arabic and English) under `RaselnaStrings.shop`.
- `MockTransport`: the bakery now runs the native catalogue, cart and checkout; new `MockScenario.store` (finder); optional `imageBase` for demo pictures.
- Example app: store demo, product pictures on the web build.

## 0.1.1

- Automated publishing: pushing a `v*` tag publishes to pub.dev from GitHub Actions with pub.dev's OIDC login (no stored token). See "Releasing" in the README.
- Smaller archive (about 460 KB, was about 1 MB): `.pubignore` leaves out the full-size screenshots, the golden test images and the screenshot tooling. README images now use absolute URLs so they still show on pub.dev.
- pub.dev metadata: declared platforms (Android, iOS, web), two screenshots, shorter description.
- Allow `flutter_secure_storage` 10.x and 11.x.

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
