// ignore_for_file: prefer_interpolation_to_compose_strings
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'gift_artwork.dart';

/// Animates complete gift artwork, including free icons and NIMZO originals.
/// This is vector/motion artwork, not a false claim of a 3-D cinematic video.
bool hasOriginalNimzoGiftEffect(String name) =>
    originalNimzoGiftArtwork(name) != null || freeGiftArtwork(name) != null;

class NimzoCustomGiftEffect extends StatefulWidget {
  const NimzoCustomGiftEffect({
    super.key,
    required this.name,
    required this.sender,
    required this.recipient,
    required this.quantity,
    required this.onFinished,
  });
  final String name;
  final String sender, recipient;
  final int quantity;
  final VoidCallback onFinished;
  @override
  State<NimzoCustomGiftEffect> createState() => _CustomEffectState();
}

class _CustomEffectState extends State<NimzoCustomGiftEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController motion;
  Timer? _reducedMotionTimer;
  bool _finished = false;
  void _finish() {
    if (_finished || !mounted) return;
    _finished = true;
    _reducedMotionTimer?.cancel();
    widget.onFinished();
  }
  @override
  void initState() {
    super.initState();
    final premium = const [
      'golden palace','private jet','luxury yacht',
      'dragon','golden dragon','phoenix',
    ].contains(widget.name.toLowerCase());
    motion = AnimationController(
      vsync:this,
      duration:Duration(milliseconds:premium?5400:3500),
    )..addStatusListener((status) {
      if(status==AnimationStatus.completed) _finish();
    });
  }
  @override
  void didChangeDependencies(){
    super.didChangeDependencies();
    if(MediaQuery.disableAnimationsOf(context)){
      motion.stop();
      // Avoid firing onFinished synchronously during parent build.
      motion.value=.999;
      // Keep a readable static frame briefly, then unblock the playback queue.
      _reducedMotionTimer ??= Timer(const Duration(milliseconds: 1200), _finish);
    }else if(motion.status==AnimationStatus.dismissed){
      motion.forward();
    }
  }
  @override
  void dispose(){ _reducedMotionTimer?.cancel(); motion.dispose(); super.dispose(); }

  bool get isPhoenix => widget.name.trim().toLowerCase() == 'phoenix';

  Color get accent => switch(widget.name.toLowerCase()){
    'heart'||'kiss'||'birthday cake'||'teddy bear'=>
      const Color(0xffff6784),
    'phoenix'=>const Color(0xffffc96a),
    'cat'||'panda'||'coffee'=>const Color(0xffa7f2d4),
    'private jet'||'luxury yacht'||'dragon'=>const Color(0xff5bdeee),
    'crown'||'diamond'||'golden palace'||'golden dragon'||'diamond ring'=>
      const Color(0xffffcf78),
    _=>const Color(0xfffad8a6),
  };

  Offset motionOffset(double t){
    final eased=Curves.easeOutCubic.transform(t.clamp(0.0,1.0));
    switch(widget.name.toLowerCase()){
      case 'private jet': return Offset((eased-1)*350,-90*math.sin(t*math.pi));
      case 'luxury yacht': return Offset((eased-1)*220,8*math.sin(t*math.pi*4));
      case 'dragon':return Offset((1-eased)*290,-65*math.sin(t*math.pi));
      case 'golden dragon':return Offset((eased-1)*300,-72*math.sin(t*math.pi*1.2));
      case 'phoenix':return Offset(0,(1-eased)*135-25*math.sin(t*math.pi*2));
      case 'coffee':return Offset(0,(1-eased)*160);
      case 'birthday cake':
      case 'gift box':return Offset(0,32*math.sin(t*math.pi*4)*(1-t));
      case 'cat':
      case 'panda': return Offset(14*math.sin(t*math.pi*4),0);
      case 'kiss':return Offset(0,-30*math.sin(t*math.pi));
      case 'rose':return Offset(18*math.sin(t*math.pi*3),-54*t);
      case 'heart':return Offset(0,-18*math.sin(t*math.pi*2));
      case 'crown':return Offset(0,-28*math.sin(t*math.pi));
      case 'diamond':return Offset(9*math.sin(t*math.pi*4),0);
      default:return Offset(0,(1-eased)*48);
    }
  }

  double turn(double t)=>switch(widget.name.toLowerCase()){
    'diamond ring'||'diamond'=>.30*math.sin(t*math.pi*4),
    'rose'=>.22*math.sin(t*math.pi*3),
    'heart'=>.12*math.sin(t*math.pi*4),
    'crown'=>.07*math.sin(t*math.pi*2),
    'dragon'||'golden dragon'=>.18*math.sin(t*math.pi*2),
    'phoenix'=>.13*math.sin(t*math.pi*3),
    'teddy bear'=>.11*math.sin(t*math.pi*3),
    _=>.045*math.sin(t*math.pi*3),
  };

  @override
  Widget build(BuildContext context)=>Material(
    color:Colors.transparent,
    child:SafeArea(
      child:AnimatedBuilder(animation:motion,builder:(context,_){
        final t=motion.value;
        final opacity=math.min(1.0,t*4.5);
        final ease=Curves.easeOutBack.transform(t.clamp(0.0,1.0));
        return Stack(children:[
          Positioned.fill(child:DecoratedBox(
            decoration:BoxDecoration(gradient:RadialGradient(
              center:const Alignment(0,-.2),radius:1.3,
              colors:[
                (isPhoenix?const Color(0xff78331b):accent)
                    .withValues(alpha:.38*opacity),
                const Color(0xff040f12).withValues(alpha:.96*opacity),
              ],
            )))),
          if(isPhoenix) Positioned.fill(child:IgnorePointer(
            child:CustomPaint(painter:_RoyalPhoenixAura(t)))),
          Positioned.fill(child:IgnorePointer(
            child:CustomPaint(painter:_GiftMotionParticles(t,accent)))),
          Center(child:ConstrainedBox(
            constraints:const BoxConstraints(maxWidth:370),
            child:Column(mainAxisSize:MainAxisSize.min,children:[
              Opacity(opacity:opacity,
                child:Transform.translate(
                  offset:motionOffset(t),
                  child:Transform.rotate(
                    angle:turn(t),
                    child:Transform.scale(
                      scale:(.55+.45*ease).clamp(.05,1.5),
                      child:SizedBox(
                        height:270,width:270,
                        child:RepaintBoundary(
                          child:GiftArtwork(name:widget.name)),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height:16),
              Text(widget.name.toUpperCase(),
                maxLines:1,overflow:TextOverflow.ellipsis,
                style:TextStyle(color:accent,
                  fontFamily:'Cinzel',fontSize:23,
                  letterSpacing:1.3,fontWeight:FontWeight.w800)),
              const SizedBox(height:8),
              Padding(padding:const EdgeInsets.symmetric(horizontal:16),
                child:Text(widget.sender+' sent '+
                  widget.name+' × '+widget.quantity.toString()+
                  ' to '+widget.recipient,
                  maxLines:2,overflow:TextOverflow.ellipsis,
                  textAlign:TextAlign.center,
                  style:const TextStyle(color:Colors.white,
                    fontWeight:FontWeight.w600,fontSize:14))),
              const SizedBox(height:8),
              Text(isPhoenix ? 'ROYAL FLAME  ·  NIMZO' : 'NIMZO EXCLUSIVE',
                style:const TextStyle(color:Color(0xffb3c5bc),
                  letterSpacing:2,fontSize:10)),
            ]),
          )),
          Positioned(right:12,top:7,
            child:IconButton(
              onPressed:widget.onFinished,
              tooltip:'Skip gift animation',
              icon:const Icon(Icons.close,color:Colors.white))),
        ]);
      }),
    ),
  );
}

/// A warm light stage for Phoenix. The bird illustration is the real art;
/// no unrelated animation is substituted, and all rendering is muted.
class _RoyalPhoenixAura extends CustomPainter {
  const _RoyalPhoenixAura(this.phase);
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 55);
    final radius = math.min(size.width * .56, size.height * .43);
    final rise = Curves.easeOutCubic.transform(phase.clamp(0.0, 1.0));
    final fade = (1 - math.max(0, phase - .83) / .17).clamp(0.0, 1.0);
    final bounds = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center, radius,
      Paint()..shader = RadialGradient(
        colors: [
          const Color(0xffffce75).withValues(alpha: .28 * rise * fade),
          const Color(0xffde521d).withValues(alpha: .16 * rise * fade),
          const Color(0xff7f2713).withValues(alpha: 0),
        ],
      ).createShader(bounds),
    );
    for (var ring = 0; ring < 3; ring++) {
      final r = radius * (.48 + ring * .22) +
          8 * math.sin(phase * math.pi * 2 + ring);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        -math.pi / 2 + phase * (ring.isEven ? 1.6 : -1.3) + ring,
        math.pi * (1.1 - ring * .13),
        false,
        Paint()
          ..color = const Color(0xffffca6a)
              .withValues(alpha: (.42 - ring * .12) * rise * fade)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.7 + (2 - ring) * .4,
      );
    }
    for (var i = 0; i < 42; i++) {
      final angle = i * 2.399963;
      final lifetime = (phase * 1.7 + i / 42) % 1;
      final spread = 44 + lifetime * radius * .95;
      final x = center.dx + math.cos(angle) * spread * .75;
      final y = center.dy + math.sin(angle) * spread * .56 -
          66 * lifetime;
      final alpha = ((1 - lifetime) * .65 * fade).clamp(0.0, 1.0);
      final end = Offset(x, y - (4 + 13 * (1 - lifetime)));
      canvas.drawLine(
        Offset(x, y), end,
        Paint()
          ..color = const Color(0xffffbb53).withValues(alpha: alpha)
          ..strokeWidth = i.isEven ? 1.9 : 1.1
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RoyalPhoenixAura old) => old.phase != phase;
}

/// Light motes and graceful travel lines; no large pink '+' placeholders.
class _GiftMotionParticles extends CustomPainter {
  const _GiftMotionParticles(this.phase, this.color);
  final double phase;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 38);
    final travel = math.min(size.width, size.height) * .44;
    final fade = (1 - math.max(0, phase - .84) / .16).clamp(0.0, 1.0);
    for (var i = 0; i < 56; i++) {
      final theta = i * 2.399963 + phase * (i.isEven ? 1.2 : -.85);
      final age = (phase * 1.3 + i / 56) % 1;
      final distance = 25 + age * travel;
      final point = center + Offset(
        math.cos(theta) * distance, math.sin(theta) * distance,
      );
      final alpha = ((1 - age) * .77 * fade).clamp(0.0, 1.0);
      final length = 3 + (1 - age) * (i.isEven ? 12 : 6);
      canvas.drawLine(
        point.translate(-math.cos(theta) * length,
            -math.sin(theta) * length),
        point,
        Paint()
          ..color = color.withValues(alpha: alpha)
          ..strokeWidth = i.isEven ? 2.0 : 1.2
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(
        point, i.isEven ? 2.0 : 1.0,
        Paint()..color = const Color(0xfffff2d1).withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(_GiftMotionParticles old) =>
      old.phase != phase || old.color != color;
}
