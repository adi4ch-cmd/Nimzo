import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Hosts the owner's provisional Jackpot 9-line HTML5 practice board inside the existing room.
///
/// The packaged HTML contains ONLY a local demo balance. The native room
/// remains mounted behind this widget, and the WebView never receives Supabase
/// credentials or any permission to debit a real wallet.
class JackpotRoomWebView extends StatefulWidget {
  const JackpotRoomWebView({
    super.key,
    this.onMinimize,
    this.onExpand,
    this.roomControls,
  });

  final VoidCallback? onMinimize;
  final VoidCallback? onExpand;
  final Widget? roomControls;

  @override
  State<JackpotRoomWebView> createState() => _JackpotRoomWebViewState();
}

class _JackpotRoomWebViewState extends State<JackpotRoomWebView> {
  late final WebViewController _controller;
  bool _pageLoaded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xff240444))
      ..addJavaScriptChannel(
        'NimzoGameBridge',
        onMessageReceived: (JavaScriptMessage message) {
          if (!mounted) return;
          switch (message.message) {
            case 'minimize':
              if (widget.onMinimize != null) {
                widget.onMinimize!();
              } else {
                Navigator.of(context).maybePop();
              }
              return;
            case 'expand':
              widget.onExpand?.call();
              return;
            // Never accept wallet, room, or auth operations from HTML.
            default:
              return;
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _pageLoaded = true);
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == false) return;
            if (mounted) {
              setState(() => _error = 'Jackpot could not load.');
            }
          },
          onNavigationRequest: (request) {
            // Do not follow links away from the bundled offline game.
            final uri = Uri.tryParse(request.url);
            if (uri == null) return NavigationDecision.prevent;
            final path = uri.path;
            final isAsset = path.endsWith('/assets/games/jackpot_9lines_demo.html');
            final isLocal = uri.scheme == 'file' ||
                uri.scheme == 'about' ||
                uri.host == 'appassets.androidplatform.net';
            return isAsset && isLocal
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
        ),
      )
      ..loadFlutterAsset('assets/games/jackpot_9lines_demo.html');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff240444),
      bottomNavigationBar: widget.roomControls,
      body: _error == null
          ? Stack(
              children: [
                WebViewWidget(
                  key: const ValueKey('jackpot-room-webview'),
                  controller: _controller,
                ),
                if (!_pageLoaded)
                  const Center(
                    child: CircularProgressIndicator(color: Color(0xffffd58a)),
                  ),
              ],
            )
          : Center(
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.white),
              ),
            ),
    );
  }
}
