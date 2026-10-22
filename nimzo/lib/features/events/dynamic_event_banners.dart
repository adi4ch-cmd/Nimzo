import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../core/providers/supabase_provider.dart';
import '../../core/services/approved_media_bytes.dart';
import '../../core/services/published_catalog_image.dart';

/// Only server-active campaigns with a valid time range are displayed.
/// Media paths resolve against the existing public "banners" Storage bucket.
class NimzoEventBanner {
  const NimzoEventBanner({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.subtitle,
    this.target,
    this.publication,
  });

  final String id;
  final String title;
  final String imageUrl;
  final String? subtitle;
  final String? target;
  final ApprovedMediaPublication? publication;

  static bool safePublicUrl(String? url) => ApprovedMediaBytes.isSafeUrl(url);

  static NimzoEventBanner? fromRow(
    Map<String, dynamic> row, {
    required String Function(String path) resolveStorage,
    required DateTime now,
  }) {
    if (row['active'] != true) return null;
    if (row['id'] is! String ||
        row['title'] is! String ||
        row['image_path'] is! String ||
        (row['subtitle'] != null && row['subtitle'] is! String) ||
        (row['target'] != null && row['target'] is! String)) return null;
    final start = DateTime.tryParse(row['start_at']?.toString() ?? '');
    final end = DateTime.tryParse(row['end_at']?.toString() ?? '');
    if ((row['start_at'] != null && start == null) ||
        (row['end_at'] != null && end == null) ||
        (start != null && end != null && !end.isAfter(start))) return null;
    if (start != null && now.isBefore(start)) return null;
    if (end != null && !now.isBefore(end)) return null;

    final title = (row['title'] as String? ?? '').trim();
    final path = (row['image_path'] as String? ?? '').trim();
    if (title.isEmpty || path.isEmpty) return null;
    final url = path.startsWith('https://')
        ? path
        : (!path.contains('..') &&
                !path.contains('%') &&
                !path.contains('?') &&
                !path.contains('#') &&
                !path.startsWith('/') &&
                !path.contains('://') &&
                !path.contains('\\')
            ? resolveStorage(path)
            : '');
    if (!safePublicUrl(url)) return null;
    const publicationFields = [
      'image_sha256',
      'image_byte_size',
      'image_mime_type',
      'image_rights_reference',
      'image_verified_at',
      'image_device_verified_at'
    ];
    PublishedCatalogImage? image;
    if (publicationFields.any((key) => row[key] != null)) {
      image = PublishedCatalogImage.parse({
        'url': url,
        'sha256': row['image_sha256'],
        'byte_size': row['image_byte_size'],
        'mime_type': row['image_mime_type'],
        'rights_reference': row['image_rights_reference'],
        'verified_at': row['image_verified_at'],
        'device_verified_at': row['image_device_verified_at'],
      });
      if (image == null) return null;
    }
    return NimzoEventBanner(
      id: row['id'].toString(),
      title: title,
      imageUrl: url,
      subtitle: row['subtitle'] as String?,
      target: row['target'] as String?,
      publication: image?.publication,
    );
  }
}

/// Screens receive content-revision updates immediately. A periodic refresh
/// also handles campaigns expiring/starting without a database write.
final nimzoEventBannersProvider =
    FutureProvider.autoDispose<List<NimzoEventBanner>>((ref) async {
  final session = ref.watch(sessionSupabaseProvider);
  if (session.userId == null) return const [];
  const legacyFields =
      'id,title,subtitle,image_path,target,start_at,end_at,sort_order,active';
  const imageFields =
      'image_sha256,image_byte_size,image_mime_type,image_rights_reference,image_verified_at,image_device_verified_at';
  Future<List<Map<String, dynamic>>> load(String fields) async =>
      await session.client
          .from('banners')
          .select(fields)
          .eq('active', true)
          .order('sort_order')
          .limit(50);
  List<Map<String, dynamic>> records;
  try {
    records = await load('$legacyFields,$imageFields');
  } on PostgrestException catch (error) {
    // Additive migration may still be staged. Only a missing-column schema
    // response permits the unchanged legacy query; malformed data never does.
    if (error.code != '42703' && error.code != 'PGRST204') rethrow;
    records = await load(legacyFields);
  }
  final now = DateTime.now().toUtc();
  var refreshAfter = const Duration(minutes: 1);
  for (final row in records) {
    for (final key in ['start_at', 'end_at']) {
      final transition = DateTime.tryParse(row[key]?.toString() ?? '');
      if (transition != null && transition.isAfter(now)) {
        final delay = transition.difference(now);
        if (delay < refreshAfter) refreshAfter = delay;
      }
    }
  }
  final timer = Timer(refreshAfter, ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return records
      .map((row) => NimzoEventBanner.fromRow(
            row,
            resolveStorage: (path) =>
                session.client.storage.from('banners').getPublicUrl(path),
            now: now,
          ))
      .whereType<NimzoEventBanner>()
      .toList(growable: false);
});
