import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/storage_service.dart';

import '../data/room_settings_repository.dart';
import 'room_controller.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/widgets/reference_widgets.dart';
import '../domain/room_theme.dart';
import 'room_themes_screen.dart';

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

  RoomSettings _copy(RoomSettings s, {
    String? theme,
    bool? isPrivate,
    bool? mic,
    bool? chat,
    bool? guest,
    bool? gift,
    bool? music,
    bool? game,
    bool? visitor,
  }) => RoomSettings(
    name: s.name,
    theme: theme ?? s.theme,
    avatarPath: s.avatarPath,
    isPrivate: isPrivate ?? s.isPrivate,
    mic: mic ?? s.mic,
    chat: chat ?? s.chat,
    guest: guest ?? s.guest,
    gift: gift ?? s.gift,
    music: music ?? s.music,
    game: game ?? s.game,
    visitor: visitor ?? s.visitor,
  );

  void _switchSetting(String key, bool value) {
    final s = settings!;
    setState(() {
      settings = _copy(s,
        isPrivate: key == 'private' ? value : null,
        mic: key == 'mic' ? value : null,
        chat: key == 'chat' ? value : null,
        guest: key == 'guest' ? value : null,
        gift: key == 'gift' ? value : null,
        music: key == 'music' ? value : null,
        game: key == 'game' ? value : null,
        visitor: key == 'visitor' ? value : null,
      );
    });
  }

  Widget _panel(Widget child) => Padding(
    padding: const EdgeInsets.only(bottom: 15),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(21),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        child: child,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final owner = ref.watch(roomProvider(widget.roomId)).valueOrNull?.ownerId ==
        ref.watch(currentUserIdProvider);
    return Scaffold(
      backgroundColor: const Color(0xffe9f3ef),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Room Setting',
          style: TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: true,
      ),
      body: AsyncContent(
        value: ref.watch(roomSettingsProvider(widget.roomId)),
        onRetry: () => ref.invalidate(roomSettingsProvider(widget.roomId)),
        builder: (s) {
          settings ??= s;
          if (name.text.isEmpty) name.text = s.name;
          final current = settings!;
          final artworkPath = artwork ?? s.avatarPath;
          final artworkUrl = artworkPath == null ? null : ref
              .read(supabaseProvider)
              .storage
              .from('room-images')
              .getPublicUrl(artworkPath);
          final palette = RoomTheme.byId(current.theme);
          final permissions = <(String, String, bool)>[
            ('mic', 'Permission to take a guest mic', current.mic),
            ('chat', 'Allow room chat', current.chat),
            ('guest', 'Allow guests', current.guest),
            ('gift', 'Gift effects', current.gift),
            ('music', 'Music', current.music),
            ('game', 'Games', current.game),
            ('visitor', 'Visitors', current.visitor),
            ('private', 'Only room members can enter', current.isPrivate),
          ];
          return ListView(
            key: const ValueKey('premium-room-edit'),
            padding: const EdgeInsets.fromLTRB(15, 18, 15, 28),
            children: [
              _panel(Column(
                children: [
                  ListTile(
                    key: const ValueKey('room-edit-avatar'),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 10, horizontal: 1),
                    title: const Text('Room Avatar',
                      style: TextStyle(fontSize: 17,
                        fontWeight: FontWeight.w800)),
                    subtitle: const Text('Choose from gallery or camera'),
                    trailing: Row(mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(radius: 35,
                          backgroundColor: const Color(0xffd5eade),
                          backgroundImage: artworkUrl == null
                              ? null : NetworkImage(artworkUrl),
                          child: artworkUrl == null
                              ? const Icon(Icons.meeting_room_rounded,
                                color: Color(0xff166a53), size: 30) : null,
                        ),
                        const SizedBox(width: 5),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: !owner || busy ? null : () async {
                      final source = await showModalBottomSheet<ImageSource>(
                        context: context,
                        builder: (c) => SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: const Icon(Icons.photo_library_outlined),
                                title: const Text('Gallery'),
                                onTap: () => Navigator.pop(
                                  c, ImageSource.gallery)),
                              ListTile(
                                leading: const Icon(Icons.photo_camera_outlined),
                                title: const Text('Camera'),
                                onTap: () => Navigator.pop(
                                  c, ImageSource.camera)),
                            ],
                          ),
                        ),
                      );
                      if (source != null) await upload(source);
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    key: const ValueKey('room-edit-theme'),
                    title: const Text('Room Theme',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(palette.label),
                    trailing: Row(mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 54, height: 37,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: palette.gradient),
                            borderRadius: BorderRadius.circular(8)),
                        ),
                        const SizedBox(width: 5),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: !owner || busy ? null : () async {
                      final selection = await Navigator.of(context).push<String>(
                        MaterialPageRoute(builder: (_) =>
                            RoomThemesScreen(currentTheme: current.theme)));
                      if (selection != null && mounted) setState(() {
                        settings = _copy(settings!, theme: selection);
                      });
                    },
                  ),
                  const Divider(height: 1),
                  TextField(
                    key: const ValueKey('room-edit-name'),
                    controller: name,
                    enabled: owner && !busy,
                    maxLength: 40,
                    decoration: const InputDecoration(
                      labelText: 'Room Name',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.fromLTRB(8, 10, 8, 4),
                    ),
                  ),
                ],
              )),
              _panel(Column(
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.only(top: 9, bottom: 5),
                      child: Text('Room Permissions',
                        style: TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 16)),
                    ),
                  ),
                  for (final entry in permissions) ...[
                    SwitchListTile(
                      key: ValueKey('room-permission-${entry.$1}'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: const Color(0xff13b88a),
                      title: Text(entry.$2,
                        style: const TextStyle(fontSize: 13,
                          fontWeight: FontWeight.w600)),
                      value: entry.$3,
                      onChanged: !owner || busy ? null
                          : (v) => _switchSetting(entry.$1, v),
                    ),
                    if (entry != permissions.last)
                      const Divider(height: 1),
                  ],
                  TextField(
                    controller: password,
                    enabled: owner && !busy,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Room password',
                      border: OutlineInputBorder(),
                      helperText: 'Leave empty to keep current password',
                    ),
                  ),
                ],
              )),
              _panel(const ListTile(
                leading: Icon(Icons.mic_rounded, color: Color(0xff16a880)),
                title: Text('Mic Seats'),
                trailing: Text('10',
                  style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('Five upper and five lower seats'),
              )),
              FilledButton(
                key: const ValueKey('room-save-button'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xff14b88a),
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: !owner || busy ? null : () async {
                  setState(() => busy = true);
                  try {
                    final x = settings!;
                    await ref.read(roomSettingsRepositoryProvider).save(
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
                      password: password.text.isEmpty ? null : password.text,
                    );
                    ref.invalidate(roomProvider(widget.roomId));
                    ref.invalidate(roomSettingsProvider(widget.roomId));
                    if (context.mounted) Navigator.pop(context);
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text(
                            'Room settings could not be saved.')));
                    }
                  } finally {
                    if (mounted) setState(() => busy = false);
                  }
                },
                child: Text(busy ? 'Saving…' : 'Save Room'),
              ),
            ],
          );
        },
      ),
    );
  }
}
