import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dynamic_event_banners.dart';
import '../../core/widgets/published_image.dart';
import 'package:go_router/go_router.dart';

import '../home/home_header.dart';

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        body: Column(children: [
          HomeHeader(
            selected: 2,
            onSelected: (index) {
              if (index != 2) context.go('/home?tab=$index');
            },
            onSearch: () => context.push('/discover'),
          ),
          const Expanded(child: EventBannerList()),
        ]),
      );
}

/// Campaign artwork is displayed only when the server publishes an active,
/// time-eligible campaign. Empty, loading and failed requests stay distinct.
class EventBannerList extends ConsumerWidget {
  const EventBannerList({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaigns = ref.watch(nimzoEventBannersProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(nimzoEventBannersProvider);
        await ref.read(nimzoEventBannersProvider.future);
      },
      child: ListView(
        key: const PageStorageKey('event-banners'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: const LinearGradient(
                    colors: [Color(0xff064e3b), Color(0xff13976d)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight)),
            child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.auto_awesome_rounded,
                      color: Color(0xffffd783), size: 26),
                  SizedBox(height: 14),
                  Text('Event',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800)),
                  SizedBox(height: 8),
                  Text('Discover what brings us together.',
                      style: TextStyle(color: Color(0xffd9f5e8), height: 1.4)),
                ]),
          ),
          const SizedBox(height: 24),
          const Text('Featured activities',
              style: TextStyle(
                  color: Color(0xff153e30),
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          campaigns.when(
            skipLoadingOnRefresh: false,
            loading: () => const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator())),
            error: (_, __) => _EventStatus(
                icon: Icons.cloud_off_rounded,
                title: 'Events could not be loaded',
                detail: 'Please try again to see the latest activities.',
                action: TextButton(
                    onPressed: () => ref.invalidate(nimzoEventBannersProvider),
                    child: const Text('Retry'))),
            data: (banners) => banners.isEmpty
                ? const _EventStatus(
                    icon: Icons.celebration_outlined,
                    title: 'More moments to celebrate soon',
                    detail:
                        'There are no active events right now. Pull down to refresh.')
                : Column(children: [
                    for (final banner in banners) _LiveEventCard(banner: banner)
                  ]),
          ),
        ],
      ),
    );
  }
}

class _EventStatus extends StatelessWidget {
  const _EventStatus(
      {required this.icon,
      required this.title,
      required this.detail,
      this.action});
  final IconData icon;
  final String title, detail;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        decoration: BoxDecoration(
            color: const Color(0xfff0f8f3),
            borderRadius: BorderRadius.circular(24)),
        child: Column(children: [
          Icon(icon, size: 42, color: const Color(0xff087f5b)),
          const SizedBox(height: 16),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xff153e30),
                  fontWeight: FontWeight.w800,
                  fontSize: 17)),
          const SizedBox(height: 9),
          Text(detail,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xff60756b), height: 1.5)),
          if (action != null) action!,
        ]),
      );
}

/// Campaigns can link only to these already-shipped screens. Unknown targets
/// remain informational; remote content cannot introduce external navigation.
String? supportedEventTarget(String? target) {
  const destinations = {
    '/games',
    '/store',
    '/ranking',
    '/levels',
    '/honors',
    '/daily-checkin'
  };
  return destinations.contains(target) ? target : null;
}

class _LiveEventCard extends StatelessWidget {
  const _LiveEventCard({required this.banner});
  final NimzoEventBanner banner;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xffe2eee6))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Semantics(
              image: true,
              label: banner.title,
              child: AspectRatio(
                  aspectRatio: 540 / 175,
                  child: PublishedImage(
                      url: banner.imageUrl,
                      publication: banner.publication,
                      key: ValueKey('nimzo-live-banner-${banner.id}'),
                      fit: BoxFit.cover,
                      unavailable: const ColoredBox(
                          color: Color(0xffedf5ef),
                          child: Center(
                              child: Icon(Icons.image_not_supported_outlined,
                                  color: Color(0xff60756b))))))),
          Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(banner.title,
                        style: const TextStyle(
                            color: Color(0xff153e30),
                            fontWeight: FontWeight.w800,
                            fontSize: 17)),
                    if (banner.subtitle?.trim().isNotEmpty ?? false)
                      Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(banner.subtitle!,
                              style: const TextStyle(
                                  color: Color(0xff60756b), height: 1.4))),
                    if (supportedEventTarget(banner.target) != null)
                      Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: OutlinedButton.icon(
                            onPressed: () => context
                                .push(supportedEventTarget(banner.target)!),
                            icon: const Icon(Icons.arrow_forward_rounded,
                                size: 18),
                            label: const Text('Explore'),
                          )),
                  ])),
        ]),
      );
}
