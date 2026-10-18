import 'package:flutter/material.dart';

/// New gift catalog preview. Actual charging is disabled until original
/// animated media is uploaded, approved, and mapped to server catalog IDs.
class NewGiftPreviewCollection extends StatelessWidget {
  const NewGiftPreviewCollection({super.key});
  static const gifts=<({String name,int price})>[
    (name:'Romantic Blossom',price:500000),
    (name:'Ice Queen Magic',price:500000),
    (name:'Tiger Warrior',price:500000),
  ];
  @override Widget build(BuildContext context)=>Padding(
    padding:const EdgeInsets.fromLTRB(14,4,14,8),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('New Gifts - 500K each',style:TextStyle(fontWeight:FontWeight.w800,fontSize:15)),
      const SizedBox(height:5),
      const Text('Media pending. No coins charged until video and server catalog are verified.',
        style:TextStyle(fontSize:11,color:Colors.grey)),
      const SizedBox(height:8),
      SizedBox(height:90,child:ListView(scrollDirection:Axis.horizontal,children:[
        for(final gift in gifts)SizedBox(width:146,child:Card(
          margin:const EdgeInsets.only(right:8),
          color:const Color(0xff24223f),
          child:Padding(padding:const EdgeInsets.all(10),child:Column(
            crossAxisAlignment:CrossAxisAlignment.start,children:[
              const Icon(Icons.card_giftcard,color:Color(0xffffd58c),size:21),
              Text(gift.name,maxLines:1,overflow:TextOverflow.ellipsis,
                style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w700,fontSize:12)),
              Text((gift.price~/1000).toString()+'K coins - Coming Soon',
                style:const TextStyle(color:Color(0xffffd58c),fontSize:10)),
            ],
          )),
        )),
      ])),
    ]),
  );
}
