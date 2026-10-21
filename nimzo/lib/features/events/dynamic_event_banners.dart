import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/supabase_provider.dart';

/// Only server-active campaigns with a valid time range are displayed.
/// Media paths resolve against the existing public "banners" Storage bucket.
class NimzoEventBanner {
  const NimzoEventBanner({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.subtitle,
    this.target,
  });

  final String id;
  final String title;
  final String imageUrl;
  final String? subtitle;
  final String? target;

  static bool safePublicUrl(String? url) {
    final uri = Uri.tryParse(url ?? '');
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty;
  }

  static NimzoEventBanner? fromRow(
    Map<String, dynamic> row, {
    required String Function(String path) resolveStorage,
    required DateTime now,
  }) {
    if (row['active'] != true) return null;
    final start = DateTime.tryParse(row['start_at']?.toString() ?? '');
    final end = DateTime.tryParse(row['end_at']?.toString() ?? '');
    if (start != null && now.isBefore(start)) return null;
    if (end != null && !now.isBefore(end)) return null;

    final title = (row['title'] as String? ?? '').trim();
    final path = (row['image_path'] as String? ?? '').trim();
    if (title.isEmpty || path.isEmpty) return null;
    final url = path.startsWith('https://')
        ? path
        : (!path.contains('..') && !path.startsWith('/') &&
                !path.contains('://') && !path.contains('\\')
            ? resolveStorage(path)
            : '');
    if (!safePublicUrl(url)) return null;
    return NimzoEventBanner(
      id: row['id'].toString(),
      title: title,
      imageUrl: url,
      subtitle: row['subtitle'] as String?,
      target: row['target'] as String?,
    );
  }
}

/// Screens receive content-revision updates immediately. A periodic refresh
/// also handles campaigns expiring/starting without a database write.
final nimzoEventBannersProvider = FutureProvider.autoDispose<
    List<NimzoEventBanner>>((ref) async {
  final session = ref.watch(sessionSupabaseProvider);
  if (session.userId == null) return const [];
  final timer = Timer(const Duration(minutes: 1), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  final records = await session.client
      .from('banners')
      .select('id,title,subtitle,image_path,target,start_at,end_at,sort_order,active')
      .eq('active', true)
      .order('sort_order')
      .limit(50);
  final now = DateTime.now().toUtc();
  return records.map((row) => NimzoEventBanner.fromRow(
    row,
    resolveStorage: (path) =>
        session.client.storage.from('banners').getPublicUrl(path),
    now: now,
  )).whereType<NimzoEventBanner>().toList(growable: false);
});
