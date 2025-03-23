import 'dart:ui';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'webview.dart';
import 'webview_win_floating_method_channel.dart';

abstract class WebviewWinFloatingPlatform extends PlatformInterface {
  /// Constructs a WebviewWinFloatingPlatform.
  WebviewWinFloatingPlatform() : super(token: _token);

  static final Object _token = Object();

  static WebviewWinFloatingPlatform _instance =
      MethodChannelWebviewWinFloating();

  /// The default instance of [WebviewWinFloatingPlatform] to use.
  ///
  /// Defaults to [MethodChannelWebviewWinFloating].
  static WebviewWinFloatingPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [WebviewWinFloatingPlatform] when
  /// they register themselves.
  static set instance(WebviewWinFloatingPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  void registerWebView(int webviewId, WinWebViewController webview) {
    throw UnimplementedError();
  }

  void unregisterWebView(int webviewId) {
    throw UnimplementedError();
  }

  Future<bool> create(int webviewId,
      {String? initialUrl, String? userDataFolder}) {
    throw UnimplementedError();
  }

  Future<void> setHasNavigationDecision(
      int webviewId, bool hasNavigationDecision) {
    throw UnimplementedError();
  }

  Future<void> updateBounds(
      int webviewId, Offset offset, Size size, double devicePixelRatio) {
    throw UnimplementedError();
  }

  Future<void> loadUrl(int webviewId, String url) {
    throw UnimplementedError();
  }

  Future<void> loadHtmlString(int webviewId, String html) {
    throw UnimplementedError();
  }

  Future<void> runJavaScript(int webviewId, String javaScriptString) {
    throw UnimplementedError();
  }

  Future<String> runJavaScriptReturningResult(
      int webviewId, String javaScriptString) {
    throw UnimplementedError();
  }

  Future<void> addScriptChannelByName(int webviewId, String channelName) {
    throw UnimplementedError();
  }

  Future<void> removeScriptChannelByName(int webviewId, String channelName) {
    throw UnimplementedError();
  }

  Future<void> setFullScreen(int webviewId, bool isFullScreen) {
    throw UnimplementedError();
  }

  Future<void> setVisibility(int webviewId, bool isVisible) {
    throw UnimplementedError();
  }

  Future<void> enableJavascript(int webviewId, bool isEnable) {
    throw UnimplementedError();
  }

  Future<bool> setUserAgent(int webviewId, String userAgent) {
    throw UnimplementedError();
  }

  Future<bool> canGoBack(int webviewId) {
    throw UnimplementedError();
  }

  Future<bool> canGoForward(int webviewId) {
    throw UnimplementedError();
  }

  Future<void> goBack(int webviewId) {
    throw UnimplementedError();
  }

  Future<void> goForward(int webviewId) {
    throw UnimplementedError();
  }

  Future<void> reload(int webviewId) {
    throw UnimplementedError();
  }

  Future<void> cancelNavigate(int webviewId) {
    throw UnimplementedError();
  }

  Future<void> clearCache(int webviewId) {
    throw UnimplementedError();
  }

  Future<bool> clearCookies(int webviewId) {
    throw UnimplementedError();
  }

  Future<void> requestFocus(int webviewId) {
    throw UnimplementedError();
  }

  Future<void> setBackgroundColor(int webviewId, Color color) {
    throw UnimplementedError();
  }

  Future<void> suspend(int webviewId) {
    throw UnimplementedError();
  }

  Future<void> resume(int webviewId) {
    throw UnimplementedError();
  }

  Future<void> dispose(int webviewId) {
    throw UnimplementedError();
  }

  Future<void> grantPermission(int webviewId, int deferralId, bool isGranted) {
    throw UnimplementedError();
  }

  Future<void> enableZoom(int webviewId, bool isEnable) {
    throw UnimplementedError();
  }

  // ------------------------------------------------------------------------
  // Windows-only methods
  // ------------------------------------------------------------------------

  Future<void> openDevTools(int webviewId) {
    throw UnimplementedError();
  }

  Future<void> enableStatusBar(int webviewId, bool isEnable) {
    throw UnimplementedError();
  }
}
