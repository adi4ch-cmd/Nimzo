import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svga/flutter_svga.dart';
import 'package:flutter_vap_player/flutter_vap_player.dart';

/// On-device QA catalogue of verified media bundled from the user-provided source.
/// No checkout, coin debits, fake ownership or auto-granted SVIP privileges.
/// Catalogued media becomes saleable/equippable only once a server entitlement
/// and its room/profile renderer are independently tested.
class WillChillPremiumScreen extends StatefulWidget {
  const WillChillPremiumScreen({super.key, this.initialGroup = 'svip'});
  final String initialGroup;

  @override
  State<WillChillPremiumScreen> createState() => _WillChillPremiumScreenState();
}

class _PremiumAsset {
  _PremiumAsset(Map<String, dynamic> json)
      : group = json['group'] as String,
        name = json['name'] as String,
        asset = json['asset'] as String,
        mediaType = json['type'] as String,
        tier = json['tier'] as int?;
  final String group, name, asset, mediaType;
  final int? tier;
  bool get isImage => mediaType == 'image';
  bool get canPlay => mediaType == 'vap' || mediaType == 'svga';
  String get displayName => name
      .replaceAll(RegExp(r'\.(png|webp|jpg|svga|mp4)$'), '')
      .replaceAll('_', ' ');
}

class _WillChillPremiumScreenState extends State<WillChillPremiumScreen> {
  static const groups = <String>[
    'svip', 'vip', 'store', 'gifts', 'entrances', 'room_fx', 'games',
  ];
  static const title = <String, String>{
    'svip': 'SVIP 1–8',
    'vip': 'VIP',
    'store': 'Store / Backpack',
    'gifts': 'Gifts / Effects',
    'entrances': 'Entrance / Crown',
    'room_fx': 'Room Effects',
    'games': 'Games UI',
  };
  List<_PremiumAsset>? _assets;
  Object? _error;
  late String _group = groups.contains(widget.initialGroup)
      ? widget.initialGroup
      : 'svip';
  int _tier = 1;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final raw = await rootBundle.loadString(
        'assets/willchill_premium/catalog.json',
      );
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final records = decoded['records'] as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _assets = records
            .map((item) => _PremiumAsset(item as Map<String, dynamic>))
            .toList(growable: false);
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  _PremiumAsset? _tierArt(String part) {
    final matches = _assets?.where((item) =>
      item.group == 'svip' && item.tier == _tier &&
      item.name.toLowerCase().contains(part)).toList();
    return matches == null || matches.isEmpty ? null : matches.first;
  }

  Widget _svipOverview() {
    final header = _tierArt('fixed_top_svip');
    final frosted = _tierArt('bg_svip');
    final progress = _tierArt('level_progress_container');
    final expires = _tierArt('expiration_container');
    Widget illustration(_PremiumAsset? art, {double height = 130}) =>
        SizedBox(
          height: height,
          child: art == null
              ? const Center(child: Icon(Icons.image_not_supported_outlined))
              : Image.asset(art.asset,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image_outlined))),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        height: 45,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: 8,
          separatorBuilder: (_, __) => const SizedBox(width: 7),
          itemBuilder: (context, i) => ChoiceChip(
            key: ValueKey('willchill-svip-level-${i + 1}'),
            selected: _tier == i + 1,
            onSelected: (_) => setState(() => _tier = i + 1),
            label: Text('SVIP ${i + 1}'),
            selectedColor: const Color(0xff9dddc7),
          ),
        ),
      ),
      const SizedBox(height: 10),
      Card(
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          illustration(header, height: 220),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Text('SVIP $_tier – Original source artwork',
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          illustration(frosted, height: 95),
          illustration(progress, height: 75),
          illustration(expires, height: 55),
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'Asset preview. Level unlocking, expiration and privileges '
              'must be verified against NIMZO server rules.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xff556b61), fontSize: 11),
            ),
          ),
        ]),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final items = (_assets ?? []).where((a) => a.group == _group &&
      (_group != 'svip' || a.tier == null || a.tier == _tier)).toList();
    return Scaffold(
      backgroundColor: const Color(0xfff5f9f7),
      appBar: AppBar(
        title: const Text('NIMZO Premium Collection'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xff174632),
      ),
      body: _error != null
          ? Center(child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text('Premium assets are not installed. '
                  'Run the verified import package before building.\n$_error',
                  textAlign: TextAlign.center),
            ))
          : _assets == null
              ? const Center(child: CircularProgressIndicator())
              : Column(children: [
                  SizedBox(
                    height: 48,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: groups.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (context, i) => ChoiceChip(
                        selected: groups[i] == _group,
                        label: Text(title[groups[i]] ?? groups[i]),
                        onSelected: (_) => setState(() => _group = groups[i]),
                        selectedColor: const Color(0xff9dddc7),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(13, 10, 13, 30),
                      children: [
                        if (_group == 'svip') _svipOverview(),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text('${title[_group]} · ${items.length} files',
                            style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800)),
                        ),
                        GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            mainAxisExtent: 166,
                          ),
                          itemCount: items.length,
                          itemBuilder: (context, i) {
                            final item = items[i];
                            return Card(
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                key: ValueKey('willchill-asset-${item.name}'),
                                onTap: item.mediaType == 'audio' ? null : () =>
                                    Navigator.of(context).push<void>(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            _PremiumAssetPreview(asset: item),
                                      )),
                                child: Column(children: [
                                  Expanded(child: Container(
                                    width: double.infinity,
                                    color: const Color(0xffedf4f0),
                                    child: item.isImage
                                        ? Image.asset(item.asset,
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(Icons.broken_image))
                                        : Center(child: Icon(
                                            item.canPlay
                                                ? Icons.play_circle_fill
                                                : Icons.movie_creation_outlined,
                                            size: 42,
                                            color: const Color(0xff0b8964),
                                          )),
                                  )),
                                  Padding(
                                    padding: const EdgeInsets.all(7),
                                    child: Text(item.displayName,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11,
                                          fontWeight: FontWeight.w700)),
                                  ),
                                ]),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ]),
    );
  }
}

class _PremiumAssetPreview extends StatefulWidget {
  const _PremiumAssetPreview({required this.asset});
  final _PremiumAsset asset;
  @override
  State<_PremiumAssetPreview> createState() => _PremiumAssetPreviewState();
}

class _PremiumAssetPreviewState extends State<_PremiumAssetPreview> {
  VapPlayerController? _vap;
  StreamSubscription<VapEvent>? _events;
  bool _initialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.asset.mediaType == 'vap') unawaited(_startVap());
  }

  Future<void> _startVap() async {
    try {
      final controller = VapPlayerController.asset(
        widget.asset.asset,
        options: const VapPlayerOptions(
          viewType: VapViewType.textureView,
          scaleType: VapScaleType.fitCenter,
          repeatCount: 0,
          mute: false,
        ),
      );
      _vap = controller;
      _events = controller.events.listen((event) {
        if (event is VapErrorEvent && mounted) {
          setState(() => _error = 'Native VAP playback failed');
        }
      }, onError: (Object _) {
        if (mounted) setState(() => _error = 'VAP event stream failed');
      });
      await controller.initialize();
      if (!mounted) return;
      setState(() => _initialized = true);
      await controller.play();
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to initialize native player');
    }
  }

  @override
  void dispose() {
    unawaited(_events?.cancel());
    final controller = _vap;
    if (controller != null) unawaited(controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xff111a17),
        appBar: AppBar(
          title: Text(widget.asset.displayName,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          backgroundColor: const Color(0xff192e26),
          foregroundColor: Colors.white,
        ),
        body: SafeArea(
          child: Stack(fit: StackFit.expand, children: [
            if (_error != null)
              Center(child: Text(_error!,
                  style: const TextStyle(color: Colors.white)))
            else if (widget.asset.isImage)
              InteractiveViewer(child: Center(child:
                  Image.asset(widget.asset.asset, fit: BoxFit.contain)))
            else if (widget.asset.mediaType == 'svga')
              SVGAEasyPlayer(assetsName: widget.asset.asset,
                  fit: BoxFit.contain)
            else if (widget.asset.mediaType == 'vap' &&
                _initialized && _vap != null)
              VapPlayer(_vap!)
            else if (widget.asset.mediaType == 'vap')
              const Center(child: CircularProgressIndicator())
            else
              const Center(child: Text('Preview not available for this format',
                  style: TextStyle(color: Colors.white))),
            Positioned(
              bottom: 20, left: 14, right: 14,
              child: Text('SOURCE ASSET PREVIEW · No coin charge or '
                  'membership grant',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ),
          ]),
        ),
      );
}
