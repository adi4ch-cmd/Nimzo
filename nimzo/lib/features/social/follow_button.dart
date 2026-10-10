import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/supabase_provider.dart';
import '../../core/widgets/master_ui.dart';
import '../profile/profile_repository.dart';
import 'social_repositories.dart';

/// The reference follow control delegates to the existing repository.
class ReferenceFollowButton extends ConsumerStatefulWidget {
  final String userId;
  const ReferenceFollowButton({super.key, required this.userId});
  @override
  ConsumerState<ReferenceFollowButton> createState() => _FollowState();
}

class _FollowState extends ConsumerState<ReferenceFollowButton> {
  bool busy = false;
  @override
  Widget build(BuildContext context) {
    final following = ref.watch(isFollowingProvider(widget.userId));
    return OutlinedButton(
      onPressed: busy || !following.hasValue
          ? null
          : () async {
              setState(() => busy = true);
              try {
                final repo = ref.read(followRepositoryProvider);
                following.value!
                    ? await repo.unfollow(widget.userId)
                    : await repo.follow(widget.userId);
                ref.invalidate(isFollowingProvider(widget.userId));
                ref.invalidate(profileStatsProvider(widget.userId));
                final me = ref.read(currentUserIdProvider);
                if (me != null) ref.invalidate(profileStatsProvider(me));
              } catch (_) {
                if (context.mounted)
                  showUiUnavailable(context, 'Follow update');
              } finally {
                if (mounted) setState(() => busy = false);
              }
            },
      child: Text(
        busy
            ? 'Updating…'
            : following.valueOrNull == true
                ? 'Following'
                : 'Follow',
      ),
    );
  }
}
