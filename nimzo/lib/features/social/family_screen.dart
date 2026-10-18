import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/supabase_provider.dart';
import '../../core/widgets/art/nimzo_identity_art.dart';
import 'family_repository.dart';
import '../wallet/wallet_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FamilyScreen extends ConsumerStatefulWidget {
  const FamilyScreen({super.key});
  @override
  ConsumerState<FamilyScreen> createState() => _FamilyState();
}

class _FamilyState extends ConsumerState<FamilyScreen> {
  bool busy = false;
  (String, String)? pendingDraft;
  String? pendingKey;
  Future<void> _run(Future<void> Function() action) async {
    if (busy) return;
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() => busy = true);
    try {
      await action();
      container.invalidate(familyDirectoryProvider);
      container.invalidate(walletProvider);
    } catch (error) {
      final message = error is PostgrestException && error.code == '23514'
          ? 'Family creation requires 1,000,000 coins in your wallet.'
          : error is PostgrestException && error.code == '23505'
              ? 'You already own a family. Pull down to refresh.'
              : 'Family action failed. Please retry.';
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _create() async {
    final draft = await showDialog<(String, String)>(
        context: context, builder: (_) => const _FamilyCreateDialog());
    if (mounted && draft != null) {
      final repository = ref.read(familyRepositoryProvider);
      if (pendingDraft != draft || pendingKey == null) {
        pendingDraft = draft;
        pendingKey = repository.newRequestKey();
      }
      await _run(() => repository.create(draft.$1, draft.$2, pendingKey!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final families = ref.watch(familyDirectoryProvider);
    final me = ref.watch(currentUserIdProvider);
    final owns = families.valueOrNull?.any((f) => f.ownerId == me) ?? false;
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
                Color(0xff1b062c)
              ])),
          child: CustomPaint(
              painter: const _FamilyBackdrop(),
              child: SafeArea(
                  child: Column(children: [
                Row(children: [
                  IconButton(
                      tooltip: 'Back',
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.chevron_left_rounded,
                          color: Colors.white)),
                  const Expanded(
                      child: Text('Family',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Color(0xffead2ff),
                              fontSize: 28,
                              fontWeight: FontWeight.w700))),
                  const SizedBox(width: 48)
                ]),
                const SizedBox(height: 20),
                const NimzoIdentityArt(
                    kind: NimzoArt.family, size: 110, color: Color(0xffc9a2e2)),
                const Text('All Family',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                Expanded(
                    child: families.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) => Center(
                      child: TextButton(
                          onPressed: () =>
                              ref.invalidate(familyDirectoryProvider),
                          child: const Text('Could not load families · Retry',
                              style: TextStyle(color: Colors.white)))),
                  data: (items) => RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(familyDirectoryProvider);
                        await ref.read(familyDirectoryProvider.future);
                      },
                      child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            if (items.isEmpty)
                              const Padding(
                                  padding: EdgeInsets.all(32),
                                  child: Column(children: [
                                    NimzoIdentityArt(
                                        kind: NimzoArt.mascot,
                                        size: 90,
                                        color: Color(0xffe8c6ff)),
                                    Text(
                                        'No families yet. Create the first one.',
                                        style:
                                            TextStyle(color: Colors.white70)),
                                  ])),
                            for (final family in items)
                              Card(
                                  color: const Color(0xff35104e),
                                  child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(family.name,
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 18,
                                                    fontWeight:
                                                        FontWeight.w700)),
                                            if (family.description.isNotEmpty)
                                              Text(family.description,
                                                  style: const TextStyle(
                                                      color: Colors.white70)),
                                            const SizedBox(height: 8),
                                            Text(
                                                '${family.memberCount} members',
                                                style: const TextStyle(
                                                    color: Colors.white70)),
                                            if (family.ownerId == me)
                                              const Text('Your family',
                                                  style: TextStyle(
                                                      color: Color(0xffe0bbff)))
                                            else
                                              FilledButton(
                                                  onPressed: busy
                                                      ? null
                                                      : () => _run(() => family
                                                              .includes(me)
                                                          ? ref
                                                              .read(
                                                                  familyRepositoryProvider)
                                                              .leave(family.id)
                                                          : ref
                                                              .read(
                                                                  familyRepositoryProvider)
                                                              .join(family.id)),
                                                  child: Text(
                                                      family.includes(me)
                                                          ? 'Leave'
                                                          : 'Join')),
                                          ]))),
                          ])),
                )),
                Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 18),
                    child: OutlinedButton(
                        onPressed: busy || owns || me == null ? null : _create,
                        style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xffe0bbff),
                            disabledForegroundColor: Colors.white54,
                            minimumSize: const Size.fromHeight(46),
                            side: const BorderSide(color: Color(0xff9865bb)),
                            shape: const StadiumBorder()),
                        child: Text(owns
                            ? 'Your family is ready'
                            : 'Create Family · 1,000,000 coins'))),
              ])))),
    );
  }
}

class _FamilyCreateDialog extends StatefulWidget {
  const _FamilyCreateDialog();
  @override
  State<_FamilyCreateDialog> createState() => _FamilyCreateDialogState();
}

class _FamilyCreateDialogState extends State<_FamilyCreateDialog> {
  final name = TextEditingController();
  final description = TextEditingController();
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    name.dispose();
    description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Create Family'),
        content: SingleChildScrollView(
            child: Form(
                key: form,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text(
                      'Creating a family costs 1,000,000 coins. Joining is free.'),
                  TextFormField(
                      controller: name,
                      maxLength: 40,
                      decoration:
                          const InputDecoration(labelText: 'Family name'),
                      validator: (value) => (value?.trim().length ?? 0) < 2
                          ? 'Enter at least 2 characters'
                          : null),
                  TextFormField(
                      controller: description,
                      maxLength: 500,
                      maxLines: 3,
                      decoration:
                          const InputDecoration(labelText: 'Description')),
                ]))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () {
                if (form.currentState!.validate()) {
                  Navigator.pop(
                      context, (name.text.trim(), description.text.trim()));
                }
              },
              child: const Text('Pay 1,000,000 coins & Create'))
        ],
      );
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
