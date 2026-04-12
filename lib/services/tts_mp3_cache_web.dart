import 'dart:typed_data';

import 'package:idb_shim/idb_browser.dart';

const _dbName = 'hidoo_tts_mp3_v1';
const _storeName = 'mp3';

Database? _db;

Future<Database?> _openDb() async {
  if (_db != null) return _db;
  try {
    final factory = getIdbFactory();
    if (factory == null) return null;
    _db = await factory.open(
      _dbName,
      version: 1,
      onUpgradeNeeded: (VersionChangeEvent event) {
        final database = event.database;
        if (!database.objectStoreNames.contains(_storeName)) {
          database.createObjectStore(_storeName);
        }
      },
    );
    return _db;
  } catch (_) {
    return null;
  }
}

/// Read cached MP3 from IndexedDB, or `null`.
Future<Uint8List?> ttsMp3CacheGet(String key) async {
  try {
    final db = await _openDb();
    if (db == null) return null;
    final txn = db.transaction(_storeName, idbModeReadOnly);
    final store = txn.objectStore(_storeName);
    final result = await store.getObject(key);
    await txn.completed;
    if (result == null) return null;
    if (result is Uint8List) return result.isEmpty ? null : result;
    if (result is List<int>) {
      final u = Uint8List.fromList(result);
      return u.isEmpty ? null : u;
    }
    return null;
  } catch (_) {
    return null;
  }
}

/// Write MP3 [bytes] under [key].
Future<void> ttsMp3CachePut(String key, Uint8List bytes) async {
  try {
    final db = await _openDb();
    if (db == null) return;
    final txn = db.transaction(_storeName, idbModeReadWrite);
    final store = txn.objectStore(_storeName);
    await store.put(bytes, key);
    await txn.completed;
  } catch (_) {
    // quota / private mode
  }
}
