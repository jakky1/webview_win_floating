import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:webview_win_floating/webview.dart';
import 'package:webview_win_floating/webview_win_floating_platform_interface.dart';
import 'package:webview_win_floating/webview_win_floating_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockWebviewWinFloatingPlatform
    with MockPlatformInterfaceMixin
    implements WebviewWinFloatingPlatform {
  @override
  Future<bool> canGoBack(int webviewId) {
    throw UnimplementedError();
  }

  @override
  Future<bool> canGoForward(int webviewId) {
    throw UnimplementedError();
  }

  @override
  Future<void> cancelNavigate(int webviewId) {
    throw UnimplementedError();
  }

  @override
  Future<void> clearCache(int webviewId) {
    throw UnimplementedError();
  }

  @override
  Future<bool> clearCookies(int webviewId) {
    throw UnimplementedError();
  }

  @override
  Future<bool> create(int webviewId, String? url) {
    throw UnimplementedError();
  }

  @override
  Future<void> dispose(int webviewId) {
    throw UnimplementedError();
  }

  @override
  Future<void> enableJavascript(int webviewId, bool isEnable) {
    throw UnimplementedError();
  }

  @override
  Future<void> goBack(int webviewId) {
    throw UnimplementedError();
  }

  @override
  Future<void> goForward(int webviewId) {
    throw UnimplementedError();
  }

  @override
  Future<void> loadHtmlString(int webviewId, String html) {
    throw UnimplementedError();
  }

  @override
  Future<void> loadUrl(int webviewId, String url) {
    throw UnimplementedError();
  }

  @override
  void registerWebView(int webviewId, WinWebViewController webview) {
  }

  @override
  Future<void> reload(int webviewId) {
    throw UnimplementedError();
  }

  @override
  Future<void> runJavascript(int webviewId, String javaScriptString) {
    throw UnimplementedError();
  }

  @override
  Future<String> runJavascriptReturningResult(int webviewId, String javaScriptString) {
    throw UnimplementedError();
  }

  @override
  Future<void> setFullScreen(int webviewId, bool isFullScreen) {
    throw UnimplementedError();
  }

  @override
  Future<bool> setUserAgent(int webviewId, String userAgent) {
    throw UnimplementedError();
  }

  @override
  Future<void> setVisibility(int webviewId, bool isVisible) {
    throw UnimplementedError();
  }

  @override
  void unregisterWebView(int webviewId) {
  }

  @override
  Future<void> updateBounds(int webviewId, Offset offset, Size size, double devicePixelRatio) {
    throw UnimplementedError();
  }

  @override
  Future<void> addScriptChannelByName(int webviewId, String channelName) {
    throw UnimplementedError();
  }

  @override
  Future<void> removeScriptChannelByName(int webviewId, String channelName) {
    throw UnimplementedError();
  }

  @override
  Future<void> requestFocus(int webviewId) {
    throw UnimplementedError();
  }

  @override
  Future<void> setBackgroundColor(int webviewId, Color color) {
    throw UnimplementedError();
  }

}

void main() {
  final WebviewWinFloatingPlatform initialPlatform = WebviewWinFloatingPlatform.instance;

  test('$MethodChannelWebviewWinFloating is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelWebviewWinFloating>());
  });

  test('getPlatformVersion', () async {
    //WebviewWinFloating webviewWinFloatingPlugin = WebviewWinFloating();
    MockWebviewWinFloatingPlatform fakePlatform = MockWebviewWinFloatingPlatform();
    WebviewWinFloatingPlatform.instance = fakePlatform;

    //expect(await webviewWinFloatingPlugin.getPlatformVersion(), '42');
  });
}
