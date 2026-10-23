import '../../core/widgets/published_image.dart';
import 'dart:async';
import '../../core/services/catalog_snapshot_cache.dart';
import '../../core/services/media_publication.dart';
import '../../core/services/approved_media_bytes.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'store_purchase_keys.dart';
import '../premium/membership_identity.dart';

import 'store_visual_equipment.dart';
import 'store_purchase_repository.dart';
import '../wallet/wallet_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'premium_cosmetics.dart';
import 'cosmetic_media_view.dart';

import '../../core/providers/supabase_provider.dart';
import '../../core/widgets/art/nimzo_identity_art.dart';

/// Account catalog with pinned media for imported items and original vector art.
class NimzoCosmeticItem {
  const NimzoCosmeticItem({
    required this.id,
    required this.category,
    required this.name,
    required this.variant,
    required this.coinPrice,
    this.thumbnailUrl,
    this.assetUrl,
    this.mediaKind,
    this.publication,
    this.thumbnailPublication,
    this.durationDays,
  });

  final String id;
  final String category;
  final String name;
  final int variant;
  final int coinPrice;
  final int? durationDays;
  final String? thumbnailUrl;
  final String? assetUrl;
  final CosmeticMediaKind? mediaKind;
  final ApprovedMediaPublication? publication;
  final ApprovedMediaPublication? thumbnailPublication;

  /// Only a server-approved, validated asset can be rendered or equipped.
  CosmeticMedia? get remoteMedia => assetUrl == null || mediaKind == null
      ? null
      : CosmeticMedia(id, category, name, assetUrl!, mediaKind!,
          thumbnail: thumbnailUrl,
          publication: publication,
          thumbnailPublication: thumbnailPublication);

  factory NimzoCosmeticItem.fromJson(Map<String, dynamic> json) {
    String? httpsUrl(Object? input) {
      final uri = Uri.tryParse(input is String ? input : '');
      return uri != null &&
              uri.scheme == 'https' &&
              uri.host.isNotEmpty &&
              uri.userInfo.isEmpty
          ? uri.toString()
          : null;
    }

    final kind = switch (json['media_kind']) {
      'image' => CosmeticMediaKind.image,
      'svga' => CosmeticMediaKind.svga,
      'vap' => CosmeticMediaKind.vap,
      _ => null,
    };
    final publication = parseMediaPublication(json,
        kind: json['media_kind'] as String? ?? 'image');
    final thumbnailPublication =
        parseMediaPublication(json, kind: 'image', prefix: 'thumbnail_');
    return NimzoCosmeticItem(
      id: json['id'] as String,
      category: json['category'] as String,
      name: json['name'] as String,
      variant: (json['variant'] as num).toInt(),
      coinPrice: (json['coin_price'] as num).toInt(),
      durationDays: json['duration_days'] as int?,
      thumbnailUrl: publication != null && thumbnailPublication == null
          ? null
          : httpsUrl(json['thumbnail_url']),
      thumbnailPublication: thumbnailPublication,
      assetUrl: httpsUrl(json['asset_url']),
      publication: publication,
      mediaKind: kind,
    );
  }
}

class NimzoStoreSnapshot {
  const NimzoStoreSnapshot(
      {required this.items,
      required this.owned,
      required this.equipped,
      this.expiresAt = const {},
      this.offline = false});
  final List<NimzoCosmeticItem> items;
  final Set<String> owned;
  final Map<String, String> equipped;
  final Map<String, DateTime?> expiresAt;
  final bool offline;

  factory NimzoStoreSnapshot.fromRows(Map<String, dynamic> payload,
      {bool offline = false,
      DateTime? now,
      Set<String> maskedSlots = const {}}) {
    final current = (now ?? DateTime.now()).toUtc();
    final items = (payload['catalog'] as List)
        .map((e) =>
            NimzoCosmeticItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final expiry = <String, DateTime?>{};
    for (final e in payload['ownership'] as List) {
      if (e is! Map || e['item_id'] is! String) continue;
      final raw = e['expires_at'];
      if (raw != null && (raw is! String || DateTime.tryParse(raw) == null))
        continue;
      final date = raw == null ? null : DateTime.parse(raw as String).toUtc();
      if (date == null || date.isAfter(current))
        expiry[e['item_id'] as String] = date;
    }
    const order = [
      'Avatar Frame',
      'Rides',
      'Party Theme',
      'Chat Bubble',
      'Live Frame',
      'Royal Badge',
      'ID Frame',
      'Profile Card',
      'Mic Wave'
    ];
    items.sort((a, b) {
      final variant = a.variant.compareTo(b.variant);
      return variant != 0
          ? variant
          : order.indexOf(a.category).compareTo(order.indexOf(b.category));
    });
    return NimzoStoreSnapshot(
        items: items,
        owned: expiry.keys.toSet(),
        expiresAt: expiry,
        offline: offline,
        equipped: {
          for (final e in payload['equipped'] as List)
            if (e is Map &&
                e['category'] is String &&
                !maskedSlots.contains(e['category']) &&
                expiry.containsKey(e['item_id']))
              e['category'] as String: e['item_id'] as String,
        });
  }
}

final nimzoStoreProvider =
    FutureProvider.autoDispose<NimzoStoreSnapshot>((ref) async {
  final session = ref.watch(sessionSupabaseProvider);
  final id = session.userId;
  if (id == null) throw StateError('Please sign in to view the Store.');
  Future<List<Map<String, dynamic>>> pages(dynamic query) async {
    final all = <Map<String, dynamic>>[];
    for (var offset = 0; offset < 5000; offset += 200) {
      final rows = await query
          .range(offset, offset + 199)
          .timeout(const Duration(seconds: 8));
      all.addAll(
          (rows as List).map((e) => Map<String, dynamic>.from(e as Map)));
      if (rows.length < 200) return all;
    }
    throw StateError('Store catalog exceeds the supported publication limit');
  }

  Map<String, dynamic> payload;
  var offline = false;
  try {
    final catalog = await pages(session.client
        .from('nimzo_cosmetic_catalog')
        .select('id,category,name,variant,coin_price,duration_days')
        .eq('active', true)
        .order('category')
        .order('variant')
        .order('id'));
    final remote = await pages(session.client
        .from('nimzo_cosmetic_media')
        .select()
        .eq('approved', true)
        .order('item_id'));
    final approved = {for (final e in remote) e['item_id']: e};
    final ownership = await pages(session.client
        .from('nimzo_cosmetic_ownership')
        .select('item_id,expires_at')
        .eq('user_id', id)
        .order('item_id'));
    final equipped = await pages(session.client
        .from('nimzo_cosmetic_equipped')
        .select('category,item_id')
        .eq('user_id', id)
        .order('category'));
    payload = {
      'catalog': [
        for (final row in catalog) {...row, ...?approved[row['id']]}
      ],
      'ownership': ownership,
      'equipped': equipped
    };
    // Parse before saving: an invalid publication cannot replace last-good data.
    NimzoStoreSnapshot.fromRows(payload);
    await CatalogSnapshotCache.save(id, 'store', payload);
  } catch (_) {
    final cached = await CatalogSnapshotCache.read(id, 'store');
    if (cached is! Map) rethrow;
    payload = Map<String, dynamic>.from(cached);
    offline = true;
  }
  final membership = ref.watch(effectiveMembershipProvider(id));
  final snapshot = NimzoStoreSnapshot.fromRows(payload,
      offline: offline,
      maskedSlots: membership.hasError
          ? const {}
          : membership.valueOrNull?.packSlots ?? const {});
  final dates = snapshot.expiresAt.values.whereType<DateTime>().toList()
    ..sort();
  final refresh = dates.isEmpty
      ? const Duration(minutes: 3)
      : dates.first.difference(DateTime.now().toUtc());
  final timer = Timer(
      refresh.isNegative
          ? Duration.zero
          : refresh > const Duration(minutes: 3)
              ? const Duration(minutes: 3)
              : refresh,
      ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return snapshot;
});

class NimzoLiveStore extends ConsumerStatefulWidget {
  const NimzoLiveStore({super.key, this.initialBag = false});

  final bool initialBag;

  @override
  ConsumerState<NimzoLiveStore> createState() => _NimzoLiveStoreState();
}

class _NimzoLiveStoreState extends ConsumerState<NimzoLiveStore> {
  late bool bag = widget.initialBag;
  String category = 'All';
  String? pending;
  PendingStorePurchase? _savedPurchase;
  StorePurchaseKeys? _purchaseStorage;
  bool _restoringPurchase = true;
  String? _purchaseRestoreError;
  int _purchaseGeneration = 0;

  @override
  void initState() {
    super.initState();
    try {
      final account = ref.read(sessionSupabaseProvider).userId;
      _restorePurchase(account);
      ref.listenManual(sessionSupabaseProvider, (previous, next) {
        if (previous?.userId != next.userId) _restorePurchase(next.userId);
      });
    } catch (_) {
      _restoringPurchase = false;
      _purchaseRestoreError = 'Sign in to manage Store purchases.';
    }
  }

  Future<void> _restorePurchase(String? account) async {
    final generation = ++_purchaseGeneration;
    setState(() {
      pending = null;
      _savedPurchase = null;
      _purchaseStorage = null;
      _restoringPurchase = true;
      _purchaseRestoreError = null;
    });
    if (account == null) {
      setState(() => _restoringPurchase = false);
      return;
    }
    try {
      final storage = StorePurchaseKeys(await SharedPreferences.getInstance());
      final saved = storage.read(account);
      if (!mounted || generation != _purchaseGeneration) return;
      setState(() {
        _purchaseStorage = storage;
        _savedPurchase = saved;
        _restoringPurchase = false;
      });
    } catch (_) {
      if (mounted && generation == _purchaseGeneration)
        setState(() {
          _restoringPurchase = false;
          _purchaseRestoreError =
              'Saved Store receipt unavailable. Reopen the Store before buying.';
        });
    }
  }

  bool _samePurchaseAccount(String account, int generation) =>
      mounted &&
      generation == _purchaseGeneration &&
      ref.read(sessionSupabaseProvider).userId == account;

  Future<void> _executeSavedPurchase(PendingStorePurchase request) async {
    final generation = _purchaseGeneration;
    final storage = _purchaseStorage;
    if (storage == null ||
        !_samePurchaseAccount(request.accountId, generation)) {
      throw StateError('Reopen the Store to check your saved purchase.');
    }
    await storage.prepare(request);
    if (!_samePurchaseAccount(request.accountId, generation)) return;
    setState(() => _savedPurchase = request);
    try {
      final result =
          await ref.read(nimzoStorePurchaseRepositoryProvider).purchase(
                itemId: request.itemId,
                expectedPrice: request.expectedPrice,
                retryKey: request.key,
              );
      await storage.complete(request);
      if (!_samePurchaseAccount(request.accountId, generation)) return;
      setState(() => _savedPurchase = null);
      ref.invalidate(nimzoStoreProvider);
      ref.invalidate(walletProvider);
      ref.invalidate(storeVisualEquipmentProvider);
      ref.invalidate(effectiveMembershipProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result.status == 'already_owned'
              ? '${request.itemName} is already in your Backpack. No coins charged.'
              : '${request.itemName} purchase confirmed. Check your Backpack.')));
    } catch (error) {
      // Only explicit SQL rollback responses release a saved confirmation.
      // Decoder, transport, malformed response and idempotency mismatches retain it.
      if (error is PostgrestException &&
          const {'22023', '42501'}.contains(error.code) &&
          const {
            'Paid item is not available',
            'Store price changed; refresh to confirm',
            'Item media not ready; no coins charged',
            'Insufficient coins; no purchase made',
            'Store publication unavailable; no coins charged',
            'Account unavailable'
          }.contains(error.message)) {
        await storage.complete(request);
        if (_samePurchaseAccount(request.accountId, generation)) {
          setState(() => _savedPurchase = null);
        }
      }
      rethrow;
    }
  }

  Future<void> _retrySavedPurchase() async {
    final request = _savedPurchase;
    if (request == null || pending != null || _restoringPurchase) return;
    final generation = _purchaseGeneration;
    setState(() => pending = request.itemId);
    try {
      final accepted = await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
                title: const Text('Retry saved purchase?'),
                content: Text(
                    '${request.itemName} · ${request.expectedPrice} coins originally confirmed. '
                    'This checks the same request and completes it only if it has not settled.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialog, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(dialog, true),
                      child: const Text('Retry')),
                ],
              ));
      if (accepted != true ||
          !_samePurchaseAccount(request.accountId, generation)) return;
      await _executeSavedPurchase(request);
    } catch (_) {
      if (_samePurchaseAccount(request.accountId, generation)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Purchase not confirmed. Your original request is saved for retry.')));
      }
    } finally {
      if (mounted && generation == _purchaseGeneration)
        setState(() => pending = null);
    }
  }

  Widget _savedPurchaseNotice() {
    final saved = _savedPurchase;
    if (!_restoringPurchase && _purchaseRestoreError == null && saved == null) {
      return const SizedBox.shrink();
    }
    return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Row(children: [
          Expanded(
              child: Text(
                  _restoringPurchase
                      ? 'Checking saved purchase…'
                      : _purchaseRestoreError ??
                          'Pending: ${saved!.itemName} · ${saved.expectedPrice} coins originally confirmed',
                  key: const ValueKey('store-pending-receipt'),
                  style:
                      const TextStyle(color: Color(0xff987330), fontSize: 12))),
          if (saved != null)
            TextButton(
              key: const ValueKey('store-retry-purchase'),
              onPressed: pending != null ? null : _retrySavedPurchase,
              child: const Text('Retry'),
            ),
        ]));
  }

  static const categories = <String>[
    'All',
    'Avatar Frame',
    'Party Theme',
    'Rides',
    'Chat Bubble',
    'Live Frame',
    'Royal Badge',
    'ID Frame',
    'Profile Card',
    'Mic Wave',
  ];

  static const colors = <Color>[
    Color(0xffefbf65),
    Color(0xfff48cad),
    Color(0xffe9a08e),
    Color(0xffa395ed),
    Color(0xff55c6ab),
    Color(0xff79b8e8),
    Color(0xffd4a467),
  ];

  NimzoArt artFor(String type) => switch (type) {
        'Avatar Frame' => NimzoArt.frame,
        'Party Theme' => NimzoArt.theme,
        'Rides' => NimzoArt.entrance,
        'Chat Bubble' => NimzoArt.bubble,
        'Live Frame' => NimzoArt.live,
        'Royal Badge' => NimzoArt.crest,
        _ => NimzoArt.reward,
      };

  IconData categoryIcon(String type) => switch (type) {
        'Avatar Frame' => Icons.filter_frames_rounded,
        'Party Theme' => Icons.palette_rounded,
        'Rides' => Icons.directions_car_rounded,
        'Chat Bubble' => Icons.chat_bubble_rounded,
        'Live Frame' => Icons.crop_square_rounded,
        'Royal Badge' => Icons.workspace_premium_rounded,
        _ => Icons.storefront_rounded,
      };

  Future<void> doAction(
      NimzoCosmeticItem item, bool isOwned, bool equipped) async {
    if (pending != null || _restoringPurchase) return;
    final generation = _purchaseGeneration;
    setState(() => pending = item.id);
    final session = ref.read(sessionSupabaseProvider);
    try {
      dynamic confirmed;
      if (session.userId == null) throw StateError('Sign in required');
      if (equipped) {
        confirmed = await session.client
            .rpc('nimzo_store_unequip', params: {'p_category': item.category});
      } else if (isOwned) {
        confirmed = await session.client.rpc(
          'nimzo_store_equip_free',
          params: {'p_item_id': item.id},
        );
      } else if (item.coinPrice == 0) {
        confirmed = await session.client.rpc(
          'nimzo_store_claim_free',
          params: {'p_item_id': item.id},
        );
      } else {
        if (item.remoteMedia == null) {
          throw StateError('Item media not ready. No coins charged.');
        }
        if (_purchaseRestoreError != null || _savedPurchase != null) {
          throw StateError(
              'Resolve the saved purchase before buying another item.');
        }
        final accepted = await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: const Text('Confirm Store purchase'),
            content: Text(
              'Buy ${item.name} for ${item.coinPrice} coins${item.durationDays == null ? ' (lifetime)' : ' for ${item.durationDays} days'}? '
              'The server verifies the final price.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialog).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialog).pop(true),
                child: const Text('Buy'),
              ),
            ],
          ),
        );
        if (!mounted ||
            accepted != true ||
            ref.read(sessionSupabaseProvider).userId != session.userId) return;
        await _executeSavedPurchase(PendingStorePurchase(
          accountId: session.userId!,
          itemId: item.id,
          itemName: item.name,
          expectedPrice: item.coinPrice,
          key: PendingStorePurchase.newKey(),
          durationDays: item.durationDays,
        ));
        return;
      }
      if (confirmed != true) {
        throw StateError('Server did not confirm the update.');
      }
      if (!mounted ||
          ref.read(sessionSupabaseProvider).userId != session.userId) {
        return;
      }
      ref.invalidate(nimzoStoreProvider);
      ref.invalidate(storeVisualEquipmentProvider);
      ref.invalidate(effectiveMembershipProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(equipped
              ? '${item.name} removed'
              : isOwned
                  ? '${item.name} equipped'
                  : '${item.name} added to Backpack'),
        ));
      }
    } catch (error) {
      // Network failures may occur after the server commits a purchase.
      if (mounted &&
          generation == _purchaseGeneration &&
          ref.read(sessionSupabaseProvider).userId == session.userId) {
        ref.invalidate(nimzoStoreProvider);
        ref.invalidate(walletProvider);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Unable to update Store: $error'),
        ));
      }
    } finally {
      if (mounted && generation == _purchaseGeneration)
        setState(() => pending = null);
    }
  }

  Widget itemTile(NimzoCosmeticItem item, NimzoStoreSnapshot snap) {
    final isOwned = snap.owned.contains(item.id);
    final equipped = snap.equipped[item.category] == item.id;
    final busy = pending == item.id;
    final accent = colors[item.variant % colors.length];

    return InkWell(
      key: ValueKey('nimzo-store-preview-${item.id}'),
      borderRadius: BorderRadius.circular(17),
      onTap: () => Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => NimzoStoreFullPreview(
            item: item,
            owned: isOwned,
            equipped: equipped,
          ),
        ),
      ),
      child: Container(
        key: ValueKey('nimzo-store-item-${item.id}'),
        decoration: BoxDecoration(
          color: const Color(0xffffffff),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: equipped ? const Color(0xff155a3f) : const Color(0xffdce7df),
            width: equipped ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.all(9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: ColoredBox(
                      color: const Color(0xffedf4ee),
                      child: Center(
                        child: item.thumbnailUrl != null
                            ? PublishedImage(
                                url: item.thumbnailUrl!,
                                publication: item.thumbnailPublication)
                            : premiumCosmetics[item.id] != null
                                ? CosmeticMediaView(
                                    key: ValueKey(item.id),
                                    media: premiumCosmetics[item.id]!,
                                    animate: false,
                                  )
                                : item.id.startsWith('nimzo-media-')
                                    ? const Icon(
                                        Icons.image_not_supported_outlined,
                                        semanticLabel: 'Item media unavailable',
                                      )
                                    : NimzoIdentityArt(
                                        kind: artFor(item.category),
                                        variant: item.variant,
                                        color: accent,
                                        size: 102,
                                      ),
                      ),
                    ),
                  ),
                  if (isOwned)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              equipped ? const Color(0xff155a3f) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          equipped ? 'Equipped' : 'Owned',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: equipped
                                ? Colors.white
                                : const Color(0xff155a3f),
                          ),
                        ),
                      ),
                    ),
                  const Positioned(
                    bottom: 6,
                    right: 6,
                    child: Icon(
                      Icons.zoom_in_rounded,
                      color: Color(0xff657c6c),
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 7),
            Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: Color(0xff155a3f),
              ),
            ),
            Text(
              item.coinPrice > 0
                  ? '${item.category} · ${item.coinPrice} coins${item.durationDays == null ? '' : ' · ${item.durationDays} days'}'
                  : item.category,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: Color(0xff667b70)),
            ),
            const SizedBox(height: 7),
            SizedBox(
              height: 35,
              child: FilledButton(
                key: ValueKey('nimzo-store-action-${item.id}'),
                onPressed: snap.offline ||
                        busy ||
                        pending != null ||
                        (item.coinPrice > 0 &&
                            !isOwned &&
                            item.remoteMedia == null)
                    ? null
                    : () => doAction(item, isOwned, equipped),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xff155a3f),
                  foregroundColor: const Color(0xffffffff),
                  disabledBackgroundColor: const Color(0xffdce7df),
                  disabledForegroundColor: const Color(0xff667b70),
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                ),
                child: busy
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        equipped
                            ? 'Remove'
                            : isOwned
                                ? 'Equip'
                                : item.coinPrice == 0
                                    ? 'Collect free'
                                    : item.remoteMedia != null
                                        ? 'Buy'
                                        : 'Not for sale',
                        style: const TextStyle(fontSize: 11),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(nimzoStoreProvider);
    return Scaffold(
      backgroundColor: const Color(0xfff4f8f5),
      appBar: AppBar(
        title: Text(
          bag ? 'Your Backpack' : 'NIMZO Store',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: const Color(0xfff4f8f5),
        foregroundColor: const Color(0xff155a3f),
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Refresh Store',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(nimzoStoreProvider),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _savedPurchaseNotice(),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xff104d37), Color(0xff207353)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bag ? 'MAKE IT YOURS' : 'THE NIMZO COLLECTION',
                          style: const TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.6,
                            color: Color(0xffe7d09c),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          bag
                              ? 'Your signature style.'
                              : 'A look that is yours.',
                          style: const TextStyle(
                            fontSize: 23,
                            height: 1.15,
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          bag
                              ? state.maybeWhen(
                                  data: (snapshot) =>
                                      '${snapshot.owned.length} collected · ${snapshot.equipped.length} equipped',
                                  orElse: () =>
                                      'Your collection, wherever you go.',
                                )
                              : 'Discover details that make you stand out.',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xffd2e7da),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    bag ? Icons.backpack_outlined : Icons.diamond_outlined,
                    size: 42,
                    color: const Color(0xffe7d09c),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 12, 15, 8),
              child: Row(
                children: [
                  Expanded(
                    child: _tabButton(
                      label: 'Store',
                      selected: !bag,
                      icon: Icons.storefront_rounded,
                      onTap: () => setState(() => bag = false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _tabButton(
                      label: 'Backpack',
                      selected: bag,
                      icon: Icons.backpack_rounded,
                      onTap: () => setState(() => bag = true),
                    ),
                  ),
                ],
              ),
            ),
            if (!bag)
              SizedBox(
                height: 46,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final selected = category == categories[i];
                    return ChoiceChip(
                      selected: selected,
                      label: Text(categories[i]),
                      labelStyle: TextStyle(
                        color: selected
                            ? const Color(0xffffffff)
                            : const Color(0xff365c48),
                        fontSize: 11,
                      ),
                      selectedColor: const Color(0xff155a3f),
                      backgroundColor: const Color(0xfff4f8f5),
                      onSelected: (_) =>
                          setState(() => category = categories[i]),
                    );
                  },
                ),
              ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 15, vertical: 9),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Choose your look. Collected items save to your '
                  'Backpack; equipped designs sync with your account.',
                  style: TextStyle(color: Color(0xff667b70), fontSize: 11),
                ),
              ),
            ),
            Expanded(
              child: state.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.store_mall_directory_outlined,
                          color: Color(0xff869b8f),
                          size: 42,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Store catalog unavailable',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Color(0xff155a3f),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Please retry. No coins have been charged.',
                          style: TextStyle(color: Color(0xff667b70)),
                          textAlign: TextAlign.center,
                        ),
                        TextButton(
                          onPressed: () => ref.invalidate(nimzoStoreProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (snap) {
                  final filtered = snap.items
                      .where(
                        (item) =>
                            (!bag || snap.owned.contains(item.id)) &&
                            (bag ||
                                category == 'All' ||
                                item.category == category),
                      )
                      .toList(growable: false);

                  if (snap.offline) {
                    return Column(children: [
                      const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                              'Offline saved catalog · reconnect to buy or equip.',
                              key: ValueKey('store-offline-notice'))),
                      Expanded(
                          child: ListView(children: [
                        for (final item in filtered) itemTile(item, snap)
                      ])),
                    ]);
                  }
                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        bag
                            ? 'Your collection starts here.\nExplore the Store to find your first design.'
                            : 'No designs available in this category.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xff667b70)),
                      ),
                    );
                  }
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final cols = constraints.maxWidth >= 680
                          ? 4
                          : constraints.maxWidth >= 460
                              ? 3
                              : 2;
                      return GridView.builder(
                        key: ValueKey(
                          bag ? 'store-backpack-grid' : 'store-catalog-grid',
                        ),
                        padding: const EdgeInsets.fromLTRB(15, 6, 15, 60),
                        itemCount: filtered.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          mainAxisExtent: 225 +
                              (MediaQuery.textScalerOf(context).scale(48) - 48),
                        ),
                        itemBuilder: (_, i) => itemTile(filtered[i], snap),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabButton({
    required String label,
    required bool selected,
    required IconData icon,
    required VoidCallback onTap,
  }) =>
      Material(
        color: selected ? const Color(0xff155a3f) : const Color(0xffffffff),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(
            height: 46,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected
                      ? const Color(0xffffffff)
                      : const Color(0xff365c48),
                ),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: selected
                        ? const Color(0xffffffff)
                        : const Color(0xff365c48),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

/// Full preview uses the same pinned item media as the Store card.
class NimzoStoreFullPreview extends StatefulWidget {
  const NimzoStoreFullPreview({
    super.key,
    required this.item,
    required this.owned,
    required this.equipped,
  });

  final NimzoCosmeticItem item;
  final bool owned;
  final bool equipped;

  @override
  State<NimzoStoreFullPreview> createState() => _NimzoStoreFullPreviewState();
}

class _NimzoStoreFullPreviewState extends State<NimzoStoreFullPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..forward();

  NimzoArt get art => switch (widget.item.category) {
        'Avatar Frame' => NimzoArt.frame,
        'Party Theme' => NimzoArt.theme,
        'Rides' => NimzoArt.entrance,
        'Chat Bubble' => NimzoArt.bubble,
        'Live Frame' => NimzoArt.live,
        'Royal Badge' => NimzoArt.crest,
        _ => NimzoArt.reward,
      };

  static const accents = <Color>[
    Color(0xffefbf65),
    Color(0xfff48cad),
    Color(0xffe9a08e),
    Color(0xffa395ed),
    Color(0xff55c6ab),
    Color(0xff79b8e8),
    Color(0xffd4a467),
  ];

  int replay = 0;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final color = accents[item.variant % accents.length];
    final media = item.remoteMedia ?? premiumCosmetics[item.id];
    final animatedMedia =
        media != null && media.kind != CosmeticMediaKind.image;
    final canvas =
        (MediaQuery.sizeOf(context).width * .84).clamp(180.0, 390.0).toDouble();
    return Scaffold(
      key: const ValueKey('nimzo-store-full-preview'),
      backgroundColor: const Color(0xfff4f8f5),
      appBar: AppBar(
        title: Text(item.name),
        centerTitle: true,
        foregroundColor: const Color(0xff155a3f),
        backgroundColor: const Color(0xfff4f8f5),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: InteractiveViewer(
                  minScale: .7,
                  maxScale: 3,
                  child: item.remoteMedia != null
                      ? SizedBox(
                          width: canvas,
                          height: canvas,
                          child: CosmeticMediaView(
                            key: ValueKey('remote-${item.id}-$replay'),
                            media: item.remoteMedia!,
                            animate: !MediaQuery.disableAnimationsOf(context),
                          ),
                        )
                      : item.thumbnailUrl != null
                          ? SizedBox(
                              width: canvas,
                              height: canvas,
                              child: PublishedImage(
                                  url: item.thumbnailUrl!,
                                  publication: item.thumbnailPublication))
                          : premiumCosmetics[item.id] != null
                              ? SizedBox(
                                  width: canvas,
                                  height: canvas,
                                  child: CosmeticMediaView(
                                    key: ValueKey('${item.id}-$replay'),
                                    media: premiumCosmetics[item.id]!,
                                    animate: !MediaQuery.disableAnimationsOf(
                                        context),
                                  ),
                                )
                              : item.id.startsWith('nimzo-media-')
                                  ? const Icon(
                                      Icons.image_not_supported_outlined,
                                      semanticLabel: 'Item media unavailable',
                                    )
                                  : AnimatedBuilder(
                                      animation: controller,
                                      builder: (_, __) => NimzoIdentityArt(
                                        kind: art,
                                        variant: item.variant,
                                        color: color,
                                        size: canvas,
                                        progress:
                                            MediaQuery.disableAnimationsOf(
                                                    context)
                                                ? 1
                                                : controller.value,
                                      ),
                                    ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      color: Color(0xff155a3f),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.category,
                    style: const TextStyle(color: Color(0xff667b70)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.equipped
                        ? 'Equipped'
                        : widget.owned
                            ? 'In your Backpack'
                            : 'Preview only — not yet owned',
                    key: const ValueKey('nimzo-preview-ownership-status'),
                    style: const TextStyle(color: Color(0xff667b70)),
                  ),
                  const SizedBox(height: 16),
                  if (animatedMedia || item.id.startsWith('nimzo-original-'))
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const ValueKey('nimzo-preview-replay'),
                        onPressed: animatedMedia ||
                                item.id.startsWith('nimzo-original-')
                            ? () {
                                setState(() => replay++);
                                if (MediaQuery.disableAnimationsOf(context)) {
                                  controller.value = 1;
                                } else {
                                  controller.forward(from: 0);
                                }
                              }
                            : null,
                        icon: Icon(
                          animatedMedia
                              ? Icons.replay_rounded
                              : Icons.image_outlined,
                        ),
                        label: Text(
                          animatedMedia
                              ? 'Replay animation'
                              : media != null
                                  ? 'Static artwork'
                                  : 'Replay artwork transition',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xff155a3f),
                          foregroundColor: const Color(0xffffffff),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    media != null
                        ? '${animatedMedia ? 'Animated media' : 'Static artwork'} · No coins charged. Badges are decorative cosmetics.'
                        : item.id.startsWith('nimzo-original-')
                            ? 'Original NIMZO design · Artwork transition only. No coins charged.'
                            : 'Item media unavailable · No coins charged.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xff667b70),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
