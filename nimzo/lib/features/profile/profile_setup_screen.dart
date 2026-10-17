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
      username = TextEditingController(),
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
      username.text = p.username ?? '';
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
    username.dispose();
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
            username: username.text.trim().isEmpty ? null : username.text.trim(),
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


  static const _purple = Color(0xffa145f4);
  static const _muted = Color(0xff9485b6);

  InputDecoration _input(String hint, {String? prefix}) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xffaba4c6), fontSize: 17),
    prefixText: prefix,
    prefixStyle: const TextStyle(color: Colors.black,
      fontSize: 17, fontWeight: FontWeight.w700),
    border: InputBorder.none,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 23),
    counterText: '',
  );

  Widget _label(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 9, top: 20),
    child: Text(label, style: const TextStyle(
      color: _muted, fontSize: 15, fontWeight: FontWeight.w500)),
  );

  Widget _field(Widget child) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: const Color(0xffeeebf6)),
    ),
    clipBehavior: Clip.antiAlias,
    child: child,
  );

  Future<void> _selectBirthday() async {
    final today = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: today,
      initialDate: dob ?? DateTime(today.year - 18, today.month, today.day),
    );
    if (selected != null) setState(() => dob = selected);
  }

  int? get age {
    if (dob == null) return null;
    final today = DateTime.now();
    var years = today.year - dob!.year;
    if (today.month < dob!.month ||
        (today.month == dob!.month && today.day < dob!.day)) {
      years--;
    }
    return years;
  }

  String get flag {
    if (countryCode == null || countryCode!.length != 2) return '🌐';
    return String.fromCharCodes(countryCode!.toUpperCase()
        .codeUnits.map((code) => code + 127397));
  }

  Widget _genderTile(String value, IconData icon, Color shade) => Expanded(
    child: InkWell(
      onTap: busy ? null : () => setState(() => gender = value),
      child: Container(
        height: 74,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: const Color(0xffebe8f4)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: shade.withValues(alpha: .15),
              radius: 20,
              child: Icon(icon, color: shade),
            ),
            const SizedBox(width: 9),
            Expanded(child: Text(value, style: const TextStyle(
              fontSize: 16, color: Colors.black,
              fontWeight: FontWeight.w700))),
            Icon(
              gender == value
                ? Icons.radio_button_checked
                : Icons.radio_button_off,
              color: _purple, size: 22,
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final id = ref.watch(currentUserIdProvider);
    final storedAvatar = avatar ?? existingAvatar;
    final avatarUrl = storedAvatar == null ? null
      : ref.watch(supabaseProvider).storage
          .from('avatars').getPublicUrl(storedAvatar);
    return Scaffold(
      backgroundColor: const Color(0xfff0eeff),
      appBar: AppBar(
        title: const Text('Profile Details', style: TextStyle(
          fontWeight: FontWeight.w800, color: Colors.black)),
        centerTitle: true,
        backgroundColor: const Color(0xffcdccff),
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xffd0ceff), Color(0xffeae9ff),
              Color(0xfff7f6ff)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: failure != null
          ? DataFailure(message: failure!, onRetry: load)
          : !loaded
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: form,
                child: ListView(
                  key: const ValueKey('modify-profile-clean-list'),
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
                  children: [
                    Center(
                      child: InkWell(
                        key: const ValueKey('modify-avatar'),
                        onTap: busy ? null : () => photo(false),
                        borderRadius: BorderRadius.circular(100),
                        child: Stack(children: [
                          CircleAvatar(
                            radius: 78,
                            backgroundColor: Colors.white,
                            backgroundImage: avatarUrl == null
                              ? null : NetworkImage(avatarUrl),
                            child: avatarUrl == null
                              ? const Icon(Icons.person, size: 70,
                                  color: _purple) : null,
                          ),
                          Positioned(right: 1, bottom: 4, child: Container(
                            height: 48, width: 48,
                            decoration: BoxDecoration(
                              color: _purple, shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white, width: 3)),
                            child: const Icon(Icons.camera_alt_rounded,
                              color: Colors.white, size: 25),
                          )),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _label('Enter your name'),
                    _field(TextFormField(
                      key: const ValueKey('modify-nickname'),
                      controller: name,
                      maxLength: 30,
                      enabled: !busy,
                      decoration: _input('Enter your name'),
                      validator: (v) => (v?.trim().length ?? 0) >= 2
                        ? null : 'Please enter a valid name',
                    )),
                    _label('Enter user name'),
                    _field(TextFormField(
                      key: const ValueKey('profile-username'),
                      controller: username,
                      maxLength: 32,
                      enabled: !busy,
                      decoration: _input('Enter your username', prefix: '@'),
                      validator: (v) {
                        final value = (v ?? '').trim().replaceFirst('@', '');
                        if (value.isEmpty) return null;
                        return RegExp(r'^[a-zA-Z0-9_.]{2,32}$').hasMatch(value)
                          ? null : '2-32 letters, numbers, _ or .';
                      },
                    )),
                    _label('Enter age'),
                    _field(ListTile(
                      key: const ValueKey('modify-birthday'),
                      minTileHeight: 76,
                      title: Text(age == null
                        ? 'Choose birth date' : age.toString(),
                        style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600,
                          color: age == null ? _muted : Colors.black)),
                      subtitle: dob == null ? null
                        : Text(dob!.toIso8601String().split('T').first,
                          style: const TextStyle(
                            fontSize: 11, color: _muted)),
                      trailing: const Icon(Icons.calendar_today_outlined,
                        color: _muted),
                      onTap: busy ? null : _selectBirthday,
                    )),
                    _label('Referral Code'),
                    _field(Row(children: [
                      Expanded(child: TextField(
                        enabled: false,
                        decoration: _input('Referral codes unavailable'),
                      )),
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: FilledButton(
                          onPressed: null,
                          style: FilledButton.styleFrom(
                            backgroundColor: _purple,
                            minimumSize: const Size(90, 47),
                          ),
                          child: const Text('Apply'),
                        ),
                      ),
                    ])),
                    _label('Country'),
                    _field(ListTile(
                      key: const ValueKey('modify-country'),
                      minTileHeight: 75,
                      leading: Text(flag,
                        style: const TextStyle(fontSize: 27)),
                      title: Text(countryName ?? 'Select country',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 17)),
                      trailing: const Icon(Icons.expand_more,
                        color: _muted),
                      onTap: busy ? null : () => showCountryPicker(
                        context: context,
                        showPhoneCode: false,
                        onSelect: (selected) => setState(() {
                          countryCode = selected.countryCode;
                          countryName = selected.name;
                        }),
                      ),
                    )),
                    _label('Select gender'),
                    Row(children: [
                      _genderTile('Male', Icons.face_rounded,
                        const Color(0xffef8c35)),
                      const SizedBox(width: 13),
                      _genderTile('Female', Icons.face_3_rounded,
                        const Color(0xfff14d9c)),
                    ]),
                    if (gender == 'Other')
                      TextButton(
                        onPressed: busy ? null
                          : () => setState(() => gender = null),
                        child: const Text('Other selected · Change selection'),
                      ),
                    const SizedBox(height: 18),
                    _field(ExpansionTile(
                      title: const Text('More profile details',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                      childrenPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 9),
                      children: [
                        ListTile(
                          title: const Text('Cover photo'),
                          subtitle: Text(cover == null
                            ? 'Choose from camera or gallery'
                            : 'New cover selected'),
                          trailing: const Icon(Icons.photo_library_outlined),
                          onTap: busy ? null : () => photo(true),
                        ),
                        TextField(
                          controller: language,
                          enabled: !busy,
                          decoration: const InputDecoration(
                            labelText: 'Language'),
                        ),
                        TextFormField(
                          key: const ValueKey('modify-signature'),
                          controller: bio,
                          enabled: !busy,
                          maxLength: 300, maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'About / Bio'),
                        ),
                      ],
                    )),
                    const SizedBox(height: 25),
                    FilledButton(
                      key: const ValueKey('modify-profile-save'),
                      onPressed: busy || id == null ? null : save,
                      style: FilledButton.styleFrom(
                        backgroundColor: _purple,
                        minimumSize: const Size.fromHeight(76),
                        shape: const StadiumBorder(),
                      ),
                      child: Text(busy ? 'Saving…' : 'Save Changes',
                        style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
