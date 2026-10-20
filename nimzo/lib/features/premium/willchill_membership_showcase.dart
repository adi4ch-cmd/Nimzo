import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Membership page composition follows the supplied WillChill video reference.
/// The account's tier/progress stay separate from the selected visual preview.
class WillChillMembershipShowcase extends StatelessWidget {
  const WillChillMembershipShowcase({
    super.key,
    required this.kind,
    required this.tier,
    required this.ownedLevel,
    required this.onTierChanged,
    this.onPreviewEntrance,
    this.growthProgress,
  });
  final String kind;
  final int tier, ownedLevel;
  final ValueChanged<int> onTierChanged;
  final VoidCallback? onPreviewEntrance;
  final double? growthProgress;
  bool get _svip => kind == 'svip';
  String get _label => _svip ? 'SVIP' : 'VIP';
  String get _base => 'assets/willchill_premium/$kind/';
  static const gold = Color(0xffe8d59b);
  String get _hero =>
      _svip ? 'fixed_top_svip${tier}_bg.webp' : 'bg_vip${tier}_top_bg_res.webp';
  String get _medal => _svip
      ? 'voiceroom_svip${tier}_entry_level_ic.webp'
      : 'ic_vip_leve$tier.png';
  String get _privilege => _svip
      ? 'bg_privil_item_svip$tier.webp'
      : 'bg_privil_item_vip$tier.${tier >= 6 ? 'png' : 'webp'}';

  Widget _art(String file, {double? height, double? width}) => Image.asset(
        '$_base$file',
        height: height,
        width: width,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.workspace_premium_outlined, color: gold, size: 36),
      );

  Widget _section(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 18, 8, 12),
        child: Row(children: [
          const Expanded(child: Divider(color: Color(0xff7f704d))),
          const SizedBox(width: 8),
          const Icon(Icons.auto_awesome, color: gold, size: 13),
          const SizedBox(width: 6),
          Flexible(
              flex: 4,
              child: Text(text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: gold,
                      fontFamily: 'serif',
                      fontSize: 16,
                      fontWeight: FontWeight.w800))),
          const SizedBox(width: 6),
          const Icon(Icons.auto_awesome, color: gold, size: 13),
          const SizedBox(width: 8),
          const Expanded(child: Divider(color: Color(0xff7f704d))),
        ]),
      );

  void _preview(BuildContext context, String label, Widget artwork) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xff17131c),
      showDragHandle: true,
      builder: (_) => SafeArea(
          child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('$_label $tier · $label',
              style: const TextStyle(
                  color: gold, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          SizedBox(height: 180, child: Center(child: artwork)),
          const SizedBox(height: 20),
          Text(ownedLevel >= tier ? 'Your membership tier' : 'Tier preview',
              style: const TextStyle(color: Colors.white70)),
        ]),
      )),
    );
  }

  Widget _tile(BuildContext context, String label, Widget art, {Key? key}) =>
      Semantics(
        button: true,
        label: 'Preview $_label $tier $label',
        child: InkWell(
          key: key,
          onTap: () => _preview(context, label, art),
          child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .18),
                image: DecorationImage(
                    image: AssetImage('$_base$_privilege'), fit: BoxFit.fill),
                border: Border.all(color: gold.withValues(alpha: .28)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(7),
                child: Column(children: [
                  Expanded(child: Center(child: art)),
                  const SizedBox(height: 7),
                  Text(label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: const TextStyle(
                          color: gold,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ]),
              )),
        ),
      );

  Widget _icon(IconData icon) => Icon(icon, color: gold, size: 38);

  Widget _nameplate() =>
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _art(
            _svip
                ? 'voiceroom_icon_svip_id_left.webp'
                : 'voiceroom_icon_vip_id_left${tier == 1 ? '' : '_v$tier'}.png',
            height: 19,
            width: 18),
        Flexible(
            child: Text('$_label $tier',
                maxLines: 1,
                style: const TextStyle(
                    color: gold, fontSize: 12, fontWeight: FontWeight.w800))),
        _art(
            _svip
                ? 'voiceroom_icon_svip_id_right.webp'
                : 'voiceroom_icon_vip_id_right${tier == 1 ? '' : '_v$tier'}.png',
            height: 19,
            width: 18),
      ]);

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final width = box.maxWidth;
        final scaled = MediaQuery.textScalerOf(context).scale(28) - 28;
        final identity = <Widget>[
          _tile(
              context,
              'Badge',
              !_svip && tier <= 5
                  ? _art('icon_vip${tier}_1.png')
                  : _art(_medal),
              key: ValueKey('membership-$kind-identity')),
          if (_svip)
            _tile(context, 'Nameplate', _nameplate(),
                key: ValueKey('membership-$kind-nameplate')),
          _tile(
              context,
              'Avatar Frame',
              !_svip && tier <= 5
                  ? _art('icon_vip${tier}_2.png')
                  : _icon(Icons.filter_frames_rounded)),
          if (!_svip)
            _tile(context, 'Entry Banner',
                tier <= 5 ? _art('icon_vip${tier}_3.png') : _nameplate(),
                key: ValueKey('membership-$kind-nameplate')),
          _tile(
              context,
              'Chat Bubble',
              !_svip && tier <= 5
                  ? _art('icon_vip${tier}_4.png')
                  : _icon(Icons.chat_bubble_outline)),
          if (!_svip) ...[
            _tile(
                context,
                'Mic Wave',
                tier <= 5
                    ? _art('icon_vip${tier}_5.png')
                    : _icon(Icons.graphic_eq)),
            _tile(
                context,
                'Profile Card',
                tier <= 5
                    ? _art('icon_vip${tier}_6.${tier == 1 ? 'webp' : 'png'}')
                    : _icon(Icons.badge_outlined)),
          ],
        ];
        const benefits = <(String, IconData)>[
          ('Animated Avatar', Icons.person_outline),
          ('Room Limit', Icons.group_add_outlined),
          ('Custom Gift', Icons.card_giftcard),
          ('Custom Greeting', Icons.text_fields),
          ('Coin Reward', Icons.savings_outlined),
          ('Profile Music', Icons.music_note_outlined),
        ];
        return Stack(children: [
          Positioned.fill(
              child: Image.asset(
                  '$_base${_svip ? 'bg_svip${tier}_frosted.webp' : 'bg_vip_middle_v$tier.webp'}',
                  fit: BoxFit.fill)),
          Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Image.asset('$_base$_hero',
                  width: width, fit: BoxFit.fitWidth)),
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            MembershipTierSelector(
                kind: kind,
                tier: tier,
                maxTier: _svip ? 8 : 7,
                onChanged: onTierChanged),
            SizedBox(
              height: _svip ? width * .74 : width * .82,
              child: _svip
                  ? Align(
                      alignment: Alignment.bottomRight,
                      child: SizedBox(
                        width: width * .54,
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              _art(_medal, height: 44, width: width * .44),
                              const SizedBox(height: 8),
                              _art('svip${tier}_level_progress_container.webp',
                                  height: width * .17, width: width * .54),
                              if (onPreviewEntrance != null)
                                IconButton(
                                    key: ValueKey('willchill-svip-crown-$tier'),
                                    tooltip: 'Preview SVIP $tier entrance',
                                    onPressed: onPreviewEntrance,
                                    icon: const Icon(Icons.play_circle_outline,
                                        color: gold)),
                            ]),
                      ))
                  : Center(
                      child: tier <= 5
                          ? _art(
                              'icon_vip${tier}_top_logo.${tier == 1 ? 'png' : 'webp'}',
                              width: width * .8,
                              height: width * .72)
                          : _art('ic_mine_vip_new.png',
                              width: width * .6, height: width * .6)),
            ),
            if (_svip)
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                            growthProgress == null
                                ? 'Current level: $ownedLevel'
                                : 'Current progress: ${(growthProgress! * 100).round()}%',
                            style: const TextStyle(color: gold, fontSize: 10)),
                        const SizedBox(height: 6),
                        SizedBox(
                            height: 12,
                            child: Stack(fit: StackFit.expand, children: [
                              Image.asset('${_base}bg_svip_progress_track.webp',
                                  fit: BoxFit.fill),
                              Align(
                                  alignment: Alignment.centerLeft,
                                  child: FractionallySizedBox(
                                      widthFactor:
                                          growthProgress?.clamp(0.0, 1.0) ?? 0,
                                      child: Image.asset(
                                          '${_base}bg_svip_progress_completed.webp',
                                          width: double.infinity,
                                          fit: BoxFit.fill))),
                            ])),
                        const SizedBox(height: 6),
                        Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            spacing: 8,
                            children: [
                              Text('Your tier: $ownedLevel',
                                  style: const TextStyle(
                                      color: gold, fontSize: 10)),
                              Text('SVIP $tier',
                                  key: ValueKey(
                                      'willchill-current-preview-$kind'),
                                  style: const TextStyle(
                                      color: gold,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800)),
                            ]),
                      ])),
            if (!_svip)
              Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: _art(
                      'icon_vip${tier}_title_res.${tier >= 6 ? 'webp' : 'png'}',
                      width: width,
                      height: 40)),
            if (!_svip)
              Semantics(
                  label: 'VIP $tier',
                  child: const SizedBox.shrink(
                      key: ValueKey('willchill-current-preview-vip'))),
            _section('Identification'),
            GridView.count(
              key: ValueKey('membership-$kind-identification-grid'),
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: (width / 3 - 14) / (122 + scaled),
              children: identity,
            ),
            _section('Exclusive privilege'),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: (width / 3 - 14) / (120 + scaled),
              children: [
                for (final entry in benefits)
                  _tile(context, entry.$1, _icon(entry.$2))
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                  ownedLevel >= tier ? 'Your membership tier' : 'Tier preview',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: gold)),
            ),
            Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 22),
                child: Text(
                    ownedLevel > 0
                        ? 'Current $_label level: $ownedLevel'
                        : 'No active $_label tier on your NIMZO account',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: gold, fontSize: 12))),
          ]),
        ]);
      });
}

class MembershipTierSelector extends StatefulWidget {
  const MembershipTierSelector(
      {super.key,
      required this.kind,
      required this.tier,
      required this.maxTier,
      required this.onChanged});
  final String kind;
  final int tier, maxTier;
  final ValueChanged<int> onChanged;
  @override
  State<MembershipTierSelector> createState() => _MembershipTierSelectorState();
}

class _MembershipTierSelectorState extends State<MembershipTierSelector> {
  final scroll = ScrollController();
  double extent = 78;
  @override
  void initState() {
    super.initState();
    _reveal();
  }

  @override
  void didUpdateWidget(covariant MembershipTierSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tier != widget.tier || oldWidget.kind != widget.kind)
      _reveal();
  }

  void _reveal() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !scroll.hasClients) return;
        final offset = ((widget.tier - 1) * extent -
                (scroll.position.viewportDimension - extent) / 2)
            .clamp(0.0, scroll.position.maxScrollExtent);
        scroll.jumpTo(offset);
      });
  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    extent = math.max(78, MediaQuery.textScalerOf(context).scale(54) + 24);
    return SizedBox(
      height: 48 + (MediaQuery.textScalerOf(context).scale(18) - 18),
      child: ListView.builder(
        key: ValueKey('willchill-${widget.kind}-tier-strip'),
        controller: scroll,
        scrollDirection: Axis.horizontal,
        itemExtent: extent,
        itemCount: widget.maxTier,
        itemBuilder: (_, i) => TextButton(
          key: ValueKey('willchill-${widget.kind}-level-${i + 1}'),
          onPressed: () => widget.onChanged(i + 1),
          style: TextButton.styleFrom(
              foregroundColor: widget.tier == i + 1
                  ? const Color(0xfff3dc8e)
                  : const Color(0xff948a87)),
          child: Text('${widget.kind.toUpperCase()} ${i + 1}',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: widget.tier == i + 1
                      ? FontWeight.w900
                      : FontWeight.w600)),
        ),
      ),
    );
  }
}
