import 'dart:async';
import '../../core/services/renderable_media.dart';
import '../../core/services/media_publication.dart';
import '../../core/services/catalog_snapshot_cache.dart';
import '../../core/services/approved_media_bytes.dart';
import 'private_animal_gifts.dart';
import 'hall_of_fame_gift.dart';
import '../../core/providers/supabase_provider.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/error_handler.dart';
import 'gift_error.dart';

class Gift {
  final String id, name, category;
  final int price;
  final String? assetPath;
  const Gift(this.id, this.name, this.category, this.price, this.assetPath,
      {this.requiresApprovedMedia = false,
      this.playbackKind,
      this.offline = false,
      this.thumbnailPublication,
      this.requiresThumbnailPublication = false});
  final bool requiresApprovedMedia;
  final bool requiresThumbnailPublication;
  final String? playbackKind;
  final bool offline;
  final ApprovedMediaPublication? thumbnailPublication;
}

/// Server-approved playback record, never permission to send or spend coins.
class GiftPlaybackMedia {
  const GiftPlaybackMedia(
      {required this.url,
      required this.kind,
      this.publication,
      this.soundEnabled = false});
  final String url;
  final String kind;
  final ApprovedMediaPublication? publication;
  final bool soundEnabled;

  static GiftPlaybackMedia? fromRow(Map<String, dynamic> row) {
    final raw = row['video_url'];
    final kind = row['media_kind'];
    if (raw is! String ||
        kind is! String ||
        !const {'mp4', 'vap', 'svga'}.contains(kind)) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) return null;
    ApprovedMediaPublication? publication;
    if (row['sha256'] != null ||
        row['byte_size'] != null ||
        row['mime_type'] != null) {
      if (row['sha256'] is! String ||
          row['byte_size'] is! int ||
          row['mime_type'] is! String) return null;
      publication = ApprovedMediaPublication(
          sha256Hex: row['sha256'] as String,
          byteLength: row['byte_size'] as int,
          mimeType: row['mime_type'] as String,
          codec: kind);
      if (!publication.isValid || !uri.path.contains(publication.sha256Hex))
        return null;
    }
    return GiftPlaybackMedia(
        url: uri.toString(),
        kind: kind,
        publication: publication,
        soundEnabled: row['sound_enabled'] == true);
  }
}

class GiftRepository {
  // Historical paid gift receipts are private audit records.
  // Do not query the retired public gift_events history from a client.
  Stream<List<Map<String, dynamic>>> watchRoomGiftEvents(String roomId) =>
      Stream.value(const <Map<String, dynamic>>[]);

  /// Read-only, RLS-scoped animation events created by the settlement trigger.
  /// Subscribe only while a room is active; do not treat these as payment proof
  /// for any client-side wallet updates.
  Stream<List<Map<String, dynamic>>> watchVerifiedAnimations({
    required String roomId,
    required String countryCode,
  }) {
    final normalized = countryCode.trim().toUpperCase();
    if (normalized.isEmpty) {
      return _db
          .from('gift_animation_events')
          .stream(primaryKey: ['id'])
          .eq('room_id', roomId)
          .order('created_at', ascending: false)
          .limit(20)
          .map(
            (rows) => rows
                .where((row) => row['scope'] == 'room')
                .map((row) => Map<String, dynamic>.from(row))
                .toList(),
          );
    }
    // RLS restricts country broadcasts to the signed-in user's country.
    // Room events are filtered locally after the RLS-scoped stream.
    return _db
        .from('gift_animation_events')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(100)
        .map(
          (rows) => rows
              .where(
                (row) =>
                    (row['scope'] == 'room' && row['room_id'] == roomId) ||
                    (row['scope'] == 'country' &&
                        row['country_code'] == normalized),
              )
              .map((row) => Map<String, dynamic>.from(row))
              .toList(),
        );
  }

  /// Read-only fallback for missed Realtime gift events in the joined room.
  /// Uses the same row-level security as the live animation stream; never
  /// creates a gift event or adjusts wallet balances.
  Future<List<Map<String, dynamic>>> recentVerifiedRoomAnimations(
    String roomId, {
    required DateTime since,
  }) async {
    final rows = await _db
        .from('gift_animation_events')
        .select()
        .eq('room_id', roomId)
        .eq('scope', 'room')
        .gte('created_at', since.toUtc().toIso8601String())
        .order('created_at', ascending: true)
        .limit(50);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  /// Only approved HTTPS media are played, after verified server settlement.
  /// Private VAP gifts keep using the existing auth-checked Edge Function.
  Future<GiftPlaybackMedia?> approvedAnimationMedia(String giftId) async {
    if (privateAnimalVapGiftIds.contains(giftId)) {
      final url = await privateMediaUrl(giftId, kind: 'animation');
      return url == null ? null : GiftPlaybackMedia(url: url, kind: 'vap');
    }
    final rows = await _db
        .from('gift_animation_media')
        .select()
        .eq('gift_id', giftId)
        .eq('approved', true)
        .limit(1);
    if (rows.isEmpty) return null;
    final media = GiftPlaybackMedia.fromRow(rows.first);
    if (media != null && giftId == hallOfFameGiftId) {
      return GiftPlaybackMedia(
          url: media.url,
          kind: 'vap',
          publication: media.publication,
          soundEnabled: media.soundEnabled);
    }
    return media;
  }

  /// Retained for existing callers that need only the server-approved URL.
  Future<String?> approvedAnimationUrl(String giftId) async =>
      (await approvedAnimationMedia(giftId))?.url;

  /// Checks private media availability before a debit without issuing a URL.
  Future<bool> privateMediaReady(String giftId) async {
    if (!privateAnimalVapGiftIds.contains(giftId)) return false;
    final response = await _db.functions.invoke(
      'gift-media',
      body: {'gift_id': giftId, 'kind': 'ready'},
    );
    final body = response.data;
    return body is Map && body['ready'] == true;
  }

  /// Authenticated read-only test URL for the designated debug test account.
  /// The Edge Function enforces the account allowlist server-side; this path
  /// NEVER invokes send_gift, creates an event, or updates any coin balance.
  Future<String?> qaGiftAnimationUrl(String giftId) async {
    if (!privateAnimalVapGiftIds.contains(giftId)) return null;
    final response = await _db.functions.invoke(
      'gift-media',
      body: {'gift_id': giftId, 'kind': 'qa_animation'},
    );
    final body = response.data;
    final url = body is Map ? body['url'] as String? : null;
    final uri = Uri.tryParse(url ?? '');
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
        ? url
        : null;
  }

  Future<String?> privateMediaUrl(String giftId, {required String kind}) async {
    if (!privateAnimalVapGiftIds.contains(giftId)) return null;
    final response = await _db.functions.invoke(
      'gift-media',
      body: {'gift_id': giftId, 'kind': kind},
    );
    final data = response.data;
    final url = data is Map ? data['url'] as String? : null;
    final uri = Uri.tryParse(url ?? '');
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
        ? url
        : null;
  }

  final SupabaseClient _db;
  GiftRepository(this._db);

  /// Names always come from authenticated, RLS-filtered public profiles.
  /// Event metadata is server-sourced and never grants payment authority.
  Future<Map<String, String>> participantNamesForVerifiedEvent(
    Map<String, dynamic> event,
  ) async {
    final ids = <String>{
      if (event['sender_id'] is String) event['sender_id'] as String,
      if (event['receiver_id'] is String) event['receiver_id'] as String,
    }
        .where(
          (id) => RegExp(
            r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
          ).hasMatch(id),
        )
        .toList();
    if (ids.isEmpty) return const {};
    try {
      final rows = await _db
          .from('profiles')
          .select('id,nimzo_id,display_name,username')
          .inFilter('id', ids)
          .limit(2);
      final names = <String, String>{};
      for (final row in rows) {
        final id = row['id']?.toString();
        if (id == null || !ids.contains(id)) continue;
        final display = (row['display_name'] as String?)?.trim();
        final username = (row['username'] as String?)?.trim();
        final number = row['nimzo_id'];
        final name = display != null && display.isNotEmpty
            ? display
            : username != null && username.isNotEmpty
                ? username
                : number is num
                    ? 'ID ${number.toString()}'
                    : '';
        if (name.isNotEmpty) names[id] = name;
      }
      return names;
    } catch (_) {
      // Offline or denied profile reads never block a settled effect.
      return const {};
    }
  }

  Future<List<Gift>> catalog() async {
    final account = _db.auth.currentUser?.id;
    List<Gift> parse(List rows, {bool offline = false}) => rows
            .where((j) => giftIsAvailable(Map<String, dynamic>.from(j)))
            .map((j) {
          String? kind = j['media_kind'] as String?;
          final media = j['gift_animation_media'];
          var verifiedAnimation = false;
          if (media is List) {
            for (final row in media) {
              if (row is Map && row['approved'] == true) {
                kind = row['media_kind'] as String?;
                verifiedAnimation = verifiedAnimation || row['sha256'] != null;
              }
            }
          }
          return Gift(j['id'], j['name'], j['category'],
              (j['coin_price'] as num).toInt(), j['asset_path'] as String?,
              requiresApprovedMedia: j['requires_approved_media'] == true,
              requiresThumbnailPublication:
                  verifiedAnimation || j['requires_approved_media'] == true,
              playbackKind: kind,
              offline: offline,
              thumbnailPublication: parseMediaPublication(
                  Map<String, dynamic>.from(j),
                  kind: 'image',
                  prefix: 'thumbnail_'));
        }).toList();
    try {
      final rows = <Map<String, dynamic>>[];
      for (var offset = 0; offset < 5000; offset += 200) {
        final page = await _db
            .from('gifts')
            .select('*,gift_animation_media(*)')
            .eq('active', true)
            .order('priority', ascending: false)
            .order('coin_price')
            .order('id')
            .range(offset, offset + 199)
            .timeout(const Duration(seconds: 8));
        rows.addAll(page);
        if (page.length < 200) break;
        if (offset == 4800)
          throw StateError(
              'Gift catalog exceeds the supported publication limit');
      }
      final parsed = parse(rows);
      if (account != null)
        await CatalogSnapshotCache.save(account, 'gifts', rows);
      return parsed;
    } catch (e) {
      final cached = account == null
          ? null
          : await CatalogSnapshotCache.read(account, 'gifts');
      if (cached is List) return parse(cached, offline: true);
      throw mapError(e);
    }
  }

  /// Preflight presentation before a charge. Postgres separately verifies live
  /// activity, account, price, publication, ownership, ledger and replay keys.
  Future<void> verifyBeforeSending(String giftId) async {
    final rows = await _db
        .from('gifts')
        .select('id,requires_approved_media,available_from,available_until')
        .eq('id', giftId)
        .eq('active', true)
        .limit(1);
    if (rows.isEmpty || !giftIsAvailable(rows.first))
      throw StateError('This gift is unavailable. No new request submitted.');
    if (rows.first['requires_approved_media'] != true) return;
    final media = await approvedAnimationMedia(giftId);
    if (media == null || media.publication == null) {
      throw StateError(
          'Gift animation is unavailable. No new request submitted.');
    }
    try {
      final bytes = await ApprovedMediaBytes.fetch(media.url,
          publication: media.publication);
      await validateRenderableMedia(bytes, media.publication!);
    } catch (_) {
      throw StateError(
          'Gift animation could not be verified. No new request submitted.');
    }
  }

  Future<bool> recoverReceipt(
      {required String scope,
      String? context,
      required String receiverId,
      required String giftId,
      required int qty,
      required String key,
      required int expectedTotal}) async {
    final receipt = await _db.rpc('gift_send_receipt_checked', params: {
      'p_scope': scope,
      'p_context': context,
      'p_receiver': receiverId,
      'p_gift': giftId,
      'p_qty': qty,
      'p_key': key,
      'p_expected_total': expectedTotal,
    });
    if (receipt == null) return false;
    if (receipt is! Map ||
        receipt['status'] != 'replayed' ||
        receipt['total'] != expectedTotal) {
      throw StateError('Gift receipt could not be verified');
    }
    return true;
  }

  Future<void> sendProfile({
    required String receiverId,
    required String giftId,
    required int qty,
    required String key,
    int? expectedTotal,
  }) async {
    _validateGiftRequest(receiverId, giftId, qty, key);
    final account = _db.auth.currentUser?.id;
    try {
      if (expectedTotal != null &&
          await recoverReceipt(
              scope: 'profile',
              receiverId: receiverId,
              giftId: giftId,
              qty: qty,
              key: key,
              expectedTotal: expectedTotal)) return;
      await verifyBeforeSending(giftId);
      if (_db.auth.currentUser?.id != account)
        throw StateError('Account changed before gift submission');
      await _db.rpc(
        expectedTotal == null
            ? 'send_profile_gift'
            : 'send_profile_gift_checked',
        params: {
          'p_receiver': receiverId,
          'p_gift': giftId,
          'p_qty': qty,
          'p_key': key,
          if (expectedTotal != null) 'p_expected_total': expectedTotal,
        },
      );
    } catch (e) {
      throw mapGiftError(e);
    }
  }

  /// Price, balance and the 45/5 split are decided by Postgres `send_gift`.
  /// The idempotency key makes retries safe.
  Future<void> send({
    required String roomId,
    required String receiverId,
    required String giftId,
    required int qty,
    required String key,
    int? expectedTotal,
  }) async {
    if (roomId.trim().isEmpty) {
      throw ArgumentError.value(roomId, 'roomId', 'Room is required.');
    }
    _validateGiftRequest(receiverId, giftId, qty, key);
    final account = _db.auth.currentUser?.id;
    try {
      if (expectedTotal != null &&
          await recoverReceipt(
              scope: 'room',
              context: roomId,
              receiverId: receiverId,
              giftId: giftId,
              qty: qty,
              key: key,
              expectedTotal: expectedTotal)) return;
      await verifyBeforeSending(giftId);
      if (_db.auth.currentUser?.id != account)
        throw StateError('Account changed before gift submission');
      await _db.rpc(
        expectedTotal == null ? 'send_gift' : 'send_gift_checked',
        params: {
          'p_room': roomId,
          'p_receiver': receiverId,
          'p_gift': giftId,
          'p_qty': qty,
          'p_key': key,
          if (expectedTotal != null) 'p_expected_total': expectedTotal,
        },
      );
    } catch (e) {
      throw mapGiftError(e);
    }
  }

  static void _validateGiftRequest(
    String receiverId,
    String giftId,
    int qty,
    String key,
  ) {
    if (receiverId.trim().isEmpty) {
      throw ArgumentError.value(
        receiverId,
        'receiverId',
        'Recipient is required.',
      );
    }
    if (giftId.trim().isEmpty) {
      throw ArgumentError.value(giftId, 'giftId', 'Gift is required.');
    }
    if (qty <= 0) {
      throw RangeError.value(qty, 'qty', 'Quantity must be positive.');
    }
    if (key.trim().isEmpty) {
      throw ArgumentError.value(key, 'key', 'Idempotency key is required.');
    }
  }
}

final giftRepositoryProvider = Provider(
  (ref) => GiftRepository(ref.watch(sessionSupabaseProvider).client),
);
bool giftIsAvailable(Map<String, dynamic> row, {DateTime? now}) {
  final current = (now ?? DateTime.now()).toUtc();
  final from = row['available_from'], until = row['available_until'];
  if ((from != null && (from is! String || DateTime.tryParse(from) == null)) ||
      (until != null && (until is! String || DateTime.tryParse(until) == null)))
    return false;
  final start = from == null ? null : DateTime.parse(from as String).toUtc();
  final end = until == null ? null : DateTime.parse(until as String).toUtc();
  return (start == null || !current.isBefore(start)) &&
      (end == null || current.isBefore(end));
}

final giftCatalogProvider = FutureProvider((ref) {
  final timer = Timer(const Duration(minutes: 1), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return ref.watch(giftRepositoryProvider).catalog();
});
final roomGiftEventProvider =
    StreamProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
  (ref, roomId) =>
      ref.watch(giftRepositoryProvider).watchRoomGiftEvents(roomId),
);

final verifiedGiftAnimationProvider = StreamProvider.autoDispose
    .family<List<Map<String, dynamic>>, ({String roomId, String countryCode})>(
  (ref, args) => ref.watch(giftRepositoryProvider).watchVerifiedAnimations(
        roomId: args.roomId,
        countryCode: args.countryCode,
      ),
);

final privateGiftThumbnailProvider =
    FutureProvider.autoDispose.family<String?, String>(
  (ref, giftId) => ref
      .watch(giftRepositoryProvider)
      .privateMediaUrl(giftId, kind: 'thumbnail'),
);
