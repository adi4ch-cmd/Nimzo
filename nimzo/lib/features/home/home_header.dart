import 'package:flutter/material.dart';

/// Shared room/event header. Tabs scroll on narrow screens and with larger text.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.onSearch,
  });

  final int selected;
  final ValueChanged<int> onSelected;
  final VoidCallback onSearch;
  static const labels = ['My', 'Popular', 'Discover', 'New', 'Pakistan'];
  static const gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xffcf48f5), Color(0xffa52bff)],
  );

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(gradient: gradient),
        child: Padding(
          padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
          child: Row(children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (var i = 0; i < labels.length; i++)
                    Semantics(
                      button: true,
                      selected: selected == i,
                      child: InkWell(
                        key: ValueKey('explore-tab-$i'),
                        onTap: () => onSelected(i),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 12),
                          child: Text(labels[i],
                              style: TextStyle(
                                fontFamily: 'serif',
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: selected == i
                                    ? Colors.white
                                    : Colors.white60,
                              )),
                        ),
                      ),
                    ),
                ]),
              ),
            ),
            IconButton(
              tooltip: 'Search rooms and users',
              onPressed: onSearch,
              icon: const Icon(Icons.search_rounded,
                  color: Colors.white, size: 27),
            ),
          ]),
        ),
      );
}
