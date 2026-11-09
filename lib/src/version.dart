/// Sent as `X-Raselna-SDK: flutter/<version>`. Keep in step with pubspec.
const raselnaSdkVersion = '0.2.0';

/// The rich prompt kinds (and modes) this SDK draws natively, sent as
/// `X-Raselna-Capabilities` (chat API 1.1). For these the server sends no
/// handoff and expects `{"action": …}` replies; a secret question always
/// hands off whatever is declared.
const raselnaCapabilities = [
  'product_list',
  'product_list.pick',
  'cart',
  'form',
  'form.range',
  'slots',
];
