import 'dart:async';
import 'package:flutter/material.dart';

List<String> cpClockParts(String? startedAt, DateTime now) {
  final start = DateTime.tryParse(startedAt ?? '');
  if (start == null) return const ['—', '—', '—', '—'];
  final elapsed = now.toUtc().difference(start.toUtc());
  final seconds = elapsed.isNegative ? 0 : elapsed.inSeconds;
  return [
    seconds ~/ 86400,
    seconds ~/ 3600 % 24,
    seconds ~/ 60 % 60,
    seconds % 60
  ].map((n) => n.toString().padLeft(2, '0')).toList();
}

/// Displays the real persisted CP binding time; no reward/score assumptions.
class CpRelationshipClock extends StatefulWidget {
  const CpRelationshipClock({super.key, required this.startedAt});
  final String? startedAt;
  @override
  State<CpRelationshipClock> createState() => _ClockState();
}

class _ClockState extends State<CpRelationshipClock> {
  Timer? timer;
  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(covariant CpRelationshipClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startedAt != widget.startedAt) _start();
  }

  void _start() {
    timer?.cancel();
    if (DateTime.tryParse(widget.startedAt ?? '') != null) {
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parts = cpClockParts(widget.startedAt, DateTime.now());
    return Row(children: [
      for (final (index, label)
          in const ['Days', 'Hours', 'Minutes', 'Seconds'].indexed)
        Expanded(
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Container(
                    height: 66,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: const Color(0x88340851),
                        border: Border.all(
                            color: const Color(0xffe380e7), width: 1.5),
                        borderRadius: BorderRadius.circular(13)),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(parts[index],
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900)),
                          Text(label,
                              style: const TextStyle(
                                  color: Color(0xffd7a9e3), fontSize: 11)),
                        ]))))
    ]);
  }
}
