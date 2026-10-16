import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers/supabase_provider.dart';
import '../../core/widgets/reference_widgets.dart';
import 'profile_repository.dart';
import 'profile_image_format.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  final bool edit;
  const ProfileSetupScreen({super.key, this.edit = false});
  @override
  ConsumerState<ProfileSetupScreen> createState() => _State();
}

class _State extends ConsumerState<ProfileSetupScreen> {
  final name = TextEditingController(),
      bio = TextEditingController(),
      language = TextEditingController();
  final form = GlobalKey<FormState>();
  String? gender, countryCode, countryName, avatar, cover, existingAvatar;
  DateTime? dob;
  bool loaded = false, busy = false;
  String? failure;
  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  Future<void> load() async {
    try {
      final id = ref.read(currentUserIdProvider);
      if (id == null) return;
      final p = await ref.read(profileProvider(id).future);
      if (!mounted) return;
      name.text = p.displayName ?? '';
      bio.text = p.bio ?? '';
      language.text = p.language ?? '';
      setState(() {
        existingAvatar = p.avatarPath;
        gender = p.gender;
        dob = p.dateOfBirth;
        countryCode = p.countryCode;
        countryName = p.countryName;
        loaded = true;
        failure = null;
      });
    } catch (_) {
      if (mounted) setState(() => failure = 'Unable to load your profile.');
    }
  }

  @override
  void dispose() {
    name.dispose();
    bio.dispose();
    language.dispose();
    super.dispose();
  }

  Future<void> photo(bool isCover) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(c, ImageSource.gallery),
            ),
            ListTile(
              title: const Text('Camera'),
              onTap: () => Navigator.pop(c, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    setState(() => busy = true);
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024)
        throw const FormatException('Photo must be under 5 MB.');
      final format = profileImageFormat(bytes),
          db = ref.read(supabaseProvider),
          id = ref.read(currentUserIdProvider);
      if (id == null) throw StateError('Sign in required');
      final path = '$id/${DateTime.now().microsecondsSinceEpoch}.${format.$1}';
      await db.storage.from(isCover ? 'covers' : 'avatars').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: format.$2),
          );
      if (mounted)
        setState(() {
          if (isCover) {
            cover = path;
          } else {
            avatar = path;
          }
        });
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Photo could not be uploaded. Choose JPEG, PNG or WebP under 5 MB and retry.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    if (!form.currentState!.validate() ||
        gender == null ||
        countryCode == null ||
        dob == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete name, gender, birth date and country.'),
        ),
      );
      return;
    }
    setState(() => busy = true);
    try {
      await ref.read(profileRepositoryProvider).update(
            displayName: name.text,
            bio: bio.text,
            countryCode: countryCode,
            countryName: countryName,
            gender: gender,
            dateOfBirth: dob,
            language: language.text,
            avatarPath: avatar,
            coverPath: cover,
          );
      final id = ref.read(currentUserIdProvider);
      if (id != null) ref.invalidate(profileProvider(id));
      if (mounted) {
        widget.edit ? Navigator.pop(context) : context.go('/home');
      }
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile could not be saved. Please retry.'),
          ),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  static const _pageColor = NimzoStyle.surface;

  Widget _section(Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(23),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: child,
          ),
        ),
      );

  Widget _line() => const Divider(height: 1, color: NimzoStyle.line);

  InputDecoration _fieldDecoration(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: NimzoStyle.ink, fontWeight: FontWeight.w700,
        ),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 13),
        counterText: '',
      );

  @override
  Widget build(BuildContext context) {
    final id = ref.watch(currentUserIdProvider);
    final storedAvatar = avatar ?? existingAvatar;
    final avatarUrl = storedAvatar == null
        ? null
        : ref.read(supabaseProvider).storage.from('avatars')
            .getPublicUrl(storedAvatar);
    return Scaffold(
      backgroundColor: _pageColor,
      appBar: AppBar(
        title: Text(widget.edit ? 'Modify Profile' : 'Set up your profile',
          style: const TextStyle(
            fontSize: 20, fontWeight: FontWeight.w800,
          )),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: NimzoStyle.ink,
      ),
      body: failure != null
          ? DataFailure(message: failure!, onRetry: load)
          : !loaded
              ? const Center(child: CircularProgressIndicator())
              : Form(
                  key: form,
                  child: ListView(
                    key: const ValueKey('modify-profile-clean-list'),
                    padding: const EdgeInsets.fromLTRB(16, 22, 16, 36),
                    children: [
                      _section(Column(
                        children: [
                          ListTile(
                            key: const ValueKey('modify-avatar'),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 2),
                            title: const Text('Avatar',
                              style: TextStyle(fontSize: 17,
                                fontWeight: FontWeight.w800)),
                            trailing: Row(mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 38,
                                  backgroundColor: const Color(0xffede4ff),
                                  backgroundImage: avatarUrl == null
                                      ? null : NetworkImage(avatarUrl),
                                  child: avatarUrl == null
                                      ? const Icon(Icons.person,
                                        color: NimzoStyle.primary, size: 32)
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                const Icon(Icons.chevron_right,
                                  color: NimzoStyle.muted),
                              ],
                            ),
                            onTap: busy ? null : () => photo(false),
                          ),
                          _line(),
                          ListTile(
                            title: const Text('Cover photo',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: busy ? null : () => photo(true),
                            subtitle: cover == null
                                ? null : const Text('New cover selected'),
                          ),
                        ],
                      )),
                      _section(Column(
                        children: [
                          TextFormField(
                            key: const ValueKey('modify-nickname'),
                            controller: name,
                            maxLength: 30,
                            decoration: _fieldDecoration('Nickname'),
                            validator: (s) => (s?.trim().length ?? 0) >= 2
                                ? null : 'Name is too short',
                          ),
                          _line(),
                          DropdownButtonFormField<String>(
                            key: const ValueKey('modify-gender'),
                            initialValue:
                                ['Male', 'Female', 'Other'].contains(gender)
                                    ? gender : null,
                            decoration: _fieldDecoration('Gender'),
                            items: [
                              for (final g in ['Male', 'Female', 'Other'])
                                DropdownMenuItem(value: g, child: Text(g)),
                            ],
                            onChanged: (v) => setState(() => gender = v),
                          ),
                          _line(),
                          ListTile(
                            key: const ValueKey('modify-birthday'),
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Birthday',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                            trailing: Text(
                              dob?.toIso8601String().split('T').first
                                  ?? 'Choose date',
                              style: const TextStyle(color: NimzoStyle.muted),
                            ),
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                firstDate: DateTime(1900),
                                lastDate: DateTime.now(),
                                initialDate: dob ?? DateTime(2000),
                              );
                              if (date != null) setState(() => dob = date);
                            },
                          ),
                          _line(),
                          ListTile(
                            key: const ValueKey('modify-country'),
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Country',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                            trailing: SizedBox(width: 125, child: Text(
                              countryName ?? 'Choose country',
                              textAlign: TextAlign.end,
                              maxLines: 1, overflow: TextOverflow.ellipsis)),
                            onTap: () => showCountryPicker(
                              context: context,
                              onSelect: (c) => setState(() {
                                countryCode = c.countryCode;
                                countryName = c.name;
                              }),
                            ),
                          ),
                          _line(),
                          TextField(
                            controller: language,
                            decoration: _fieldDecoration('Language'),
                          ),
                          _line(),
                          TextFormField(
                            key: const ValueKey('modify-signature'),
                            controller: bio,
                            maxLength: 300,
                            maxLines: 2,
                            decoration:
                                _fieldDecoration('Personalized Signature'),
                          ),
                        ],
                      )),
                      const SizedBox(height: 8),
                      FilledButton(
                        key: const ValueKey('modify-profile-save'),
                        onPressed: busy || id == null ? null : save,
                        style: FilledButton.styleFrom(
                          backgroundColor: NimzoStyle.primary,
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(busy ? 'Saving…' : 'Save'),
                      ),
                    ],
                  ),
                ),
    );
  }
}
