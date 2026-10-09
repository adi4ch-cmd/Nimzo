import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/storage_service.dart';

import '../data/room_settings_repository.dart';
import 'room_controller.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/widgets/reference_widgets.dart';
import '../../../core/theme/app_theme.dart';

class RoomSettingsScreen extends ConsumerStatefulWidget {
  final String roomId;
  final bool isOwner;
  const RoomSettingsScreen({
    super.key,
    required this.roomId,
    this.isOwner = false,
  });
  @override
  ConsumerState<RoomSettingsScreen> createState() => _State();
}

class _State extends ConsumerState<RoomSettingsScreen> {
  final name = TextEditingController(), password = TextEditingController();
  RoomSettings? settings;
  bool busy = false;
  String? artwork;
  Future<void> upload(ImageSource source) async {
    setState(() => busy = true);
    try {
      final path = await ref
          .read(storageServiceProvider)
          .pickAndUpload('room-images', source: source, roomId: widget.roomId);
      if (mounted && path != null) setState(() => artwork = path);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Room photo could not be uploaded.')),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    name.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final owner =
        ref.watch(roomProvider(widget.roomId)).valueOrNull?.ownerId ==
        ref.watch(currentUserIdProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Room Setting')),
      body: AsyncContent(
        value: ref.watch(roomSettingsProvider(widget.roomId)),
        onRetry: () => ref.invalidate(roomSettingsProvider(widget.roomId)),
        builder: (s) {
          settings ??= s;
          if (name.text.isEmpty) name.text = s.name;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: !owner || busy
                        ? null
                        : () => upload(ImageSource.gallery),
                    child: const Text('Choose room photo'),
                  ),
                  OutlinedButton(
                    onPressed: !owner || busy
                        ? null
                        : () => upload(ImageSource.camera),
                    child: const Text('Camera'),
                  ),
                ],
              ),
              if (artwork != null)
                const Text('New room photo selected. Save to apply.'),
              TextField(
                controller: name,
                enabled: owner,
                maxLength: 40,
                decoration: const InputDecoration(labelText: 'Room name'),
              ),
              for (final entry in {
                'mic': settings!.mic,
                'chat': settings!.chat,
                'guest': settings!.guest,
                'gift': settings!.gift,
                'music': settings!.music,
                'game': settings!.game,
                'visitor': settings!.visitor,
                'private': settings!.isPrivate,
              }.entries)
                SwitchListTile(
                  title: Text(
                    {
                      'mic': 'Permission to take the mic of guest',
                      'chat': 'Send emojis to the chatting area',
                      'guest': 'Allow guests',
                      'gift': 'Gift Effect',
                      'music': 'Music',
                      'game': 'Games',
                      'visitor': 'Visitors',
                      'private': 'Only room members can enter',
                    }[entry.key]!,
                  ),
                  value: entry.value,
                  onChanged: !owner || busy
                      ? null
                      : (v) => setState(() {
                          final x = settings!;
                          settings = RoomSettings(
                            name: x.name,
                            theme: x.theme,
                            avatarPath: x.avatarPath,
                            isPrivate: entry.key == 'private' ? v : x.isPrivate,
                            mic: entry.key == 'mic' ? v : x.mic,
                            chat: entry.key == 'chat' ? v : x.chat,
                            guest: entry.key == 'guest' ? v : x.guest,
                            gift: entry.key == 'gift' ? v : x.gift,
                            music: entry.key == 'music' ? v : x.music,
                            game: entry.key == 'game' ? v : x.game,
                            visitor: entry.key == 'visitor' ? v : x.visitor,
                          );
                        }),
                ),
              TextField(
                controller: password,
                enabled: owner,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Room password'),
              ),
              for (final row in [
                ('Number of Mic', '10'),
                ('Dice Count', '3 ›'),
                ('Membership Fee', 'Unavailable'),
                ('Live Mode', 'Off ›'),
                ('Live record', '›'),
                ('Guest send text level', 'Unavailable'),
                ('Blocked List', '›'),
                ('Action record', '›'),
                ('Room Rewards', 'Unavailable'),
                ('Room Support', '›'),
                ('Apply for Banner', '›'),
              ])
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: NimzoStyle.line)),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Text(row.$1)),
                      Text(
                        row.$2,
                        style: const TextStyle(color: NimzoStyle.muted),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: !owner || busy
                    ? null
                    : () async {
                        setState(() => busy = true);
                        try {
                          final x = settings!;
                          await ref
                              .read(roomSettingsRepositoryProvider)
                              .save(
                                widget.roomId,
                                RoomSettings(
                                  name: name.text,
                                  theme: x.theme,
                                  avatarPath: artwork ?? x.avatarPath,
                                  isPrivate: x.isPrivate,
                                  mic: x.mic,
                                  chat: x.chat,
                                  guest: x.guest,
                                  gift: x.gift,
                                  music: x.music,
                                  game: x.game,
                                  visitor: x.visitor,
                                ),
                                password: password.text.isEmpty
                                    ? null
                                    : password.text,
                              );
                          ref.invalidate(roomProvider(widget.roomId));
                          ref.invalidate(roomSettingsProvider(widget.roomId));
                          if (context.mounted) Navigator.pop(context);
                        } catch (_) {
                          if (context.mounted)
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Room settings could not be saved.',
                                ),
                              ),
                            );
                        } finally {
                          if (mounted) setState(() => busy = false);
                        }
                      },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }
}
