import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_theme.dart';

/// Presentation primitives transcribed from nimzo-ui-2.html.
class GradientText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Gradient gradient;
  const GradientText(this.text,
      {super.key, this.style, this.gradient = NimzoStyle.gradient});
  @override
  Widget build(BuildContext context) => ShaderMask(
        shaderCallback: (rect) => gradient.createShader(rect),
        blendMode: BlendMode.srcIn,
        child: Text(text,
            style: (style ??
                    const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .5))
                .copyWith(color: Colors.white)),
      );
}

class GradientButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Gradient gradient;
  final Color foreground;
  final EdgeInsets padding;
  const GradientButton(
      {super.key,
      required this.child,
      required this.onPressed,
      this.gradient = NimzoStyle.gradient,
      this.foreground = Colors.white,
      this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 13)});
  @override
  Widget build(BuildContext context) => Opacity(
        opacity: onPressed == null ? .5 : 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
              gradient: gradient, borderRadius: BorderRadius.circular(14)),
          child: FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  disabledForegroundColor: foreground,
                  foregroundColor: foreground,
                  padding: padding,
                  textStyle: const TextStyle(
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
              onPressed: onPressed,
              child: child),
        ),
      );
}

class ReferenceTabs extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;
  final bool pills;
  const ReferenceTabs(
      {super.key,
      required this.labels,
      required this.selected,
      required this.onSelected,
      this.pills = false});
  @override
  Widget build(BuildContext context) => Container(
        decoration: pills
            ? null
            : const BoxDecoration(
                border: Border(bottom: BorderSide(color: NimzoStyle.line))),
        child: Row(children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
                child: Padding(
                    padding: EdgeInsets.only(
                        right: pills && i < labels.length - 1 ? 8 : 0),
                    child: InkWell(
                        onTap: () => onSelected(i),
                        borderRadius: BorderRadius.circular(pills ? 20 : 0),
                        child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                                color: pills && selected != i
                                    ? NimzoStyle.surface
                                    : null,
                                gradient: pills && selected == i
                                    ? NimzoStyle.gradient
                                    : null,
                                borderRadius:
                                    pills ? BorderRadius.circular(20) : null,
                                border: !pills && selected == i
                                    ? const Border(
                                        bottom: BorderSide(
                                            color: NimzoStyle.primary,
                                            width: 2))
                                    : null),
                            child: Text(labels[i],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: pills && selected == i
                                        ? Colors.white
                                        : selected == i
                                            ? NimzoStyle.ink
                                            : NimzoStyle.muted))))))
        ]),
      );
}

class ReferenceArtwork extends StatelessWidget {
  final String group;
  final int index;
  final double size;
  final BoxFit fit;
  const ReferenceArtwork(this.group, this.index,
      {super.key, this.size = 58, this.fit = BoxFit.contain});
  @override
  Widget build(BuildContext context) =>
      Image.asset('assets/reference/$group/$index.jpg',
          width: size, height: size, fit: fit);
}

class BalancePanel extends StatelessWidget {
  final String label, balance;
  const BalancePanel({super.key, this.label = 'Coins', required this.balance});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            gradient: NimzoStyle.gradient,
            borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 12)),
          Text(balance,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w700))
        ]),
      );
}

class DashedCircle extends StatelessWidget {
  final Widget child;
  final double size;
  final Color color;
  const DashedCircle(
      {super.key,
      required this.child,
      this.size = 52,
      this.color = NimzoStyle.primary});
  @override
  Widget build(BuildContext context) => SizedBox.square(
      dimension: size,
      child: CustomPaint(
          painter: _DashedCirclePainter(color), child: Center(child: child)));
}

class _DashedCirclePainter extends CustomPainter {
  final Color color;
  const _DashedCirclePainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2),
        radius = size.width / 2 - 1;
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xfff1e6ff));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (var i = 0; i < 28; i++) {
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
          i * math.pi * 2 / 28, math.pi * 2 / 44, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter oldDelegate) =>
      oldDelegate.color != color;
}

void showUiUnavailable(BuildContext context,
    [String feature = 'This feature']) {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text('$feature is unavailable.')));
}

Future<T?> showReferenceSheet<T>(BuildContext context, Widget child) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: .45),
      builder: (context) => Theme(
          data: Theme.of(context).copyWith(
              textTheme: Theme.of(context).textTheme.apply(
                  bodyColor: NimzoStyle.ink, displayColor: NimzoStyle.ink)),
          child: SafeArea(
              child: ConstrainedBox(
                  constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * .75),
                  child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16,
                          16 + MediaQuery.viewInsetsOf(context).bottom),
                      child: SingleChildScrollView(child: child))))),
    );

/// Original path artwork from the final HTML; never a substitute icon catalog.
class ReferenceIcon extends StatelessWidget {
  final String name;
  final double size;
  final Color? color;
  final bool originalColors;
  const ReferenceIcon(this.name,
      {super.key, this.size = 22, this.color, this.originalColors = false});
  @override
  Widget build(BuildContext context) => Align(
      widthFactor: 1,
      heightFactor: 1,
      child: SvgPicture.asset('assets/reference/icons/$name.svg',
          width: size,
          height: size,
          colorFilter: originalColors
              ? null
              : ColorFilter.mode(
                  color ?? IconTheme.of(context).color ?? NimzoStyle.ink,
                  BlendMode.srcIn)));
}

/// The reference's generated microphone room artwork is its default room image.
class ReferenceRoomAvatar extends StatelessWidget {
  final String? url;
  final double size;
  const ReferenceRoomAvatar({super.key, this.url, this.size = 46});
  @override
  Widget build(BuildContext context) {
    final fallback = SvgPicture.asset('assets/reference/icons/room.svg',
        width: size, height: size);
    return SizedBox.square(
        dimension: size,
        child: ClipOval(
            child: url == null || url!.isEmpty
                ? fallback
                : Image.network(url!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => fallback)));
  }
}

String referenceNumber(num value) => value
    .toString()
    .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
