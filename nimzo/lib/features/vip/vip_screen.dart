// ignore_for_file: prefer_interpolation_to_compose_strings
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/formatters.dart';
import '../../core/providers/supabase_provider.dart';
import '../../core/errors/error_handler.dart';
import '../profile/profile_repository.dart';
import 'vip_repository.dart';
import 'vip_tiers.dart';
import 'vip_presentation.dart';
import 'royal_lion_entry.dart';

final membershipNameProvider = FutureProvider<String?>((ref) async {
  final id = ref.watch(currentUserIdProvider);
  if (id == null) return null;
  final profile = await ref.watch(profileProvider(id).future);
  return profile.displayName ?? profile.username;
});

class VipScreen extends ConsumerStatefulWidget {
  final bool svip;
  const VipScreen({super.key, this.svip = false});
  @override
  ConsumerState<VipScreen> createState() => _VipState();
}

class _VipState extends ConsumerState<VipScreen> {
  int tier = 5;
  bool _membershipSelected = false;
  bool _purchasing = false;
  String? _purchaseKey;
  String get family => widget.svip ? 'SVIP' : 'VIP';
  Color get accent => widget.svip
      ? const Color(0xffecae70) : const Color(0xff7be6b8);
  Color get surface => widget.svip
      ? const Color(0xff21131a) : const Color(0xff102b24);

  Future<void> _buyNormalVip() async {
    if (_purchasing || widget.svip) return;
    final selected = tier;
    final cost = NimzoVipTiers.normalVipCoins[selected - 1];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Activate VIP ' + selected.toString()),
        content: Text('Pay ' + compactNumber(cost) +
            ' coins for 30 days of VIP membership? ' +
            'Your balance will be debited by the secure server.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm with coins'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _purchasing = true);
    // Keep this idempotency key for uncertain network retries.
    _purchaseKey ??=
        'vip-' + DateTime.now().microsecondsSinceEpoch.toString() +
        '-' + selected.toString();
    try {
      await ref.read(vipRepositoryProvider).purchaseNormalVip(
        tier: selected, key: _purchaseKey!,
      );
      _purchaseKey = null;
      ref.invalidate(vipStatusProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('VIP ' + selected.toString() +
          ' verified by NIMZO server')),
      );
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().toLowerCase().contains('insufficient coins')
          ? 'Not enough coins for this VIP tier.'
          : mapError(error).message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  void _selectTier(int nextTier) {
    if (nextTier == tier) return;
    setState(() {
      tier = nextTier;
      _membershipSelected = true;
      _purchaseKey = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(vipStatusProvider);
    final progress = widget.svip
        ? ref.watch(svipProgressProvider).valueOrNull : null;
    final active = status.valueOrNull?[
      widget.svip ? 'svip_level' : 'vip_level'
    ];
    if (!_membershipSelected && active is num &&
        active >= 1 && active <= 10) {
      _membershipSelected = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => tier = active.toInt());
      });
    }
    final name = ref.watch(membershipNameProvider).valueOrNull ??
      'Your NIMZO identity';
    final label = status.isLoading
        ? 'Loading membership…'
        : status.hasError
            ? 'Membership unavailable'
            : active is num && active > 0
                ? 'Active · ' + family + ' ' + active.toString()
                : 'No active ' + family + ' membership';
    final price = NimzoVipTiers.normalVipCoins[tier - 1];
    final usd = NimzoVipTiers.svipRechargeUsd[tier - 1] * 100;
    final threshold = progress?.thresholdFor(tier);
    return Theme(
      data: Theme.of(context).copyWith(
        iconTheme: const IconThemeData(color: Colors.white),
        textTheme: Theme.of(context).textTheme.apply(
          bodyColor: Colors.white, displayColor: Colors.white,
          fontFamily: 'Poppins',
        ),
      ),
      child: Scaffold(
        backgroundColor: widget.svip
            ? const Color(0xff0e0a0d) : const Color(0xff071a15),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: accent,
          title: Text(widget.svip
            ? 'NIMZO · SVIP COLLECTION'
            : 'NIMZO · ROYAL VIP',
            style: TextStyle(
              color:accent, fontSize:15, fontWeight:FontWeight.w800,
              letterSpacing:.8)),
          centerTitle: true,
        ),
        body: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 22, 16, 24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: accent.withValues(alpha: .45)),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: widget.svip
                        ? [const Color(0xff402529),
                           const Color(0xff100c13)]
                        : [const Color(0xff1c5540),
                           const Color(0xff0c2820)],
                    ),
                  ),
                  child: Column(children: [
                    Text(widget.svip
                      ? 'DIAMOND MEMBERSHIP'
                      : 'THE ROYAL COLLECTION',
                      style: TextStyle(
                        color: accent,
                        fontSize: 11, letterSpacing: 2.1,
                        fontWeight: FontWeight.w700)),
                    const SizedBox(height: 14),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: MembershipEmblem(
                        key: ValueKey(family + '-' + tier.toString()),
                        level: tier, svip: widget.svip, size: 154),
                    ),
                    const SizedBox(height: 12),
                    Text(family + ' ' + tier.toString(),
                      style: const TextStyle(
                        fontFamily: 'Cinzel', fontSize: 30,
                        letterSpacing: 1.4, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xff061913),
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(color: accent.withValues(alpha: .35))),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,horizontal: 18),
                        child: Text(label, style: TextStyle(
                          color: accent, fontSize: 12))),
                    ),
                  ]),
                ),
                const SizedBox(height: 22),
                Text('EXPLORE THE COLLECTION',
                  style: TextStyle(
                    color: accent, letterSpacing: 1.4,
                    fontWeight: FontWeight.w800, fontSize: 12)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 114,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: 10,
                    separatorBuilder: (_, __) => const SizedBox(width: 9),
                    itemBuilder: (context, i) {
                      final n = i + 1;
                      return Semantics(
                        selected: tier == n, button: true,
                        label: family + ' ' + n.toString(),
                        child: InkWell(
                          key: ValueKey(
                            (widget.svip ? 'svip' : 'vip') + '-tier-' + n.toString()),
                          onTap: () => _selectTier(n),
                          borderRadius: BorderRadius.circular(16),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 210),
                            width: 82,
                            padding: const EdgeInsets.fromLTRB(5,8,5,5),
                            decoration: BoxDecoration(
                              color: tier == n ? surface : const Color(0xff14231f),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: tier == n ? accent :
                                  accent.withValues(alpha: .18)),
                            ),
                            child: Column(children: [
                              MembershipEmblem(
                                level: n,svip:widget.svip,
                                small:true,size:67),
                              const SizedBox(height: 3),
                              Text(family + ' ' + n.toString(),
                                style: TextStyle(
                                  fontSize: 10, color: tier == n
                                    ? accent : const Color(0xffb3c3bb))),
                            ]),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),
                _card(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text(
                        family + ' ' + tier.toString() + ' · Collection preview',
                        style: TextStyle(color: accent,
                          fontWeight: FontWeight.w700))),
                      Text(widget.svip && threshold != null
                        ? 'Configured tier' : 'Preview',
                        style: const TextStyle(
                          color: Color(0xffa7b9af),fontSize: 11)),
                    ]),
                    const SizedBox(height: 10),
                    Text(widget.svip
                      ? threshold != null
                        ? 'Recorded threshold: ' + _usd(threshold)
                        : 'Reference recharge: ' + _usd(usd)
                      : compactNumber(price) + ' coins / 30 days',
                      style: const TextStyle(
                        fontSize: 22,fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    Text(widget.svip
                      ? 'Ten original SVIP medals are installed. Active membership and rewards depend on your server-verified account status.'
                      : 'Premium tier purchase is processed by the NIMZO server. Selecting a tier here never grants membership.',
                      style: const TextStyle(
                        color: Color(0xffa7b9af),fontSize: 12)),
                  ],
                )),
                if (widget.svip) ...[
                  _heading('Verified recharge progress'),
                  _card(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(progress == null ? 'Recharge progress unavailable' :
                        'Recorded cycle · ' + _usd(progress.cycleCents),
                        style: TextStyle(color:accent)),
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        value:progress?.fraction ?? 0,minHeight:6,
                        color:accent,backgroundColor:const Color(0xff39262a)),
                      const SizedBox(height: 10),
                      Text(progress == null
                        ? 'Sign in to retrieve server membership.'
                        : progress.nextLevel == null
                          ? 'Highest configured tier reached.'
                          : 'Next SVIP ' + progress.nextLevel.toString() +
                            ' · ' + _usd(progress.nextThresholdCents!),
                        style: const TextStyle(
                          color:Color(0xffa7b9af),fontSize:12)),
                    ],
                  )),
                ],
                _heading('Your premium identity'),
                _card(child: Row(children: [
                  MembershipEmblem(
                    level:tier,svip:widget.svip,size:80),
                  const SizedBox(width:16),
                  Expanded(child:Column(
                    crossAxisAlignment:CrossAxisAlignment.start,
                    children:[
                      Text(name,style:const TextStyle(
                        fontWeight:FontWeight.w700)),
                      const SizedBox(height:5),
                      Text(family + ' ' + tier.toString() + ' · NIMZO',
                        style:TextStyle(color:accent)),
                      const SizedBox(height:5),
                      Text(active == tier
                        ? 'Server-verified active membership'
                        : 'Tier preview; no activated cosmetics',
                        style:const TextStyle(
                          color:Color(0xffa7b9af),fontSize:11)),
                    ],
                  )),
                ])),
                if (!widget.svip && tier == 10) ...[
                  _heading('Royal Lion entrance preview'),
                  _card(child: Column(children: [
                    const SizedBox(height: 350,
                      child: RoyalLionEntry(name: 'NIMZO KING')),
                    const SizedBox(height: 8),
                    Text('Original Royal Lion · 5.5-second room arrival',
                      style:TextStyle(color:accent,fontSize:13)),
                    const SizedBox(height: 8),
                    const Text(
                      'Room entry requires a live server-verified VIP benefit. Preview does not activate it.',
                      textAlign:TextAlign.center,
                      style:TextStyle(
                        color:Color(0xffa7b9af),fontSize:12)),
                  ])),
                ],
                _heading('Your privileges'),
                _benefit(Icons.workspace_premium_outlined,
                  'New royal profile emblem',
                  'NIMZO original VIP identity, not an old reference image.'),
                _benefit(Icons.verified_user_outlined,
                  'Secure membership status',
                  'Eligibility is verified from your account on the server.'),
                if (!widget.svip)
                  _benefit(Icons.auto_awesome_outlined,
                    'Royal Lion room entry',
                    'A genuine eligible room join triggers one entrance.'),
                if (widget.svip)
                  _benefit(Icons.card_giftcard_outlined,
                    'SVIP weekly rewards',
                    'Rewards depend on your server-verified account status.'),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top:false,
          child: Padding(
            padding:const EdgeInsets.fromLTRB(16,8,16,12),
            child:ConstrainedBox(
              constraints:const BoxConstraints(maxWidth:700),
              child: SizedBox(
                height:54,
                child: FilledButton(
                  onPressed: widget.svip
                    ? () => context.push('/recharge')
                    : (status.isLoading || status.hasError || _purchasing)
                      ? null : _buyNormalVip,
                  style:FilledButton.styleFrom(
                    backgroundColor:accent,
                    foregroundColor:const Color(0xff09251c),
                    shape:RoundedRectangleBorder(
                      borderRadius:BorderRadius.circular(16))),
                  child:Text(widget.svip
                    ? 'View recharge options'
                    : _purchasing
                      ? 'Confirming securely…'
                      : 'Activate VIP ' + tier.toString() +
                        ' · ' + compactNumber(price) + ' coins',
                    style:const TextStyle(fontWeight:FontWeight.w800)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: accent.withValues(alpha: .22)),
    ),
    child: child,
  );
  Widget _heading(String value) => Padding(
    padding:const EdgeInsets.only(top:21,bottom:11),
    child:Text(value.toUpperCase(),style:TextStyle(
      color:accent,fontSize:12,fontWeight:FontWeight.w800,letterSpacing:1.4)),
  );
  Widget _benefit(IconData icon,String title,String subtitle) => Padding(
    padding:const EdgeInsets.only(bottom:9),
    child:_card(child:Row(children:[
      Icon(icon,color:accent,size:27),
      const SizedBox(width:14),
      Expanded(child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,
        children:[
          Text(title,style:const TextStyle(
            color:Colors.white,fontWeight:FontWeight.w700)),
          const SizedBox(height:4),
          Text(subtitle,style:const TextStyle(
            color:Color(0xffb3c3bb),fontSize:12)),
        ],
      )),
    ])),
  );
  String _usd(int cents) => '\u0024' + (cents/100).toStringAsFixed(0);
}
