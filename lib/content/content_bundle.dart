import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

/// Format of the canonical content shipped inside the app
/// (`assets/content/`, built by MyBrev `npm run content:app-bundle`).
const kContentSchemaVersion = 1;
const kContentAssetDir = 'assets/content';

/// Marks a reference into the collection's string table.
const kStringRef = '\u0001';

/// Collections that ship with the app and are kept current by the version
/// manifest. Same list as MyBrev `APP_CONTENT_COLLECTIONS`.
const kContentCollections = [
  'days',
  'readings',
  'liturgicalTemplates',
  'invitatoriums',
  'completoriums',
  'prayers',
  'prayerCategories',
  'songs',
  // Compendium of the Catechism: units, and `current` (meta and parts).
  'compendium',
  'compendiumMeta',
];

/// What the Liturgy of the Hours and the Readings need before a day opens.
const kLiturgicalCollections = [
  'days',
  'readings',
  'liturgicalTemplates',
  'invitatoriums',
  'completoriums',
];

/// One decoded collection of the bundle.
class DecodedCollection {
  const DecodedCollection({
    required this.collection,
    required this.contentVersion,
    required this.docs,
    required this.hashes,
  });

  final String collection;
  final int contentVersion;
  final Map<String, Map<String, dynamic>> docs;
  final Map<String, String> hashes;
}

/// gzip → JSON → documents with the shared strings resolved. Runs in an
/// isolate (`compute`); the documents share the table's String objects.
DecodedCollection decodeContentCollection(Uint8List gzipBytes) {
  final json =
      jsonDecode(utf8.decode(GZipDecoder().decodeBytes(gzipBytes)))
          as Map<String, dynamic>;
  if (json['schemaVersion'] != kContentSchemaVersion) {
    throw FormatException(
      'Unsupported content schema ${json['schemaVersion']}',
    );
  }
  final strings = (json['strings'] as List).cast<String>();
  Object? resolve(Object? value) {
    if (value is String) {
      return value.startsWith(kStringRef)
          ? strings[int.parse(value.substring(1))]
          : value;
    }
    if (value is List) {
      for (var i = 0; i < value.length; i++) {
        value[i] = resolve(value[i]);
      }
      return value;
    }
    if (value is Map) {
      for (final key in value.keys.toList()) {
        value[key] = resolve(value[key]);
      }
      return value;
    }
    return value;
  }

  final rawDocs = json['docs'] as Map<String, dynamic>;
  final docs = <String, Map<String, dynamic>>{
    for (final entry in rawDocs.entries)
      entry.key: resolve(entry.value)! as Map<String, dynamic>,
  };
  final hashes = (json['hashes'] as Map).cast<String, String>();
  if (!docs.keys.every(hashes.containsKey)) {
    throw const FormatException('A bundled document has no hash');
  }
  return DecodedCollection(
    collection: json['collection'] as String,
    contentVersion: (json['contentVersion'] as num).toInt(),
    docs: docs,
    hashes: hashes,
  );
}

/// Digest of a collection: sha256 over «id\thash\n» lines sorted by id
/// (MyBrev `collectionDigest`). An unknown hash is written empty, so a
/// document of unknown version always makes the digest differ.
String contentDigest(Map<String, String?> hashes) {
  final ids = hashes.keys.toList()..sort();
  final buffer = StringBuffer();
  for (final id in ids) {
    buffer
      ..write(id)
      ..write('\t')
      ..write(hashes[id] ?? '')
      ..write('\n');
  }
  return sha256
      .convert(utf8.encode(buffer.toString()))
      .toString()
      .substring(0, 16);
}

/// Written by imports, not part of the text (MyBrev `BOOKKEEPING_FIELDS`).
const kBookkeepingFields = {
  'updatedAt',
  'importedAt',
  'parsedAt',
  'miniSavedAt',
};

/// Stable JSON with sorted keys (MyBrev `canonicalJson`).
String canonicalJson(Object? value) {
  final buffer = StringBuffer();
  void write(Object? item) {
    if (item is Map) {
      final keys = item.keys.map((key) => key.toString()).toList()..sort();
      buffer.write('{');
      for (var i = 0; i < keys.length; i++) {
        if (i > 0) buffer.write(',');
        buffer
          ..write(jsonEncode(keys[i]))
          ..write(':');
        write(item[keys[i]]);
      }
      buffer.write('}');
    } else if (item is List) {
      buffer.write('[');
      for (var i = 0; i < item.length; i++) {
        if (i > 0) buffer.write(',');
        write(item[i]);
      }
      buffer.write(']');
    } else if (item is double &&
        item == item.truncateToDouble() &&
        item.isFinite) {
      // JavaScript prints 2.0 as 2.
      buffer.write(item.toInt());
    } else {
      buffer.write(jsonEncode(item));
    }
  }

  write(value);
  return buffer.toString();
}

/// Hash of a stored document (MyBrev `documentHash`).
String documentHash(Map document) {
  final content = {
    for (final entry in document.entries)
      if (!kBookkeepingFields.contains(entry.key)) entry.key: entry.value,
  };
  return sha256
      .convert(utf8.encode(canonicalJson(content)))
      .toString()
      .substring(0, 16);
}
