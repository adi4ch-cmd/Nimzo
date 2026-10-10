// ignore_for_file: prefer_interpolation_to_compose_strings
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'gift_artwork.dart';

/// Animates only original, individually illustrated NIMZO gift names.
/// This is vector/motion artwork, not a false claim of a 3-D cinematic video.
bool hasOriginalNimzoGiftEffect(String name) =>
    originalNimzoGiftArtwork(name) != null;

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
      if(status==AnimationStatus.completed) widget.onFinished();
    });
  }
  @override
  void didChangeDependencies(){
    super.didChangeDependencies();
    if(MediaQuery.disableAnimationsOf(context)){
      motion.stop();
      motion.value=1;
    }else if(motion.status==AnimationStatus.dismissed){
      motion.forward();
    }
  }
  @override
  void dispose(){ motion.dispose(); super.dispose(); }

  Color get accent => switch(widget.name.toLowerCase()){
    'kiss'||'birthday cake'||'teddy bear'||'phoenix'=>
      const Color(0xffff6784),
    'cat'||'panda'||'coffee'=>const Color(0xffa7f2d4),
    'private jet'||'luxury yacht'||'dragon'=>const Color(0xff5bdeee),
    'golden palace'||'golden dragon'||'diamond ring'=>
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
      default:return Offset(0,(1-eased)*48);
    }
  }

  double turn(double t)=>switch(widget.name.toLowerCase()){
    'diamond ring'=>.30*math.sin(t*math.pi*4),
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
          Positioned.fill(child:ColoredBox(
            color:const Color(0xff030c12).withValues(alpha:.88*opacity))),
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
              const Text('NIMZO EXCLUSIVE',
                style:TextStyle(color:Color(0xffb3c5bc),
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

class _GiftMotionParticles extends CustomPainter {
  const _GiftMotionParticles(this.phase,this.color);
  final double phase;
  final Color color;
  @override
  void paint(Canvas canvas,Size size){
    final center=Offset(size.width/2,size.height/2-38);
    final s=math.min(size.width,size.height);
    for(var i=0;i<56;i++){
      final angle=i*2.399963+phase*(i.isEven?1.9:-1.1);
      final age=(phase*1.25+i/56)%1;
      final radius=30+(age*s*.45);
      final p=center+Offset(math.cos(angle)*radius,
        math.sin(angle)*radius);
      final alpha=((1-age)*.88).clamp(0.0,1.0);
      final paint=Paint()
        ..color=color.withValues(alpha:alpha)
        ..strokeWidth=i.isEven?2.5:1.6
        ..strokeCap=StrokeCap.round;
      final line=3.5+(1-age)*8;
      canvas.drawLine(p.translate(-line,0),p.translate(line,0),paint);
      canvas.drawLine(p.translate(0,-line),p.translate(0,line),paint);
    }
  }
  @override
  bool shouldRepaint(_GiftMotionParticles old)=>
      old.phase!=phase||old.color!=color;
}
