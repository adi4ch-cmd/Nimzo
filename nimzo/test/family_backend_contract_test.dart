import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/social/family_repository.dart';

void main() {
  test('family directory model parses real database fields', () {
    final row = {
      'id': 'family-1',
      'owner_id': 'owner-1',
      'name': 'NIMZO Family',
      'description': 'Public community',
      'owner_name': 'Member',
      'owner_avatar_path': 'member/avatar.webp',
      'member_count': 8,
      'is_member': true,
      'created_at': '2026-10-18T00:00:00Z',
    };
    final family = NimzoFamily.fromRow(row);
    expect(family.id, 'family-1');
    expect(family.ownerId, 'owner-1');
    expect(family.name, 'NIMZO Family');
    expect(family.memberCount, 8);
    expect(family.isMember, isTrue);
    expect(family.ownerAvatarPath, 'member/avatar.webp');
    expect(family.createdAt.isUtc, isTrue);
  });

  test('Family backend uses RLS directory and server-only coin charge', () async {
    final repo = await File(
      'lib/features/social/family_repository.dart',
    ).readAsString();
    final screen = await File(
      'lib/features/social/family_screen.dart',
    ).readAsString();
    final sql = await File(
      '../supabase/migrations/20261018080000_family_founder_membership.sql',
    ).readAsString();
    final directorySql = await File(
      '../supabase/migrations/20261018080500_family_directory_rls.sql',
    ).readAsString();
    expect(repo, contains("from('nimzo_family_directory')"));
    expect(repo, contains("'create_family'"));
    expect(repo, contains("'p_key': requestKey"));
    expect(repo, contains("from('nimzo_family_members')"));
    expect(repo, isNot(contains("from('wallets')")));
    expect(repo, isNot(contains("from('ledger')")));
    expect(screen, contains('Confirm · 1,000,000 coins'));
    expect(screen, contains('_pendingSignature'));
    expect(screen, contains("NimzoArt.family"));
    expect(sql, contains('after insert on public.nimzo_families'));
    expect(sql, contains('on conflict (family_id, user_id) do nothing'));
    expect(directorySql, contains('security_invoker = true'));
    expect(directorySql, contains('grant select on public.nimzo_family_directory to authenticated'));
  });
}
