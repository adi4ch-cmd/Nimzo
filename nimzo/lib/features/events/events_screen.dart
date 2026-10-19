import 'package:flutter/material.dart';
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

/// The five complete banners supplied by the user, in their original order.
/// These are display artwork; no reward eligibility or live campaign is implied.
class EventBannerList extends StatelessWidget {
  const EventBannerList({super.key});

  static const banners = <({String title, double top})>[
    (title: 'Glamour Queen', top: 170),
    (title: 'Power Championship', top: 358),
    (title: 'Room Medal Challenge', top: 546),
    (title: 'Team Up, Share Gold!', top: 734),
    (title: 'Recharge To Get Super Rebate', top: 922),
  ];

  @override
  Widget build(BuildContext context) => ListView.separated(
        key: const PageStorageKey('event-banners'),
        padding: const EdgeInsets.fromLTRB(13, 8, 13, 16),
        itemCount: banners.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 9),
        itemBuilder: (context, index) {
          if (index == 0) {
            return const Text('Event',
                style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xff303030)));
          }
          final banner = banners[index - 1];
          return Semantics(
            image: true,
            label: banner.title,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: AspectRatio(
                aspectRatio: 540 / 175,
                child: LayoutBuilder(builder: (context, constraints) {
                  // Draw only this banner's rectangle from the supplied sheet.
                  // The source is kept intact; phone chrome and partial artwork
                  // remain outside the clipped viewport.
                  final scale = constraints.maxWidth / 540;
                  return Stack(clipBehavior: Clip.hardEdge, children: [
                    Positioned(
                      left: -18 * scale,
                      top: -banner.top * scale,
                      width: 576 * scale,
                      height: 1280 * scale,
                      child: Image.asset(
                        'assets/events/reference_banners.jpg',
                        fit: BoxFit.fill,
                        excludeFromSemantics: true,
                      ),
                    ),
                  ]);
                }),
              ),
            ),
          );
        },
      );
}
