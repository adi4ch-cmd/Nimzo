import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

/// Records the Flutter/native contract; it does not render or execute HTML.
/// Never use this placeholder as a golden of the native game's graphics.
class TestGameWebViewPlatform extends WebViewPlatform {
  static TestGameWebViewPlatform install() {
    final platform = TestGameWebViewPlatform();
    WebViewPlatform.instance = platform;
    return platform;
  }

  final controllers = <TestGameWebViewController>[];

  /// Clears recordings between mounted games. The platform remains installed.
  void reset() => controllers.clear();

  @override
  TestGameWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    final controller = TestGameWebViewController(params);
    controllers.add(controller);
    return controller;
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) =>
      TestGameNavigationDelegate(params);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) =>
      _TestGameWebViewWidget(params);
}

class TestGameWebViewController extends PlatformWebViewController {
  TestGameWebViewController(super.params) : super.implementation();

  String? flutterAsset;
  JavaScriptMode? javaScriptMode;
  Color? backgroundColor;
  TestGameNavigationDelegate? delegate;
  final channels = <String, JavaScriptChannelParams>{};

  @override
  Future<void> loadFlutterAsset(String key) async => flutterAsset = key;

  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) async =>
      javaScriptMode = mode;

  @override
  Future<void> setBackgroundColor(Color color) async => backgroundColor = color;

  @override
  Future<void> addJavaScriptChannel(JavaScriptChannelParams params) async {
    channels[params.name] = params;
  }

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async =>
      delegate = handler as TestGameNavigationDelegate;

  void finishPage() => delegate!.onPageFinished!(localAssetUrl);

  String get localAssetUrl =>
      'file:///android_asset/flutter_assets/$flutterAsset';

  Future<NavigationDecision> requestNavigation(String url) async =>
      await delegate!.onNavigationRequest!(
        NavigationRequest(url: url, isMainFrame: true),
      );

  void sendBridgeMessage(String message) => channels['NimzoGameBridge']!
      .onMessageReceived(JavaScriptMessage(message: message));

  void failMainFrame({bool isForMainFrame = true}) =>
      delegate!.onWebResourceError!(
        WebResourceError(
          errorCode: -1,
          description: 'Test native resource failure',
          isForMainFrame: isForMainFrame,
          url: localAssetUrl,
        ),
      );
}

class TestGameNavigationDelegate extends PlatformNavigationDelegate {
  TestGameNavigationDelegate(super.params) : super.implementation();

  NavigationRequestCallback? onNavigationRequest;
  PageEventCallback? onPageFinished;
  WebResourceErrorCallback? onWebResourceError;

  @override
  Future<void> setOnNavigationRequest(
          NavigationRequestCallback callback) async =>
      onNavigationRequest = callback;

  @override
  Future<void> setOnPageFinished(PageEventCallback callback) async =>
      onPageFinished = callback;

  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback callback) async =>
      onWebResourceError = callback;
}

class _TestGameWebViewWidget extends PlatformWebViewWidget {
  _TestGameWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const ColoredBox(
        key: ValueKey('native-game-webview-test-boundary'),
        color: Color(0xff240444),
        child: Center(
          child: Text(
            'Native WebView boundary\nHTML graphics require device/browser QA',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
}
