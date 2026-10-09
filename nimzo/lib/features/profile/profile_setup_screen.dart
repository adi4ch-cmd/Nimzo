import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
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
  String? gender, countryCode, countryName, avatar, cover;
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
      await db.storage
          .from(isCover ? 'covers' : 'avatars')
          .uploadBinary(
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
      await ref
          .read(profileRepositoryProvider)
          .update(
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.edit ? 'Edit profile' : 'Set up your profile'),
    ),
    body: failure != null
        ? DataFailure(message: failure!, onRetry: load)
        : !loaded
        ? const Center(child: CircularProgressIndicator())
        : Form(
            key: form,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                OutlinedButton(
                  onPressed: busy ? null : () => photo(false),
                  child: Text(
                    avatar == null ? 'Profile photo' : 'Profile photo selected',
                  ),
                ),
                OutlinedButton(
                  onPressed: busy ? null : () => photo(true),
                  child: Text(
                    cover == null ? 'Cover photo' : 'Cover photo selected',
                  ),
                ),
                TextFormField(
                  controller: name,
                  maxLength: 30,
                  decoration: const InputDecoration(labelText: 'Display name'),
                  validator: (s) =>
                      (s?.trim().length ?? 0) >= 2 ? null : 'Name is too short',
                ),
                DropdownButtonFormField<String>(
                  initialValue: ['Male', 'Female', 'Other'].contains(gender)
                      ? gender
                      : null,
                  decoration: const InputDecoration(labelText: 'Gender'),
                  items: [
                    for (final g in ['Male', 'Female', 'Other'])
                      DropdownMenuItem(value: g, child: Text(g)),
                  ],
                  onChanged: (v) => setState(() => gender = v),
                ),
                ListTile(
                  title: const Text('Date of birth'),
                  subtitle: Text(
                    dob?.toIso8601String().split('T').first ?? 'Choose date',
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
                ListTile(
                  title: const Text('Country'),
                  subtitle: Text(countryName ?? 'Choose country'),
                  onTap: () => showCountryPicker(
                    context: context,
                    onSelect: (c) => setState(() {
                      countryCode = c.countryCode;
                      countryName = c.name;
                    }),
                  ),
                ),
                TextField(
                  controller: language,
                  decoration: const InputDecoration(labelText: 'Language'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bio,
                  maxLength: 300,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Bio'),
                ),
                FilledButton(
                  onPressed: busy ? null : save,
                  child: Text(busy ? 'Saving…' : 'Save'),
                ),
              ],
            ),
          ),
  );
}
