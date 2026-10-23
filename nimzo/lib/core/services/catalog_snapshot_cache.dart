import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Last-good presentation only. Cached content never establishes prices,
/// entitlement, room powers or permission to spend. Every transaction rechecks
/// current server state. Account namespacing prevents cross-account snapshots.
class CatalogSnapshotCache {
  static const _limit = 2 * 1024 * 1024;
  static String _key(String account, String channel) =>
      'nimzo.catalog.v1.${base64Url.encode(utf8.encode(account))}.$channel';

  static Future<void> save(String account, String channel, Object payload) async {
    try {
      final text = jsonEncode({'saved_at':DateTime.now().toUtc().toIso8601String(),
          'payload':payload});
      if (text.length > _limit) return;
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_key(account,channel), text);
    } catch (_) { /* Cache failure never turns a successful read into a failure. */ }
  }

  static Future<Object?> read(String account, String channel) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final text = preferences.getString(_key(account,channel));
      if (text == null || text.length > _limit) return null;
      final record = jsonDecode(text);
      if (record is! Map || record['saved_at'] is! String) return null;
      final saved = DateTime.tryParse(record['saved_at']);
      final age = saved == null ? null : DateTime.now().toUtc().difference(saved);
      if (age == null || age.isNegative || age > const Duration(hours:24)) return null;
      return record['payload'];
    } catch (_) {return null;}
  }
}
