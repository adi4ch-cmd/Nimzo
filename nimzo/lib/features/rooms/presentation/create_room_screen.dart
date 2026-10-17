import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../profile/profile_image_format.dart';
import '../../profile/profile_repository.dart';
import 'room_controller.dart';

/// Tingle-reference room creator using the existing Supabase room contract.
/// All selections are either saved to the backend or return a visible error.
class CreateRoomScreen extends ConsumerStatefulWidget {
  const CreateRoomScreen({super.key});
  @override
  ConsumerState<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends ConsumerState<CreateRoomScreen> {
  final name = TextEditingController();
  final description = TextEditingController();
  final password = TextEditingController();
  XFile? image;
  Uint8List? imageBytes;
  bool isPrivate = false;
  bool busy = false;

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    password.dispose();
    super.dispose();
  }

  void notice(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  Future<void> chooseImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text('Select Room Photo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            ListTile(
              key: const ValueKey('room-photo-camera'),
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              key: const ValueKey('room-photo-gallery'),
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
            TextButton(
              key: const ValueKey('room-photo-cancel'),
              onPressed: () => Navigator.of(sheetContext).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || source == null) return;
    try {
      final selected = await ImagePicker().pickImage(
        source: source, imageQuality: 85, maxWidth: 1440,
      );
      if (selected == null) return;
      final bytes = await selected.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        throw const FormatException('Room photo must be under 5 MB.');
      }
      profileImageFormat(bytes);
      if (mounted) setState(() {
        image = selected;
        imageBytes = bytes;
      });
    } catch (_) {
      if (mounted) notice('Choose a JPEG, PNG or WebP picture under 5 MB.');
    }
  }

  Future<void> create() async {
    if (busy) return;
    if (name.text.trim().isEmpty || name.text.trim().length > 40) {
      notice('Enter a room name of up to 40 characters.');
      return;
    }
    if (isPrivate && password.text.trim().length < 4) {
      notice('Private room password must be at least four characters.');
      return;
    }
    setState(() => busy = true);
    try {
      // Store the signed-in profile country with the permanent room so
      // country-filtered discovery works for newly created audio rooms.
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) throw StateError('Sign in required');
      final owner = await ref.read(profileProvider(userId).future);
      final code = owner.countryCode?.trim();
      final name = owner.countryName?.trim();
      final roomCountry = code != null && code.isNotEmpty
          ? code
          : name != null && name.isNotEmpty ? name : null;
      final id = await ref.read(roomRepositoryProvider).create(
        name.text.trim(),
        country: roomCountry,
        password: isPrivate ? password.text.trim() : null,
      );
      String? metadataError;
      final db = ref.read(sessionSupabaseProvider).client;
      final uid = db.auth.currentUser?.id;
      if (uid != null && (imageBytes != null || description.text.trim().isNotEmpty)) {
        try {
          final changes = <String, dynamic>{};
          final rules = description.text.trim();
          if (rules.isNotEmpty) changes['rules'] = rules;
          if (imageBytes != null) {
            final format = profileImageFormat(imageBytes!);
            final path = '${id}/${DateTime.now().microsecondsSinceEpoch}.${format.$1}';
            await db.storage.from('room-images').uploadBinary(
              path, imageBytes!,
              fileOptions: FileOptions(
                contentType: format.$2, upsert: false,
              ),
            );
            changes['avatar_path'] = path;
          }
          final changed = await db.from('rooms').update(changes)
            .eq('id', id).eq('owner_id', uid).select('id').maybeSingle();
          if (changed == null) {
            throw StateError('Room settings were not saved.');
          }
        } catch (_) {
          metadataError = 'Room created, but photo or description was not saved. '
            'You can retry from room settings.';
        }
      }
      if (mounted && metadataError != null) notice(metadataError);
      ref.invalidate(myRoomsProvider);
      ref.invalidate(popularRoomsProvider(null));
      if (mounted) context.go('/room/' + id);
    } catch (e) {
      if (mounted) notice('Room could not be saved: ' + e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [
            Color(0xff008bff), Color(0xff448afa),
            Color(0xffba5af8), Color(0xff1500d3),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(children: [
          Row(children: [
            IconButton(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            ),
            const Expanded(child: Text(
              'Create Audio Room', textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 19,
                fontWeight: FontWeight.w700),
            )),
            const SizedBox(width: 48),
          ]),
          Expanded(child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            children: [
              const _Label('Select Room Image'),
              const SizedBox(height: 14),
              Align(alignment: Alignment.centerLeft, child: InkWell(
                onTap: chooseImage,
                child: Container(
                  height: 162, width: 155,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .10),
                    border: Border.all(color: Colors.white38),
                    borderRadius: BorderRadius.circular(23),
                  ),
                  child: imageBytes == null
                    ? const Icon(Icons.add_photo_alternate_outlined,
                        color: Colors.white, size: 53)
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(21),
                        child: Image.memory(imageBytes!, width: 155,
                          height: 162, fit: BoxFit.cover),
                      ),
                ),
              )),
              const SizedBox(height: 28),
              const _Label('Room Name'),
              const SizedBox(height: 12),
              _Input(controller: name, hint: 'Enter your room name...'),
              const SizedBox(height: 19),
              const _Label('Room Description'),
              const SizedBox(height: 12),
              _Input(controller: description,
                hint: 'Type Comment...', maxLines: 4),
              const SizedBox(height: 25),
              const _Label('Room Type'),
              const SizedBox(height: 12),
              Row(children: [
                _Type(text: 'Public', icon: Icons.lock_open,
                  selected: !isPrivate,
                  onTap: () => setState(() => isPrivate = false)),
                const SizedBox(width: 15),
                _Type(text: 'Private', icon: Icons.lock_outline,
                  selected: isPrivate,
                  onTap: () => setState(() => isPrivate = true)),
              ]),
              if (isPrivate) ...[
                const SizedBox(height: 14),
                _Input(controller: password, hint: 'Room password'),
              ],
            ],
          )),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 46, vertical: 10),
            child: SizedBox(width: double.infinity, height: 64,
              child: FilledButton(
                onPressed: busy ? null : create,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xffff527f),
                  shape: const StadiumBorder(),
                ),
                child: Text(busy ? 'Opening...' : 'Go Live',
                  style: const TextStyle(fontSize: 22, color: Colors.white)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 0, 15, 22),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (final text in const [
                  'Normal Live', 'Multi Live', 'Audio Room'
                ]) TextButton(
                  onPressed: text == 'Audio Room' ? null : () =>
                    notice('NIMZO supports audio-only rooms.'),
                  child: Text(text, style: TextStyle(
                    color: Colors.white.withValues(alpha:
                      text == 'Audio Room' ? 1 : .7),
                    fontWeight: text == 'Audio Room'
                      ? FontWeight.w700 : FontWeight.w400,
                  )),
                ),
              ],
            ),
          ),
        ]),
      ),
    ),
  );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
    style: const TextStyle(color: Color(0xffcfcbff),
      fontSize: 17, fontWeight: FontWeight.w600));
}
class _Input extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  const _Input({required this.controller, required this.hint,
    this.maxLines = 1});
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller, maxLines: maxLines,
    maxLength: maxLines > 1 ? 500 : 40,
    style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xffe9dfff)),
      counterStyle: const TextStyle(color: Colors.white70),
      fillColor: Colors.white.withValues(alpha: .12),
      filled: true,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(color: Colors.white38)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(color: Colors.white)),
    ),
  );
}
class _Type extends StatelessWidget {
  final String text;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _Type({required this.text, required this.icon,
    required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap, icon: Icon(icon), label: Text(text),
    style: OutlinedButton.styleFrom(
      foregroundColor: selected ? NimzoStyle.primary : Colors.white,
      backgroundColor: selected ? Colors.white : Colors.white12,
      side: const BorderSide(color: Colors.white38),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13)),
    ),
  );
}
