// ignore_for_file: prefer_interpolation_to_compose_strings
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Original NIMZO regal lion, drawn with vectors; never copies a movie design.
/// All sounds intentionally remain muted to protect Vivox voice communication.
class RoyalLionEntry extends StatefulWidget {
  const RoyalLionEntry({super.key, required this.name, this.onFinished});
  final String name;
  final VoidCallback? onFinished;
  @override
  State<RoyalLionEntry> createState() => _RoyalLionEntryState();
}

class _RoyalLionEntryState extends State<RoyalLionEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 5500));
  @override
  void initState() {
    super.initState();
    _motion.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onFinished?.call();
    });
  }
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion.stop();
      _motion.value = 1;
    } else if (_motion.status == AnimationStatus.dismissed) {
      _motion.forward();
    }
  }
  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Royal Lion King entrance for ' + widget.name,
    child: Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: _motion,
        builder: (context, _) {
          final t = Curves.easeOutCubic.transform(_motion.value);
          return Stack(children: [
            Positioned.fill(child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -.18), radius: 1.15,
                  colors: [
                    const Color(0xff59310d).withValues(alpha: .9 * t),
                    const Color(0xff101b16).withValues(alpha: .96 * t),
                    const Color(0xff030c09).withValues(alpha: .95 * t),
                  ],
                ),
              ),
            )),
            Center(child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 370),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Transform.translate(
                  offset: Offset(0, 110 * (1 - t)),
                  child: Transform.scale(
                    scale: .65 + .35 * t,
                    child: SizedBox(
                      width: 330, height: 340,
                      child: CustomPaint(painter: RoyalLionPainter(_motion.value)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text('THE KING HAS ARRIVED', textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xffffd58b).withValues(alpha: t),
                    fontFamily: 'Cinzel', fontSize: 19,
                    fontWeight: FontWeight.w800, letterSpacing: 1.3)),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(widget.name,
                    overflow: TextOverflow.ellipsis, maxLines: 1,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: t),
                      fontWeight: FontWeight.w800, fontSize: 23),
                    textAlign: TextAlign.center),
                ),
                const SizedBox(height: 8),
                const Text('NIMZO  •  ROYAL ENTRANCE',
                  style: TextStyle(color: Color(0xffd5b581),
                    fontSize: 10, letterSpacing: 1.4)),
              ]),
            )),
            if (widget.onFinished != null)
              Positioned(
                right: 14, top: MediaQuery.paddingOf(context).top + 16,
                child: IconButton(
                  tooltip: 'Skip royal entrance',
                  onPressed: widget.onFinished,
                  icon: const Icon(Icons.close, color: Colors.white))),
          ]);
        },
      ),
    ),
  );
}

/// Genuine original NIMZO illustration: crown, mane, lion face and particles.
class RoyalLionPainter extends CustomPainter {
  const RoyalLionPainter(this.phase);
  final double phase;
  void oval(Canvas c,Rect r,Color color) =>
      c.drawOval(r,Paint()..color=color);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width/2,size.height*.50);
    canvas.scale(math.min(size.width/315,size.height/360));
    for(var i=0;i<52;i++){
      final a=i*2.39996+phase*.9;
      final r=105+(i%9)*13+6*math.sin(phase*7+i);
      oval(canvas,Rect.fromCircle(
        center:Offset(math.cos(a)*r,math.sin(a)*r),
        radius:i.isEven?1.5:2.7),
        const Color(0xffffd583).withValues(
          alpha:.20+.5*(.5+.5*math.sin(phase*8+i))));
    }
    for(var i=0;i<36;i++){
      final a=i*math.pi/18;
      final p=Path()
        ..moveTo(math.cos(a)*76,math.sin(a)*84)
        ..quadraticBezierTo(math.cos(a-.18)*112,math.sin(a-.18)*116,
            math.cos(a)*151,math.sin(a)*157)
        ..quadraticBezierTo(math.cos(a+.18)*115,math.sin(a+.18)*121,
            math.cos(a)*76,math.sin(a)*84)
        ..close();
      canvas.drawPath(p,Paint()..color=Color.lerp(
        const Color(0xff5c290f),const Color(0xffbd7428),
        .36+.3*math.sin(i*.7+phase*3).abs())!);
    }
    oval(canvas,const Rect.fromLTWH(-113,-111,226,245),
      const Color(0xff814119));
    oval(canvas,const Rect.fromLTWH(-103,-91,58,64),
      const Color(0xffdf9d4c));
    oval(canvas,const Rect.fromLTWH(45,-91,58,64),
      const Color(0xffdf9d4c));
    const face=Rect.fromLTWH(-84,-91,168,200);
    canvas.drawOval(face,Paint()..shader=const LinearGradient(
      colors:[Color(0xfffac779),Color(0xffc18138),Color(0xff865027)],
      begin:Alignment.topLeft,end:Alignment.bottomRight).createShader(face));
    oval(canvas,const Rect.fromLTWH(-65,-28,38,29),
      const Color(0xff653119));
    oval(canvas,const Rect.fromLTWH(27,-28,38,29),
      const Color(0xff653119));
    oval(canvas,const Rect.fromLTWH(-53,-18,22,13),
      const Color(0xff17231a));
    oval(canvas,const Rect.fromLTWH(31,-18,22,13),
      const Color(0xff17231a));
    oval(canvas,const Rect.fromLTWH(-44,-17,6,5),
      const Color(0xffffe3a2));
    oval(canvas,const Rect.fromLTWH(38,-17,6,5),
      const Color(0xffffe3a2));
    oval(canvas,const Rect.fromLTWH(-57,32,65,60),
      const Color(0xffffdf99));
    oval(canvas,const Rect.fromLTWH(-8,32,65,60),
      const Color(0xffffdf99));
    final nose=Path()..moveTo(-19,50)..lineTo(19,50)
      ..quadraticBezierTo(0,80,-19,50)..close();
    canvas.drawPath(nose,Paint()..color=const Color(0xff392519));
    canvas.drawLine(const Offset(0,68),const Offset(0,91),
      Paint()..color=const Color(0xff713d24)..strokeWidth=4);
    final crown=Path()
      ..moveTo(-78,-90)..lineTo(-84,-158)..lineTo(-44,-132)
      ..lineTo(-29,-183)..lineTo(0,-145)..lineTo(29,-183)
      ..lineTo(44,-132)..lineTo(84,-158)..lineTo(78,-90)..close();
    const bounds=Rect.fromLTWH(-87,-187,174,104);
    canvas.drawPath(crown,Paint()..shader=const LinearGradient(
      colors:[Color(0xffa85b19),Color(0xffffe4a0),Color(0xffd79028)],
      ).createShader(bounds));
    canvas.drawPath(crown,Paint()..color=const Color(0xffffdf82)
      ..style=PaintingStyle.stroke..strokeWidth=3);
    oval(canvas,const Rect.fromLTWH(-13,-139,26,31),
      const Color(0xffdf365b));
    canvas.restore();
  }
  @override
  bool shouldRepaint(RoyalLionPainter old)=>old.phase!=phase;
}
