import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'package:mybrev_flutter/models/priest_access_content.dart';

class ProtectedCatalogSnapshot {
  ProtectedCatalogSnapshot(
    this.uid,
    Iterable<String> sets,
    this.scope,
    this.content,
  ) : sets = Set.unmodifiable(sets);

  final String uid;
  final Set<String> sets;
  // Includes rollout mode and the verified profile ID and revision.
  final String scope;
  final PrayerAccessContent content;

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'scope': scope,
    'sets': sets.toList()..sort(),
    'prayers': content.prayers,
    'categories': content.categories,
  };

  factory ProtectedCatalogSnapshot.fromJson(Map<String, dynamic> value) {
    Map<String, Map<String, dynamic>> rows(String kind) =>
        (value[kind] as Map<String, dynamic>).map(
          (id, data) => MapEntry(id, data as Map<String, dynamic>),
        );
    return ProtectedCatalogSnapshot(
      value['uid'] as String,
      (value['sets'] as List).cast<String>(),
      value['scope'] as String,
      PrayerAccessContent(rows('prayers'), rows('categories')),
    );
  }
}

abstract interface class ProtectedCatalogStorage {
  Future<ProtectedCatalogSnapshot?> read({bool staging = false});
  Future<void> write(ProtectedCatalogSnapshot value, {bool staging = false});
  Future<void> delete({bool stagingOnly = false});
}

/// Authenticate the native-only envelope before attempting CBC decryption.
/// The directory and its device-bound key are independently excluded from backup.
class SealedProtectedCatalogStorage implements ProtectedCatalogStorage {
  SealedProtectedCatalogStorage({
    required this.directory,
    required this.readKey,
    required this.writeKey,
    required this.deleteKey,
  });

  static const _version = 'mybrev-offline-catalog-v1';
  static const _maxBytes = 32 * 1024 * 1024;
  final Future<Directory> Function() directory;
  final Future<String?> Function() readKey;
  final Future<void> Function(String) writeKey;
  final Future<void> Function() deleteKey;

  static ProtectedCatalogStorage? forPlatform() {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return null;
    }
    const channel = MethodChannel('mybrev/protected-catalog');
    const secure = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
    );
    return SealedProtectedCatalogStorage(
      directory: () async {
        final path = await channel.invokeMethod<String>('directory');
        if (path == null || path.isEmpty) throw const FileSystemException();
        return Directory(path);
      },
      readKey: () => secure.read(key: _version),
      writeKey: (key) => secure.write(key: _version, value: key),
      deleteKey: () => secure.delete(key: _version),
    );
  }

  Future<File> _file(bool staging) async {
    final folder = await directory();
    final name = staging ? 'staging' : 'catalog';
    return File([folder.path, '$name.bin'].join(Platform.pathSeparator));
  }

  List<int> _derived(List<int> master, String purpose) =>
      Hmac(sha256, master).convert(utf8.encode('$_version:$purpose')).bytes;

  List<int> _tag(List<int> master, List<int> bytes, bool staging) => Hmac(
    sha256,
    _derived(master, staging ? 'staging-mac' : 'catalog-mac'),
  ).convert(bytes).bytes;

  bool _equal(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a[i] ^ b[i];
    }
    return difference == 0;
  }

  @override
  Future<ProtectedCatalogSnapshot?> read({bool staging = false}) async {
    try {
      final file = await _file(staging);
      if (!await file.exists() || await file.length() > _maxBytes) return null;
      final encoded = await readKey();
      if (encoded == null) return null;
      final master = base64Url.decode(encoded);
      if (master.length != 32) return null;
      final bytes = await file.readAsBytes();
      if (bytes.length < 64 || bytes.length > _maxBytes) return null;
      final cipherText = Uint8List.sublistView(bytes, 32);
      if (cipherText.length % 16 != 0 ||
          !_equal(
            Uint8List.sublistView(bytes, 0, 32),
            _tag(master, cipherText, staging),
          )) {
        return null;
      }
      final cipher = HiveAesCipher(_derived(master, 'encryption'));
      final plain = Uint8List(cipherText.length);
      final length = cipher.decrypt(cipherText, 0, cipherText.length, plain, 0);
      final envelope =
          jsonDecode(utf8.decode(Uint8List.sublistView(plain, 0, length)))
              as Map<String, dynamic>;
      if (envelope['version'] != _version) return null;
      final snapshot = envelope['snapshot'] as Map<String, dynamic>;
      if (envelope['contentVersion'] != _catalogVersion(snapshot)) return null;
      return ProtectedCatalogSnapshot.fromJson(snapshot);
    } catch (_) {
      return null;
    }
  }

  String _catalogVersion(Map<String, dynamic> snapshot) {
    Iterable<List<dynamic>> rows(String kind) sync* {
      final documents = snapshot[kind] as Map;
      final ids = documents.keys.cast<String>().toList()..sort();
      for (final id in ids) {
        final row = documents[id] as Map;
        yield [
          kind,
          id,
          row['contentHash'] ??
              sha256.convert(utf8.encode(jsonEncode(row))).toString(),
        ];
      }
    }

    return sha256
        .convert(
          utf8.encode(jsonEncode([...rows('prayers'), ...rows('categories')])),
        )
        .toString();
  }

  @override
  Future<void> write(
    ProtectedCatalogSnapshot value, {
    bool staging = false,
  }) async {
    final file = await _file(staging);
    var encoded = await readKey();
    if (encoded == null) {
      encoded = base64Url.encode(Hive.generateSecureKey());
      await writeKey(encoded);
    }
    final master = base64Url.decode(encoded);
    if (master.length != 32) throw const FormatException('Invalid catalog key');
    final snapshot = value.toJson();
    final plain = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'version': _version,
          'contentVersion': _catalogVersion(snapshot),
          'snapshot': snapshot,
        }),
      ),
    );
    if (plain.length > _maxBytes - 64) {
      throw const FormatException('Catalog too large');
    }
    final cipher = HiveAesCipher(_derived(master, 'encryption'));
    final output = Uint8List(cipher.maxEncryptedSize(plain));
    final length = cipher.encrypt(plain, 0, plain.length, output, 0);
    final cipherText = Uint8List.sublistView(output, 0, length);
    final pending = File('${file.path}.new');
    await pending.writeAsBytes([
      ..._tag(master, cipherText, staging),
      ...cipherText,
    ], flush: true);
    await pending.rename(file.path);
  }

  @override
  Future<void> delete({bool stagingOnly = false}) async {
    try {
      if (!stagingOnly) await deleteKey();
    } finally {
      for (final staging in [true, if (!stagingOnly) false]) {
        final file = await _file(staging);
        for (final item in [file, File('${file.path}.new')]) {
          if (await item.exists()) await item.delete();
        }
      }
    }
  }
}
