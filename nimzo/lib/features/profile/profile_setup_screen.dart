import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import '../../core/providers/supabase_provider.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/helpers.dart';
import '../../core/widgets/nimzo_button.dart';
import '../../core/widgets/nimzo_icon.dart';
import 'profile_repository.dart';
import 'profile_image_format.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});
  @override
  ConsumerState<ProfileSetupScreen> createState() => _S();
}

class _S extends ConsumerState<ProfileSetupScreen> {
  bool busy = false;
  bool loading = true;
  String? loadError;
  String? _avatarPath,
      _coverPath,
      _countryCode,
      _countryName,
      _language,
      _gender;
  DateTime? _dob;
  final _name = TextEditingController();
  final _bio = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { loading = true; loadError = null; });
    try {
      final id = ref.read(currentUserIdProvider);
      if (id == null) throw StateError('Please sign in again.');
      final p = await ref.read(profileProvider(id).future);
      if (!mounted) return;
      setState(() {
        _name.text = p.displayName ?? '';
        _avatarPath = p.avatarPath; _coverPath = p.coverPath;
        _countryCode = p.countryCode; _countryName = p.countryName;
        _language = p.language ?? 'English'; _gender = p.gender;
        _dob = p.dateOfBirth; _bio.text = p.bio ?? '';
      });
    } catch (e) { if (mounted) setState(() => loadError = '$e'); }
    finally { if (mounted) setState(() => loading = false); }
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _pickImage({
    required bool cover,
    required ImageSource source,
  }) async {
    if (busy || loading) return;
    setState(() => busy = true);
    try {
      final x = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 88,
      );
      if (x == null || !mounted) return;
      final bytes = await x.readAsBytes();
      final (extension, contentType) = profileImageFormat(bytes);
      if (!mounted) return;
      final db = ref.read(supabaseProvider);
      final uid = db.auth.currentUser?.id;
      if (uid == null) throw Exception('Please sign in again.');
      final bucket = cover ? 'covers' : 'avatars';
      final path =
          '$uid/${cover ? 'cover' : 'avatar'}-${DateTime.now().microsecondsSinceEpoch}.$extension';
      await db.storage.from(bucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              upsert: false,
              contentType: contentType,
            ),
          );
      if (!mounted) return;
      setState(() {
        if (cover) {
          _coverPath = path;
        } else {
          _avatarPath = path;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            cover ? 'Cover photo uploaded.' : 'Profile photo uploaded.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Photo upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _save() async {
    if (busy || loading || loadError != null) return;
    final name = _name.text.trim();
    if (_avatarPath?.trim().isNotEmpty != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a profile photo.')),
      );
      return;
    }
    if (_countryCode == null ||
        _dob == null ||
        _language == null ||
        _gender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please complete country, language, date of birth and gender.',
          ),
        ),
      );
      return;
    }
    setState(() => busy = true);
    try {
      await ref.read(profileRepositoryProvider).update(
            displayName: name,
            bio: _bio.text.trim(),
            avatarPath: _avatarPath,
            coverPath: _coverPath,
            countryCode: _countryCode,
            countryName: _countryName,
            language: _language,
            dateOfBirth: _dob,
            gender: _gender,
          );
      final id = ref.read(currentUserIdProvider);
      if (id != null) {
        ref.invalidate(profileProvider(id));
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Edit Profile')),
        body: loading ? const Center(child: CircularProgressIndicator())
      : loadError != null ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Profile could not be loaded.'),
          TextButton(onPressed: () { final id = ref.read(currentUserIdProvider);
            if (id != null) ref.invalidate(profileProvider(id)); _load(); }, child: const Text('Retry')),
        ])) : SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Profile Identity',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              const Text(
                'Your Nimzo ID is permanent. You can change your display name anytime.',
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _name,
                maxLength: 30,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Name (optional)',
                  hintText: 'Your display name',
                  prefixIcon: NimzoIcon(
                    Icons.person_rounded,
                    color: NimzoColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _ImageCard(
                title: 'Profile Picture',
                path: _avatarPath,
                bucket: 'avatars',
                imageUrl: storageUrl(
                  ref.read(supabaseProvider),
                  'avatars',
                  _avatarPath,
                ),
                onGallery: () =>
                    _pickImage(cover: false, source: ImageSource.gallery),
                onCamera: () =>
                    _pickImage(cover: false, source: ImageSource.camera),
              ),
              const SizedBox(height: 14),
              _ImageCard(
                title: 'Profile Cover',
                path: _coverPath,
                bucket: 'covers',
                imageUrl: storageUrl(
                  ref.read(supabaseProvider),
                  'covers',
                  _coverPath,
                ),
                cover: true,
                onGallery: () =>
                    _pickImage(cover: true, source: ImageSource.gallery),
                onCamera: () =>
                    _pickImage(cover: true, source: ImageSource.camera),
              ),
              const SizedBox(height: 20),
              _selectTile(
                context,
                'Country',
                _countryName ?? 'Select country',
                () => showCountryPicker(
                  context: context,
                  showPhoneCode: false,
                  onSelect: (c) => setState(() {
                    _countryCode = c.countryCode;
                    _countryName = c.name;
                  }),
                ),
              ),
              _selectTile(
                context,
                'Language',
                _language ?? 'Select language',
                () => _choice(
                  'Language',
                  ['English', 'Arabic'],
                  _language,
                  (v) => setState(() => _language = v),
                ),
              ),
              _selectTile(
                context,
                'Gender',
                _gender ?? 'Select gender',
                () => _choice(
                  'Gender',
                  ['Male', 'Female', 'Prefer not to say'],
                  _gender,
                  (v) => setState(() => _gender = v),
                ),
              ),
              _selectTile(
                context,
                'Date of Birth',
                _dob == null
                    ? 'Select date'
                    : '${_dob!.day.toString().padLeft(2, '0')}/${_dob!.month.toString().padLeft(2, '0')}/${_dob!.year}',
                () async {
                  final d = await showDatePicker(
                    context: context,
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                    initialDate: _dob ?? DateTime(2000),
                  );
                  if (d != null && mounted) setState(() => _dob = d);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bio,
                maxLength: 300,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'About / Bio'),
              ),
              const SizedBox(height: 16),
              NimzoButton(
                  label: 'Save Profile', loading: busy, onPressed: _save),
            ],
          ),
        ),
      );

  Future<void> _choice(
    String title,
    List<String> options,
    String? current,
    ValueChanged<String> set,
  ) async {
    final v = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            ...options.map(
              (x) => ListTile(
                title: Text(x),
                trailing: x == current
                    ? const NimzoIcon(
                        Icons.check_circle_rounded,
                        size: 20,
                        color: Color(0xFF2E9B73),
                      )
                    : null,
                onTap: () => Navigator.pop(context, x),
              ),
            ),
          ],
        ),
      ),
    );
    if (v != null && mounted) set(v);
  }

  Widget _selectTile(
    BuildContext c,
    String title,
    String value,
    VoidCallback onTap,
  ) =>
      Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          title: Text(title),
          subtitle: Text(value),
          trailing: const NimzoIcon(
            Icons.chevron_right_rounded,
            color: Color(0xFF64748B),
          ),
          onTap: onTap,
        ),
      );
}

class _ImageCard extends StatelessWidget {
  final String title, bucket;
  final String? path, imageUrl;
  final bool cover;
  final VoidCallback onGallery, onCamera;
  const _ImageCard({
    required this.title,
    required this.bucket,
    required this.path,
    required this.imageUrl,
    required this.onGallery,
    required this.onCamera,
    this.cover = false,
  });
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: cover ? 110 : 64,
                height: 64,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                child: imageUrl == null
                    ? const NimzoIcon(
                        Icons.add_photo_alternate_rounded,
                        size: 26,
                        color: Color(0xFF2E9B73),
                      )
                    : Image.network(
                        imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const NimzoIcon(
                          Icons.broken_image_rounded,
                          color: Color(0xFFD85C5C),
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    const Text('Choose directly from your phone or camera.'),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const NimzoIcon(
                  Icons.more_horiz_rounded,
                  color: Color(0xFF64748B),
                ),
                onSelected: (v) => v == 'camera' ? onCamera() : onGallery(),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'gallery', child: Text('Phone Gallery')),
                  PopupMenuItem(value: 'camera', child: Text('Camera')),
                ],
              ),
            ],
          ),
        ),
      );
}
