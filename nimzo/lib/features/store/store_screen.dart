import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/supabase_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/master_ui.dart';
import '../profile/profile_collections.dart';
import 'store_badge.dart';
import '../wallet/wallet_screen.dart';
import 'store_repository.dart';

class RoyalStoreScreen extends ConsumerStatefulWidget {
  const RoyalStoreScreen({super.key});
  @override
  ConsumerState<RoyalStoreScreen> createState()=>_RoyalStoreScreenState();
}

class _RoyalStoreScreenState extends ConsumerState<RoyalStoreScreen> {
  bool bag = false;
  String? busy;
  String? pendingKey;
  String? pendingItem;

  void refresh(String id) {
    ref.invalidate(royalBagProvider(id));
    ref.invalidate(walletProvider);
    ref.invalidate(profileCollectionProvider((id,ProfileCollection.medal)));
    ref.invalidate(equippedRoyalMedalProvider(id));
  }

  Future<void> purchase(RoyalStoreItem item, String id) async {
    if (busy != null) return;
    final confirmed = await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:Text('Buy ${item.name}?'),
      content:Text('${compactNumber(item.price)} coins will be deducted once. The medal is permanent.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Buy'))]));
    if (confirmed != true || !mounted) return;
    setState(()=>busy=item.id);
    if (pendingItem != item.id) {
      pendingItem=item.id;
      pendingKey=ref.read(royalStoreRepositoryProvider).newPurchaseKey();
    }
    try {
      await ref.read(royalStoreRepositoryProvider).buy(item.id,pendingKey!);
      if (!mounted) return;
      pendingItem=null;
      pendingKey=null;
      refresh(id);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Purchased. Find it in your Bag.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:Text('Purchase not confirmed: $e. Retry the same item to check.'),
      ));
    } finally {if(mounted) setState(()=>busy=null);}
  }

  Future<void> equip(String id,String itemId) async {
    if (busy!=null) return;
    setState(()=>busy=itemId);
    try {
      await ref.read(royalStoreRepositoryProvider).equip(itemId);
      if (!mounted) return;
      refresh(id);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Medal equipped on your profile.')));
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Could not equip medal: $e')));
    } finally {if(mounted) setState(()=>busy=null);}
  }

  Widget artwork(String path) => Image.asset(path,width:66,height:66,fit:BoxFit.contain,
    errorBuilder:(_,__,___)=>const Icon(Icons.image_not_supported_outlined,size:46));

  @override
  Widget build(BuildContext context) {
    final id=ref.watch(currentUserIdProvider);
    return Scaffold(
      appBar:AppBar(title:const Text('NIMZO Royal Store')),
      body:id==null ? const Center(child:Text('Sign in to use the Store.')) :
      RefreshIndicator(onRefresh:() async {
        ref.invalidate(royalCatalogProvider);
        refresh(id);
        await ref.read(royalCatalogProvider.future);
      },child:ListView(padding:const EdgeInsets.all(16),children:[
        Row(children:[
          Expanded(child:Text('Royal Collection',style:Theme.of(context).textTheme.titleLarge)),
          TextButton.icon(onPressed:()=>context.push('/wallet'),
            icon:const Icon(Icons.account_balance_wallet_outlined),label:const Text('Wallet')),
        ]),
        ref.watch(walletProvider).when(
          data:(balance)=>Text('${compactNumber(balance.coins)} coins available',
            style:const TextStyle(color:NimzoStyle.primary,fontWeight:FontWeight.w700)),
          loading:()=>const LinearProgressIndicator(),
          error:(_,__)=>const Text('Wallet balance unavailable')),
        const SizedBox(height:12),
        SegmentedButton<bool>(segments:const [
          ButtonSegment(value:false,label:Text('Store'),icon:Icon(Icons.storefront_outlined)),
          ButtonSegment(value:true,label:Text('My Bag'),icon:Icon(Icons.inventory_2_outlined)),
        ],selected:{bag},onSelectionChanged:(v)=>setState(()=>bag=v.first)),
        const SizedBox(height:18),
        if(!bag)
          ref.watch(royalCatalogProvider).when(
            loading:()=>const Center(child:CircularProgressIndicator()),
            error:(e,_)=>_error(e,()=>ref.invalidate(royalCatalogProvider)),
            data:(items)=>items.isEmpty?const Text('No Royal collectibles on sale.'):
              FutureBuilder<List<RoyalBagItem>>(
                future:ref.watch(royalBagProvider(id).future),
                builder:(ctx,snapshot){
                  if(snapshot.hasError) return _error(snapshot.error!,()=>ref.invalidate(royalBagProvider(id)));
                  if(!snapshot.hasData) return const Center(child:CircularProgressIndicator());
                  final owned=snapshot.data!.map((x)=>x.id).toSet();
                  return _grid([
                    for(final item in items) _card(item.name,item.image,
                      '${compactNumber(item.price)} coins',
                      owned.contains(item.id)?'Owned':'Buy',
                      owned.contains(item.id)||busy!=null?null:()=>purchase(item,id)),
                  ]);
                }),
          )
        else ref.watch(royalBagProvider(id)).when(
          loading:()=>const Center(child:CircularProgressIndicator()),
          error:(e,_)=>_error(e,()=>ref.invalidate(royalBagProvider(id))),
          data:(items)=>items.isEmpty?const Text('Your Bag is empty. Buy a Royal collectible in Store.'):
            _grid([
              for(final item in items) _card(item.name,item.image,
                item.equipped?'Visible on profile':'Owned permanently',
                item.equipped?'Equipped':'Equip',
                item.equipped||busy!=null?null:()=>equip(id,item.id))
            ])),
      ])),
    );
  }

  Widget _error(Object error,VoidCallback retry)=>Column(children:[
    Text('Store data unavailable: $error'),
    TextButton(onPressed:retry,child:const Text('Retry')),
  ]);

  Widget _grid(List<Widget> cards)=>LayoutBuilder(builder:(context,constraints){
    final columns=constraints.maxWidth>=650?3:2;
    return GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),
      crossAxisCount:columns,childAspectRatio:.77,crossAxisSpacing:12,mainAxisSpacing:12,
      children:cards);
  });

  Widget _card(String name,String image,String detail,String action,VoidCallback? onTap)=>
    Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(
      color:Theme.of(context).cardColor,borderRadius:BorderRadius.circular(18),
      border:Border.all(color:const Color(0xffd8b36b))),
      child:Column(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
        Expanded(child:Center(child:artwork(image))),
        Text(name,maxLines:1,overflow:TextOverflow.ellipsis,
          style:const TextStyle(fontWeight:FontWeight.w700)),
        Text(detail,maxLines:2,textAlign:TextAlign.center,
          style:const TextStyle(fontSize:11)),
        const SizedBox(height:4),
        SizedBox(width:double.infinity,child:FilledButton(
          onPressed:onTap,child:Text(busy!=null&&onTap!=null?'Working…':action))),
      ]));
}
