import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

/// Client-only interactive demo. Never debits coins or creates a paid wager.
class LockedGameDemo extends StatefulWidget {
  const LockedGameDemo({super.key, required this.slug, this.roomControls, this.onClose, this.onMinimize, this.onExpand, this.expanded=false});
  final String slug;
  final Widget? roomControls;
  final VoidCallback? onClose, onMinimize, onExpand;
  final bool expanded;
  @override State<LockedGameDemo> createState()=>_LockedGameDemoState();
}
class _LockedGameDemoState extends State<LockedGameDemo> {
  static const gold=Color(0xffffd78a);
  static const lionMult=[5,5,5,5,10,15,25,45], wheelMult=[2,8,2];
  static const lionNames=['Tomato','Mushroom','Onion','Shaljam','Pizza','Meat','Fish','Jinga'];
  static const wheelNames=['Left 2x','Lucky 8x','Right 2x'];
  static const lionChips=[5000,10000,50000,300000,1000000];
  static const wheelChips=[5000,10000,50000,300000,500000,1000000];
  final Map<int,int> bets={};
  int chipIndex=0, seconds=20, round=1;
  int? example;
  bool autoplay=false;
  Timer? timer;
  bool get lion=>widget.slug=='grady_lion';
  List<int> get mult=>lion?lionMult:wheelMult;
  List<String> get names=>lion?lionNames:wheelNames;
  List<int> get chips=>lion?lionChips:wheelChips;
  int get total=>bets.values.fold(0,(int a,int b)=>a+b);
  @override void initState(){
    super.initState();
    if(lion)timer=Timer.periodic(const Duration(seconds:1),(_){
      if(!mounted)return;
      setState((){
        if(seconds<=1){result();}else{seconds--;}
      });
    });
  }
  void result(){
    example=Random.secure().nextInt(mult.length);
    round++;seconds=20;
    if(!autoplay)bets.clear();
  }
  String pretty(int n)=>n>=1000000?(n/1000000).toStringAsFixed(n%1000000==0?0:1)+'M':n>=1000?(n~/1000).toString()+'K':n.toString();
  void select(int index){
    if(!bets.containsKey(index)&&bets.length>=(lion?6:2)){
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(lion?'Maximum 6 options':'Maximum 2 options')));
      return;
    }
    if(!lion&&index!=1&&bets.keys.any((n)=>n!=1&&n!=index)){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Cannot combine both 2x selections')));
      return;
    }
    setState(()=>bets[index]=(bets[index]??0)+chips[chipIndex]);
  }
  @override void dispose(){timer?.cancel();super.dispose();}
  @override Widget build(BuildContext context)=>Scaffold(
    backgroundColor:const Color(0xff130a29),
    appBar:AppBar(
      backgroundColor:const Color(0xff29134d),
      foregroundColor:Colors.white,
      title:Text(lion?'Grady Lion':'Lucky Wheel 77'),
      leading:widget.onClose==null?null:IconButton(onPressed:widget.onClose,icon:const Icon(Icons.close)),
      actions:[
        if(widget.onExpand!=null)IconButton(onPressed:widget.onExpand,icon:Icon(widget.expanded?Icons.fullscreen_exit:Icons.fullscreen)),
        if(widget.onMinimize!=null)IconButton(onPressed:widget.onMinimize,icon:const Icon(Icons.picture_in_picture_alt)),
      ],
    ),
    bottomNavigationBar:widget.roomControls,
    body:SafeArea(child:ListView(padding:const EdgeInsets.all(12),children:[
      Container(padding:const EdgeInsets.all(15),
        decoration:BoxDecoration(color:const Color(0xff372354),borderRadius:BorderRadius.circular(14),border:Border.all(color:gold)),
        child:Column(children:[
          const Text('INTERACTIVE DEMO - NO COINS DEDUCTED',style:TextStyle(color:gold,fontWeight:FontWeight.bold)),
          const SizedBox(height:6),
          Text(lion?'20s demo rounds - max 6 selections':'2x / 8x / 2x - max 2 selections',style:const TextStyle(color:Colors.white)),
          Text('Round '+round.toString()+(lion?' - '+seconds.toString()+' sec':''),style:const TextStyle(color:Colors.white70)),
        ]),
      ),
      const SizedBox(height:12),
      if(!lion)const Center(child:Text('LUCKY 77',style:TextStyle(color:gold,fontSize:28,fontWeight:FontWeight.w900))),
      GridView.builder(
        shrinkWrap:true,
        physics:const NeverScrollableScrollPhysics(),
        gridDelegate:SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount:lion?4:3,childAspectRatio:lion?.70:.78,crossAxisSpacing:6,mainAxisSpacing:6),
        itemCount:mult.length,
        itemBuilder:(context,index){
          final selected=bets.containsKey(index);
          return Material(
            color:selected?const Color(0xff514080):const Color(0xff261946),
            borderRadius:BorderRadius.circular(12),
            child:InkWell(key:ValueKey(widget.slug+'-demo-option-'+index.toString()),onTap:()=>select(index),child:Container(
              decoration:BoxDecoration(borderRadius:BorderRadius.circular(12),
                border:Border.all(color:selected?gold:const Color(0xff705b94),width:selected?2:1)),
              child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
                if(lion)Expanded(child:Image.asset('assets/reference/grady/'+index.toString()+'.jpg',
                  fit:BoxFit.contain,errorBuilder:(_,__,___)=>const Icon(Icons.casino,color:gold)))
                else Icon(index==1?Icons.stars:Icons.bolt,color:gold,size:40),
                Text(names[index],maxLines:1,overflow:TextOverflow.ellipsis,
                  style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold,fontSize:11)),
                Text(mult[index].toString()+'x',style:const TextStyle(color:gold,fontSize:20,fontWeight:FontWeight.bold)),
                if(selected)Text(pretty(bets[index]!),style:const TextStyle(color:Color(0xff93fbe3),fontSize:10)),
              ]),
            )),
          );
        },
      ),
      if(example!=null)Padding(padding:const EdgeInsets.all(10),
        child:Text('Example outcome: '+names[example!]+' (not a real wager)',style:const TextStyle(color:gold),textAlign:TextAlign.center)),
      const SizedBox(height:14),
      const Text('DEMO CHIPS',style:TextStyle(color:Colors.white70)),
      SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
        for(var i=0;i<chips.length;i++)Padding(padding:const EdgeInsets.only(right:7),
          child:ChoiceChip(
            key:ValueKey(widget.slug+'-chip-'+i.toString()),
            selected:chipIndex==i,label:Text(pretty(chips[i])),
            onSelected:(_)=>setState(()=>chipIndex=i),
            showCheckmark:false,selectedColor:gold,backgroundColor:const Color(0xff56448a),
            labelStyle:TextStyle(color:chipIndex==i?const Color(0xff28154e):Colors.white),
          )),
      ])),
      const SizedBox(height:10),
      Text('Selected: '+bets.length.toString()+' - Demo total: '+pretty(total),
        style:const TextStyle(color:gold,fontWeight:FontWeight.bold)),
      const SizedBox(height:10),
      Wrap(spacing:8,children:[
        OutlinedButton(onPressed:()=>setState(bets.clear),child:const Text('Clear')),
        OutlinedButton(onPressed:()=>setState(()=>autoplay=!autoplay),
          child:Text((lion?'Auto Play ':'Auto Repeat ')+(autoplay?'ON':'OFF'))),
        if(!lion)FilledButton(onPressed:()=>setState(result),child:const Text('Demo Result')),
      ]),
      const SizedBox(height:14),
      const Text('Preview only. No paid betting, balance changes or actual winnings.',
        style:TextStyle(color:Colors.white60,fontSize:12),textAlign:TextAlign.center),
    ])),
  );
}
