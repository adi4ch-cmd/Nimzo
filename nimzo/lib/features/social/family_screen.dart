import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/supabase_provider.dart';
import '../../core/widgets/art/nimzo_identity_art.dart';
import 'family_repository.dart';

/// Connected Family directory. Maintains the reference's royal purple design,
/// with all identity, membership and purchase results read from Supabase.
class FamilyScreen extends ConsumerStatefulWidget {
  const FamilyScreen({super.key});

  @override
  ConsumerState<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends ConsumerState<FamilyScreen> {
  bool _creating = false;
  String? _busyFamily;
  String? _pendingKey;
  String? _pendingSignature;

  void _notify(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _createFamily() async {
    if (_creating) return;
    final name = TextEditingController();
    final description = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create Family'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text(
              'The server charges 1,000,000 coins once when creating a Family. '
              'Your existing account and wallet data stay unchanged unless '
              'you confirm this purchase.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: name,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: 'Family name', hintText: '2–40 characters',
              ),
            ),
            TextField(
              controller: description,
              maxLength: 500,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, {
              'name': name.text.trim(),
              'description': description.text.trim(),
            }),
            child: const Text('Confirm · 1,000,000 coins'),
          ),
        ],
      ),
    );
    name.dispose();
    description.dispose();
    if (!mounted || result == null) return;
    final familyName = result['name'] ?? '';
    final familyDescription = result['description'] ?? '';
    if (familyName.length < 2 || familyName.length > 40) {
      _notify('Family name must be between 2 and 40 characters.');
      return;
    }
    final repo = ref.read(nimzoFamilyRepositoryProvider);
    final signature = '$familyName\n$familyDescription';
    // A retry of the same request reuses its key, avoiding a second charge
    // if the first response was lost after the server committed.
    if (_pendingSignature != signature) {
      _pendingSignature = signature;
      _pendingKey = repo.newCreationKey();
    }
    setState(() => _creating = true);
    try {
      await repo.create(
        name: familyName,
        description: familyDescription,
        requestKey: _pendingKey!,
      );
      _pendingKey = null;
      _pendingSignature = null;
      ref.invalidate(nimzoFamilyDirectoryProvider);
      _notify('Family created successfully.');
    } catch (error) {
      _notify('Family could not be created: $error');
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _editFamily(NimzoFamily family) async {
    if (_busyFamily != null) return;
    final name = TextEditingController(text: family.name);
    final description = TextEditingController(text: family.description);
    final data = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Family'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: name,
              maxLength: 40,
              decoration: const InputDecoration(labelText: 'Family name'),
            ),
            TextField(
              controller: description,
              maxLength: 500,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, {
              'name': name.text,
              'description': description.text,
            }),
            child: const Text('Save details'),
          ),
        ],
      ),
    );
    name.dispose();
    description.dispose();
    if (!mounted || data == null) return;
    setState(() => _busyFamily = family.id);
    try {
      await ref.read(nimzoFamilyRepositoryProvider).edit(
        family,
        name: data['name'] ?? '',
        description: data['description'] ?? '',
      );
      ref.invalidate(nimzoFamilyDirectoryProvider);
      _notify('Family details updated.');
    } catch (error) {
      _notify('Family could not be updated: $error');
    } finally {
      if (mounted) setState(() => _busyFamily = null);
    }
  }

  Future<void> _changeMembership(NimzoFamily family) async {
    if (_busyFamily != null) return;
    if (family.isMember && family.ownerId ==
        ref.read(currentUserIdProvider)) {
      _notify('Family owners remain members of their Family.');
      return;
    }
    if (family.isMember) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Leave Family?'),
          content: Text('Leave ${family.name}? Your other account data '
              'and wallet will not be deleted.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Leave'),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
    }
    setState(() => _busyFamily = family.id);
    try {
      final repo = ref.read(nimzoFamilyRepositoryProvider);
      if (family.isMember) {
        await repo.leave(family);
      } else {
        await repo.join(family.id);
      }
      ref.invalidate(nimzoFamilyDirectoryProvider);
      _notify(family.isMember ? 'Left Family.' : 'Joined Family.');
    } catch (error) {
      _notify('Membership could not be updated: $error');
    } finally {
      if (mounted) setState(() => _busyFamily = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);
    final families = ref.watch(nimzoFamilyDirectoryProvider);
    final owned = families.valueOrNull?.any((f) => f.ownerId == userId) ?? false;
    return Scaffold(
      backgroundColor: const Color(0xff1b062c),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xff270b40),
              Color(0xff541078),
              Color(0xff1b062c),
            ],
          ),
        ),
        child: CustomPaint(
          painter: const _FamilyBackdrop(),
          child: SafeArea(
            child: Column(children: [
              Row(children: [
                IconButton(
                  tooltip: 'Back',
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.chevron_left_rounded,
                      color: Colors.white),
                ),
                const Expanded(
                  child: Text(
                    'Family',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xffead2ff),
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh Family directory',
                  onPressed: () =>
                      ref.invalidate(nimzoFamilyDirectoryProvider),
                  icon: const Icon(Icons.refresh_rounded,
                      color: Color(0xffead2ff)),
                ),
              ]),
              const SizedBox(height: 12),
              const NimzoIdentityArt(
                kind: NimzoArt.family,
                size: 110,
                color: Color(0xffc9a2e2),
              ),
              const SizedBox(height: 12),
              const Text('All Family',
                  style: TextStyle(color: Colors.white,
                      fontSize: 14, fontWeight: FontWeight.w700)),
              Expanded(
                child: families.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xffd0a3ec)),
                  ),
                  error: (_, __) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Text(
                          'Family directory could not be loaded.',
                          style: TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                        TextButton(
                          onPressed: () =>
                              ref.invalidate(nimzoFamilyDirectoryProvider),
                          child: const Text('Retry'),
                        ),
                      ]),
                    ),
                  ),
                  data: (rows) => rows.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                vertical: 32, horizontal: 20),
                              decoration: BoxDecoration(
                                color: const Color(0xaa35104e),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xffbb8b56)),
                              ),
                              child: const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  NimzoIdentityArt(
                                    kind: NimzoArt.mascot,
                                    size: 80,
                                    color: Color(0xffe8c6ff),
                                  ),
                                  SizedBox(height: 14),
                                  Text(
                                    'No Families yet. Create the first one.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white70, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 18, 14, 20),
                          itemCount: rows.length,
                          itemBuilder: (context, index) {
                            final family = rows[index];
                            final owner = family.ownerId == userId;
                            return Card(
                              color: const Color(0xd035104e),
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(17),
                                side: const BorderSide(
                                  color: Color(0xffbb8b56)),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(children: [
                                  const CircleAvatar(
                                    radius: 26,
                                    backgroundColor: Color(0xff6d3381),
                                    child: Icon(Icons.diversity_3_rounded,
                                      color: Color(0xffe3c38a)),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(family.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800)),
                                        Text(
                                          '${family.memberCount} members · '
                                          '${family.ownerName}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11),
                                        ),
                                        if (family.description.isNotEmpty)
                                          Text(
                                            family.description,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Color(0xffdfc2ed),
                                              fontSize: 11),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  OutlinedButton(
                                    onPressed: _busyFamily != null ||
                                            userId == null
                                        ? null
                                        : owner
                                            ? () => _editFamily(family)
                                            : () => _changeMembership(family),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor:
                                          const Color(0xfff0d0a2),
                                      side: const BorderSide(
                                        color: Color(0xffbb8b56)),
                                    ),
                                    child: Text(owner ? 'Edit'
                                        : family.isMember ? 'Leave' : 'Join'),
                                  ),
                                ]),
                              ),
                            );
                          },
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 18),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    key: const ValueKey('family-create-live'),
                    onPressed: _creating || owned || userId == null
                        ? null : _createFamily,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                      foregroundColor: const Color(0xfff5d7ff),
                      side: const BorderSide(color: Color(0xffba8b56)),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(_creating ? 'Creating…'
                        : owned ? 'You already own a Family'
                        : 'Create Family · 1,000,000 coins'),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _FamilyBackdrop extends CustomPainter {
  const _FamilyBackdrop();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    // Original palace silhouettes and draped curtains frame the empty state.
    for (final mirrored in [false, true]) {
      canvas.save();
      if (mirrored) {
        canvas.translate(size.width, 0);
        canvas.scale(-1, 1);
      }
      final curtain = Path()
        ..moveTo(0, 0)
        ..lineTo(size.width * .37, 0)
        ..cubicTo(size.width * .30, size.height * .12, size.width * .13,
            size.height * .10, size.width * .08, size.height * .37)
        ..lineTo(0, size.height * .52)
        ..close();
      paint.shader = const LinearGradient(colors: [
        Color(0xff170526),
        Color(0xff762c8c),
        Color(0xff2a073a)
      ]).createShader(Rect.fromLTWH(0, 0, size.width * .37, size.height * .52));
      canvas.drawPath(curtain, paint);
      paint.shader = null;
      paint
        ..color = const Color(0xffb88c54)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawPath(curtain, paint);
      for (var i = 0; i < 3; i++) {
        final x = 8.0 + i * 12;
        final h = size.height * (.56 + i * .05);
        final tower = Path()
          ..moveTo(x, size.height)
          ..lineTo(x, h)
          ..lineTo(x + 5, h - 17)
          ..lineTo(x + 10, h)
          ..lineTo(x + 10, size.height)
          ..close();
        paint
          ..color = const Color(0xff2c0a40)
          ..style = PaintingStyle.fill;
        canvas.drawPath(tower, paint);
        paint
          ..color = const Color(0x668b599e)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8;
        canvas.drawPath(tower, paint);
      }
      canvas.restore();
    }
    paint.style = PaintingStyle.stroke;
    for (var i = 0; i < 6; i++) {
      paint
        ..strokeWidth = 1.5
        ..color = const Color(0xffbb6ef0).withValues(alpha: .12);
      final inset = 12.0 + i * 15;
      canvas.drawPath(
          Path()
            ..moveTo(inset, 0)
            ..quadraticBezierTo(
                size.width * .5, size.height * .32, size.width - inset, 0),
          paint);
    }
    paint
      ..style = PaintingStyle.fill
      ..color = const Color(0x33dfbfff);
    for (var i = 0; i < 24; i++) {
      canvas.drawCircle(
          Offset((i * 47.0 + 17) % size.width, (i * 113.0 + 30) % size.height),
          i.isEven ? 1.5 : 1,
          paint);
    }
  }

  @override
  bool shouldRepaint(_FamilyBackdrop oldDelegate) => false;
}
