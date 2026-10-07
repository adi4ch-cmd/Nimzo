import 'dart:math';
import 'package:flutter/material.dart';
import 'game_catalog.dart';

/// Approved boards remain visible when the verified game service is unavailable.
/// No prototype timer, wager deduction, payout or result is generated here.
class GameScreen extends StatelessWidget {
  final String? roomId, slug;
  const GameScreen({super.key, this.roomId, this.slug});
  static const fruit = [
    'Orange',
    'Kiwi',
    'Apple',
    'Avocado',
    'Watermelon',
    'Lemon',
    'Mango',
    'Pomegranate'
  ];
  static const grady = [
    'Tomato',
    'Mushroom',
    'Onion',
    'Shaljam',
    'Pizza',
    'Meat',
    'Fish',
    'Jinga',
    'Chicken',
    'Mixed Meat'
  ];
  static const cars = [
    'BMW',
    'Porsche',
    'Land Rover',
    'Ferrari',
    'Lamborghini',
    'Bugatti',
    'Rolls-Royce',
    'Mercedes'
  ];
  @override
  Widget build(BuildContext context) {
    final game =
        NimzoRoomGames.approved.where((g) => g.slug == slug).firstOrNull ??
            NimzoRoomGames.approved.first;
    final i = game.artwork;
    final title = i == 1
        ? 'Grady Pro'
        : i == 3
            ? 'Slot Jackpots'
            : game.title;
    final options = i == 0
        ? fruit
        : i == 1
            ? grady
            : i == 2
                ? cars
                : i == 4
                    ? ['Player A', 'Player B', 'Player C']
                    : ['Home', 'Draw', 'Away'];
    return Scaffold(
        backgroundColor: const Color(0xff14052e),
        appBar: AppBar(
            backgroundColor: const Color(0xff3b0f7a),
            foregroundColor: Colors.white,
            title: Text(title,
                style: const TextStyle(
                    color: Colors.white, fontSize: 16, fontFamily: 'Roboto'))),
        body: ListView(padding: const EdgeInsets.all(14), children: [
          const Padding(
              padding: EdgeInsets.only(bottom: 14),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Round —', style: TextStyle(color: Color(0xffe9d5ff))),
                    Text('Time —', style: TextStyle(color: Color(0xffe9d5ff)))
                  ])),
          if (i == 5)
            const Center(
                child: SizedBox.square(
                    dimension: 190,
                    child: CustomPaint(painter: _WheelPainter())))
          else if (i == 3) ...[
            Row(children: [
              for (final label in ['GRAND', 'MAJOR', 'MINOR', 'MINI'])
                Expanded(
                    child: Padding(
                        padding: EdgeInsets.all(4),
                        child: Text(label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Color(0xfffde68a), fontSize: 11))))
            ]),
            Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: const Color(0xfff59e0b),
                    borderRadius: BorderRadius.circular(14)),
                child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 5,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                    children: [
                      for (var n = 0; n < 15; n++)
                        Container(
                            decoration: BoxDecoration(
                                color: const Color(0xff0f0a26),
                                borderRadius: BorderRadius.circular(8)),
                            child: Image.asset(
                                'assets/reference/slot/${n * 5 % 12}.jpg',
                                fit: BoxFit.contain))
                    ])),
          ] else
            GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: i == 1 ? 5 : 3,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: i == 1 ? 0.65 : 0.85,
                children: [
                  for (var n = 0;
                      n < options.length + ((i == 0 || i == 2) ? 1 : 0);
                      n++)
                    if ((i == 0 || i == 2) && n == 4)
                      Container(
                          decoration: BoxDecoration(
                              color: const Color(0xff1b0b3a),
                              border:
                                  Border.all(color: const Color(0xfffacc15)),
                              borderRadius: BorderRadius.circular(12)),
                          child: const Center(
                              child: Text('—\nDrawing Time',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white))))
                    else
                      Builder(builder: (context) {
                        final index = (i == 0 || i == 2) && n > 4 ? n - 1 : n;
                        return Container(
                            decoration: BoxDecoration(
                                color: [
                                  const Color(0xffea580c),
                                  const Color(0xff7c3aed),
                                  const Color(0xff16a34a),
                                  const Color(0xff0284c7),
                                  const Color(0xffdb2777)
                                ][index % 5],
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.all(4),
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (i == 0 || i == 1)
                                    Expanded(
                                        child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: Image.asset(
                                                'assets/reference/${i == 0 ? 'fruit' : 'grady'}/$index.jpg',
                                                fit: BoxFit.cover))),
                                  Text(options[index],
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700)),
                                ]));
                      }),
                ]),
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('Results unavailable',
                  style: TextStyle(color: Color(0xffe9d5ff)))),
          const SizedBox(height: 10),
          FilledButton(
              style: FilledButton.styleFrom(
                  disabledBackgroundColor: const Color(0xff382152),
                  disabledForegroundColor: const Color(0xffe9d5ff)),
              onPressed: null,
              child: Text(i == 3 || i == 5
                  ? 'Spin unavailable'
                  : 'Betting unavailable')),
          const SizedBox(height: 10),
          Text(
              roomId == null
                  ? 'Open a room to access in-room games.'
                  : 'Game service unavailable. No coins will be spent.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xffc4b5fd))),
        ]));
  }
}

class _WheelPainter extends CustomPainter {
  const _WheelPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2), r = size.width / 2;
    const colors = [
      0xfff43f5e,
      0xff22c55e,
      0xfffacc15,
      0xff3b82f6,
      0xffec4899,
      0xfff97316,
      0xffa855f7,
      0xff06b6d4
    ];
    for (var i = 0; i < 8; i++) {
      canvas.drawArc(Rect.fromCircle(center: center, radius: r), i * pi / 4,
          pi / 4, true, Paint()..color = Color(colors[i]));
    }
    canvas.drawCircle(
        center,
        r - 3,
        Paint()
          ..color = const Color(0xfff59e0b)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6);
    canvas.drawCircle(center, 28, Paint()..color = const Color(0xfffff7e0));
    final text = TextPainter(
        text: const TextSpan(
            text: '77',
            style: TextStyle(
                fontSize: 22,
                fontFamily: 'Roboto',
                fontWeight: FontWeight.w800,
                color: Color(0xff92400e))),
        textDirection: TextDirection.ltr)
      ..layout();
    text.paint(canvas, center - Offset(text.width / 2, text.height / 2));
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) => false;
}
