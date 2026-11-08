import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the SDK keeps its few values: the device credential (a secret,
/// per the API contract) and the offline queue. Never a customer's secret
/// answer: those never pass through the app.
///
/// The default is [SecureStore] (Keychain on iOS, Keystore-backed storage on
/// Android). Implement this to use your own storage.
abstract class RaselnaStore {
  Future<String?> read(String key);
  Future<void> write(String key, String? value);
}

/// Keychain / Keystore storage. Keys are namespaced (`raselna_chat.`) so
/// they never collide with the app's own.
class SecureStore implements RaselnaStore {
  SecureStore({this.prefix = 'raselna_chat.', FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final String prefix;
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: prefix + key);
    } on Exception {
      // A Keystore reset (e.g. after a backup restore) loses the value: the
      // SDK then registers the device again.
      return null;
    }
  }

  @override
  Future<void> write(String key, String? value) async {
    if (value == null) {
      await _storage.delete(key: prefix + key);
    } else {
      await _storage.write(key: prefix + key, value: value);
    }
  }
}

/// In memory only (tests, previews, the mock demo).
class MemoryStore implements RaselnaStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String? value) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}
