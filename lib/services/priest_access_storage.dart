import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class PriestAccessStorage {
  Future<Map<String, dynamic>> read();
  Future<void> write(Map<String, dynamic> data);
}

class SecurePriestAccessStorage implements PriestAccessStorage {
  // Firebase Auth owns its persisted credentials. This record contains only a
  // display hint and a durable UID for deferred self-revocation, never a code.
  static const _key = 'priest_device_spark_v2';
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
  @override
  Future<Map<String, dynamic>> read() async {
    await _storage.delete(key: 'priest_device_v1');
    final raw = await _storage.read(key: _key);
    return raw == null ? {} : Map<String, dynamic>.from(jsonDecode(raw));
  }

  @override
  Future<void> write(Map<String, dynamic> data) =>
      _storage.write(key: _key, value: jsonEncode(data));
}
