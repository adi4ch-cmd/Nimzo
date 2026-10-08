import 'package:flutter/material.dart';
import 'game_catalog.dart';
import 'game_screen.dart';

/// Keeps the existing room and voice session mounted throughout game browsing.
class RoomGameHost extends StatefulWidget {
  final Widget child;
  final String roomId;
  final bool voiceConnected, micEnabled;
  final VoidCallback? onMic;
  const RoomGameHost(
      {super.key,
      required this.child,
      required this.roomId,
      this.voiceConnected = false,
      this.micEnabled = false,
      this.onMic});
  @override
  State<RoomGameHost> createState() => RoomGameHostState();
}

class RoomGameHostState extends State<RoomGameHost> {
  String? _slug;
  bool _minimized = false;
  void open(String slug) {
    if (!NimzoRoomGames.approved.any((game) => game.slug == slug)) return;
    setState(() {
      _slug = slug;
      _minimized = false;
    });
  }

  void _minimize() => setState(() => _minimized = true);
  void _close() => setState(() => _slug = null);
  @override
  Widget build(BuildContext context) {
    final game =
        NimzoRoomGames.approved.where((g) => g.slug == _slug).firstOrNull;
    return PopScope(
      canPop: game == null || _minimized,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && game != null) _minimize();
      },
      child: LayoutBuilder(
          builder: (context, constraints) => Stack(children: [
                widget.child,
                if (game != null)
                  Positioned.fill(
                      top: constraints.maxHeight * .35,
                      child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(24)),
                          child: Offstage(
                            offstage: _minimized,
                            child: TickerMode(
                                enabled: !_minimized,
                                child: GameScreen(
                                  key: ValueKey(game.slug),
                                  slug: game.slug,
                                  roomId: widget.roomId,
                                  onMinimize: _minimize,
                                  onClose: _close,
                                  roomControls: SafeArea(
                                      child: Material(
                                          color: const Color(0xff28104d),
                                          child: ListTile(
                                            leading: const Icon(
                                                Icons.spatial_audio_off,
                                                color: Colors.white),
                                            title: const Text('Voice room',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight:
                                                        FontWeight.w700)),
                                            subtitle: Text(
                                                widget.voiceConnected
                                                    ? 'Connected'
                                                    : 'Voice disconnected',
                                                style: const TextStyle(
                                                    color: Color(0xffe9d5ff))),
                                            onTap: _minimize,
                                            trailing: IconButton(
                                                tooltip: widget.micEnabled
                                                    ? 'Mute microphone'
                                                    : 'Enable microphone',
                                                onPressed: widget.voiceConnected
                                                    ? widget.onMic
                                                    : null,
                                                icon: Icon(
                                                    widget.micEnabled
                                                        ? Icons.mic
                                                        : Icons.mic_off,
                                                    color: Colors.white)),
                                          ))),
                                )),
                          ))),
                if (game != null && _minimized)
                  Positioned(
                      right: 12,
                      bottom: 84,
                      child: SafeArea(
                          child: Material(
                        color: const Color(0xff28104d),
                        elevation: 12,
                        borderRadius: BorderRadius.circular(20),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          InkWell(
                              onTap: () => open(game.slug),
                              borderRadius: BorderRadius.circular(20),
                              child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(children: [
                                    ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.asset(
                                            'assets/reference/game/${game.artwork}.jpg',
                                            width: 36,
                                            height: 36)),
                                    const SizedBox(width: 8),
                                    const Text('Restore game',
                                        style: TextStyle(color: Colors.white)),
                                  ]))),
                          IconButton(
                              tooltip: 'Close game',
                              onPressed: _close,
                              icon:
                                  const Icon(Icons.close, color: Colors.white)),
                        ]),
                      ))),
              ])),
    );
  }
}
