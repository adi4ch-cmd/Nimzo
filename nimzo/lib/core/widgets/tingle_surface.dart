import 'package:flutter/material.dart';

/// Original NIMZO presentation tokens measured against the full walkthrough.
/// Contains no service or account state.
const tingleSky = LinearGradient(
  begin: Alignment.topRight,
  end: Alignment.bottomLeft,
  stops: [0, .35, 1],
  colors: [Color(0xff68b7f3), Color(0xffc7ceff), Color(0xfff2efff)],
);

class TingleTabs extends StatelessWidget {
  const TingleTabs(
      {super.key,
      required this.labels,
      required this.selected,
      required this.onSelected,
      this.light = false,
      this.pills = false});
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;
  final bool light, pills;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (var i = 0; i < labels.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Semantics(
                selected: selected == i,
                button: true,
                child: InkWell(
                  key: ValueKey('tingle-tab-${labels[i]}'),
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => onSelected(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    constraints: const BoxConstraints(minHeight: 36),
                    alignment: Alignment.center,
                    padding: EdgeInsets.symmetric(horizontal: pills ? 14 : 2),
                    decoration: BoxDecoration(
                        color: pills
                            ? (selected == i
                                ? const Color(0xffa32cf4)
                                : Colors.white.withValues(alpha: .5))
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(labels[i],
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: selected == i
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: pills && selected == i
                                ? Colors.white
                                : light
                                    ? (selected == i
                                        ? Colors.white
                                        : Colors.white70)
                                    : selected == i
                                        ? const Color(0xffa32cf4)
                                        : const Color(0xffa499bf))),
                  ),
                ),
              ),
            ),
        ]),
      );
}
