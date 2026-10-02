import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/nimzo_button.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/utils/helpers.dart';
import '../data/room_settings_repository.dart';
import '../domain/room_theme.dart';
import 'room_controller.dart';

/// Owners edit settings; everyone can view rules. Every write is re-checked in Postgres.
class RoomSettingsScreen extends ConsumerStatefulWidget {
  final String roomId;
  final bool isOwner;
  const RoomSettingsScreen({super.key, required this.roomId, required this.isOwner});
  @override
  ConsumerState<RoomSettingsScreen> createState() => _S();
}

class _S extends ConsumerState<RoomSettingsScreen> {
  RoomSettings? s;
  final _pw = TextEditingController();
  bool busy = false;
  @override
  void dispose() { _pw.dispose(); super.dispose(); }

  RoomSettings _copy(RoomSettings o, {String? theme, String? avatarPath, bool? isPrivate, bool? mic, bool? chat, bool? guest, bool? gift, bool? music, bool? game, bool? visitor}) =>
      RoomSettings(name: o.name, theme: theme ?? o.theme, avatarPath: avatarPath ?? o.avatarPath, isPrivate: isPrivate ?? o.isPrivate, mic: mic ?? o.mic, chat: chat ?? o.chat,
          guest: guest ?? o.guest, gift: gift ?? o.gift, music: music ?? o.music, game: game ?? o.game, visitor: visitor ?? o.visitor);

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(roomSettingsProvider(widget.roomId));\n    final db = ref.watch(supabaseProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Room settings')),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(roomSettingsProvider(widget.roomId))),
        data: (loaded) {
          final cur = s ?? loaded;
          final on = widget.isOwner;
          Widget sw(String t, bool v, void Function(bool) f) => SwitchListTile(title: Text(t), value: v, onChanged: on ? (x) => setState(() => f(x)) : null);
          final imageUrl = cur.avatarPath == null ? null : storageUrl(db, 'room-images', cur.avatarPath!);\n          return ListView(padding: const EdgeInsets.all(16), children: [\n            Card(clipBehavior: Clip.antiAlias, child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [\n              Container(width: 76, height: 76, clipBehavior: Clip.antiAlias, decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: Theme.of(context).colorScheme.surfaceContainerHighest), child: imageUrl == null ? const Icon(Icons.meeting_room_outlined, size: 32) : Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined))),\n              const SizedBox(width: 14),\n              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [\n                Text('Room picture', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),\n                const SizedBox(height: 4),\n                const Text('Choose a professional room picture from your phone.'),\n                const SizedBox(height: 8),\n                OutlinedButton.icon(onPressed: on ? _pickRoomImage : null, icon: const Icon(Icons.photo_library_outlined), label: const Text('Choose from phone')),\n              ])),\n            ]))),\n            const SizedBox(height: 12),
            Text('Theme', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final t in RoomTheme.all)
                ChoiceChip(label: Text(t.label), selected: cur.theme == t.id, onSelected: on ? (_) => setState(() => s = _copy(cur, theme: t.id)) : null),
            ]),
            const Divider(height: 32),
            sw('Private room', cur.isPrivate, (v) => s = _copy(cur, isPrivate: v)),
            if (cur.isPrivate && on) TextField(controller: _pw, obscureText: true, decoration: const InputDecoration(labelText: 'Password (leave empty to keep)')),
            sw('Allow mic', cur.mic, (v) => s = _copy(cur, mic: v)),
            sw('Allow chat', cur.chat, (v) => s = _copy(cur, chat: v)),
            sw('Allow guests', cur.guest, (v) => s = _copy(cur, guest: v)),
            sw('Allow gifts', cur.gift, (v) => s = _copy(cur, gift: v)),
            sw('Allow music', cur.music, (v) => s = _copy(cur, music: v)),
            sw('Allow games', cur.game, (v) => s = _copy(cur, game: v)),
            sw('Allow visitors', cur.visitor, (v) => s = _copy(cur, visitor: v)),
            const SizedBox(height: 12),
            if (on) NimzoButton(label: 'Save', loading: busy, onPressed: () async {
              setState(() => busy = true);
              try {
                await ref.read(roomSettingsRepositoryProvider).save(widget.roomId, cur, password: _pw.text.isEmpty ? null : _pw.text);
                ref.invalidate(roomProvider(widget.roomId));
                ref.invalidate(roomSettingsProvider(widget.roomId));
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
              } finally { if (mounted) setState(() => busy = false); }
            }),
            const Divider(height: 32),
            ListTile(leading: const Icon(Icons.group_outlined), title: const Text('Members & moderation'),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RoomMembersScreen(roomId: widget.roomId)))),
            const ListTile(leading: Icon(Icons.rule_outlined), title: Text('Room rules'), subtitle: Text('Be respectful. No harassment, hate or spam. Owners and moderators may mute, remove or ban.')),
          ]);
        },
      ),
    );
  }
}

class RoomMembersScreen extends ConsumerWidget {
  final String roomId;
  const RoomMembersScreen({super.key, required this.roomId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void snack(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
    final repo = ref.read(roomSettingsRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Members')),
      body: ref.watch(roomMembersProvider(roomId)).when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(roomMembersProvider(roomId))),
        data: (l) => ListView(children: [
          for (final m in l) ListTile(
            title: Text(m['display_name'] ?? 'User'), subtitle: Text(m['role']),
            trailing: PopupMenuButton<String>(
              onSelected: (v) async {
                try {
                  if (v == 'mod') await repo.setModerator(roomId, m['user_id'], m['role'] != 'moderator');
                  if (v == 'kick') await ref.read(roomRepositoryProvider).kick(roomId, m['user_id']);
                  ref.invalidate(roomMembersProvider(roomId));
                } catch (e) { snack('$e'); }
              },
              itemBuilder: (_) => const [PopupMenuItem(value: 'mod', child: Text('Toggle moderator')), PopupMenuItem(value: 'kick', child: Text('Kick & block'))],
            ),
          ),
        ]),
      ),
    );
  }
}
