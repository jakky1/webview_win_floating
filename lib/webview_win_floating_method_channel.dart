import 'dart:developer';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'webview.dart';
import 'webview_win_floating_platform_interface.dart';

/// An implementation of [WebviewWinFloatingPlatform] that uses method channels.
class MethodChannelWebviewWinFloating extends WebviewWinFloatingPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('webview_win_floating');

  final webviewMap = <int, WeakReference<WinWebViewController>>{};
  MethodChannelWebviewWinFloating() {
    assert(() {
      // When hot-reload in debugging mode, clear all old webviews created before hot-reload
      methodChannel.invokeMethod<bool>('clearAll');
      return true;
    }());

    methodChannel.setMethodCallHandler((call) async {
      //log("[webview] native->flutter: $call");
      int? webviewId = call.arguments["webviewId"];
      assert(webviewId != null);
      final ref = webviewMap[webviewId];
      if (ref == null) {
        log("webview not found: id = $webviewId");
        return;
      }

      final controller = ref.target;
      if (controller == null) {
        webviewMap.remove(webviewId);
        log("webview is alive but not referenced anymore: id = $webviewId");
        return;
      }

      if (call.method == "OnWebMessageReceived") {
        String message = call.arguments["message"]!;
        controller.notifyMessageReceived_(message);
      } else if (call.method == "onPageStarted") {
        String url = call.arguments["url"]!;
        bool isNewWindow = call.arguments["isNewWindow"]!;
        bool isUserInitiated = call.arguments["isUserInitiated"]!;
        controller.notifyOnPageStarted_(url, isNewWindow, isUserInitiated);
      } else if (call.method == "onPageFinished") {
        String url = call.arguments["url"]!;
        int errCode = call.arguments["errCode"]!;
        controller.notifyOnPageFinished_(url, errCode);
      } else if (call.method == "onPageTitleChanged") {
        String title = call.arguments["title"]!;
        controller.notifyOnPageTitleChanged_(title);
      } else if (call.method == "onMoveFocusRequest") {
        bool isNext = call.arguments["isNext"]!;
        controller.notifyOnFocusRequest_(isNext);
      } else if (call.method == "OnFullScreenChanged") {
        bool? isFullScreen = call.arguments["isFullScreen"];
        assert(isFullScreen != null);
        controller.notifyFullScreenChanged_(isFullScreen!);
      } else if (call.method == "onHistoryChanged") {
        controller.notifyHistoryChanged_();
      } else if (call.method == "onAskPermission") {
        String url = call.arguments["url"]!;
        int kind = call.arguments["kind"]!;
        int deferralId = call.arguments["deferralId"]!;
        controller.notifyAskPermission_(
            url, WinPermissionKind.values[kind], deferralId);
      } else {
        assert(false, "unknown call from native: ${call.method}");
      }
    });
  }

  @override
  void registerWebView(int webviewId, WinWebViewController webview) {
    webviewMap[webviewId] = WeakReference(webview);
  }

  @override
  void unregisterWebView(int webviewId) {
    webviewMap.remove(webviewId);
  }

  @override
  Future<bool> create(int webviewId,
      {String? initialUrl, String? userDataFolder}) async {
    return await methodChannel.invokeMethod<bool>('create', {
          "webviewId": webviewId,
          "url": initialUrl ?? "",
          "userDataFolder": userDataFolder ?? ""
        }) ??
        false;
  }

  @override
  Future<void> setHasNavigationDecision(
      int webviewId, bool hasNavigationDecision) async {
    return await methodChannel.invokeMethod<void>('setHasNavigationDecision', {
      "webviewId": webviewId,
      "hasNavigationDecision": hasNavigationDecision
    });
  }

  @override
  Future<void> updateBounds(
      int webviewId, Offset offset, Size size, double devicePixelRatio) async {
    await methodChannel.invokeMethod<bool>('updateBounds', {
      "webviewId": webviewId,
      "left": (offset.dx * devicePixelRatio).toInt(),
      "top": (offset.dy * devicePixelRatio).toInt(),
      "right": ((offset.dx + size.width) * devicePixelRatio).toInt(),
      "bottom": ((offset.dy + size.height) * devicePixelRatio).toInt(),
    });
  }

  @override
  Future<void> loadUrl(int webviewId, String url) async {
    await methodChannel
        .invokeMethod<bool>('loadUrl', {"webviewId": webviewId, "url": url});
  }

  @override
  Future<void> loadHtmlString(int webviewId, String html) async {
    await methodChannel.invokeMethod<bool>(
        'loadHtmlString', {"webviewId": webviewId, "html": html});
  }

  @override
  Future<void> runJavaScript(int webviewId, String javaScriptString) async {
    await methodChannel.invokeMethod<void>('runJavascript', {
      "webviewId": webviewId,
      "javaScriptString": javaScriptString,
      "ignoreResult": true
    });
  }

  @override
  Future<String> runJavaScriptReturningResult(
      int webviewId, String javaScriptString) async {
    return await methodChannel.invokeMethod<String>('runJavascript', {
          "webviewId": webviewId,
          "javaScriptString": javaScriptString,
          "ignoreResult": false
        }) ??
        "";
  }

  @override
  Future<void> addScriptChannelByName(int webviewId, String channelName) {
    return methodChannel.invokeMethod<void>('addScriptChannelByName',
        {"webviewId": webviewId, "channelName": channelName});
  }

  @override
  Future<void> removeScriptChannelByName(int webviewId, String channelName) {
    return methodChannel.invokeMethod<void>('removeScriptChannelByName',
        {"webviewId": webviewId, "channelName": channelName});
  }

  @override
  Future<void> setFullScreen(int webviewId, bool isFullScreen) async {
    await methodChannel.invokeMethod<bool>('setFullScreen',
        {"webviewId": webviewId, "isFullScreen": isFullScreen});
  }

  @override
  Future<void> setVisibility(int webviewId, bool isVisible) async {
    await methodChannel.invokeMethod<bool>(
        'setVisibility', {"webviewId": webviewId, "isVisible": isVisible});
  }

  @override
  Future<void> enableJavascript(int webviewId, bool isEnable) async {
    await methodChannel.invokeMethod<bool>(
        'enableJavascript', {"webviewId": webviewId, "isEnable": isEnable});
  }

  @override
  Future<bool> setUserAgent(int webviewId, String userAgent) async {
    bool? b = await methodChannel.invokeMethod<bool?>(
        'setUserAgent', {"webviewId": webviewId, "userAgent": userAgent});
    return b!;
  }

  @override
  Future<bool> canGoBack(int webviewId) async {
    bool? b = await methodChannel
        .invokeMethod<bool?>('canGoBack', {"webviewId": webviewId});
    return b!;
  }

  @override
  Future<bool> canGoForward(int webviewId) async {
    bool? b = await methodChannel
        .invokeMethod<bool?>('canGoForward', {"webviewId": webviewId});
    return b!;
  }

  @override
  Future<void> goBack(int webviewId) async {
    await methodChannel.invokeMethod<void>('goBack', {"webviewId": webviewId});
  }

  @override
  Future<void> goForward(int webviewId) async {
    await methodChannel
        .invokeMethod<void>('goForward', {"webviewId": webviewId});
  }

  @override
  Future<void> reload(int webviewId) async {
    await methodChannel.invokeMethod<void>('reload', {"webviewId": webviewId});
  }

  @override
  Future<void> cancelNavigate(int webviewId) async {
    await methodChannel
        .invokeMethod<void>('cancelNavigate', {"webviewId": webviewId});
  }

  @override
  Future<void> clearCache(int webviewId) async {
    await methodChannel
        .invokeMethod<void>('clearCache', {"webviewId": webviewId});
  }

  @override
  Future<bool> clearCookies(int webviewId) async {
    bool? b = await methodChannel
        .invokeMethod<bool?>('clearCookies', {"webviewId": webviewId});
    return b!;
  }

  @override
  Future<void> requestFocus(int webviewId) async {
    await methodChannel
        .invokeMethod<void>('requestFocus', {"webviewId": webviewId});
  }

  @override
  Future<void> setBackgroundColor(int webviewId, Color color) async {
    await methodChannel.invokeMethod<void>(
        'setBackgroundColor', {"webviewId": webviewId, "color": color.value});
  }

  @override
  Future<void> suspend(int webviewId) async {
    await methodChannel.invokeMethod<bool>('suspend', {"webviewId": webviewId});
  }

  @override
  Future<void> resume(int webviewId) async {
    await methodChannel.invokeMethod<bool>('resume', {"webviewId": webviewId});
  }

  @override
  Future<void> dispose(int webviewId) async {
    await methodChannel.invokeMethod<bool>('dispose', {"webviewId": webviewId});
  }

  @override
  Future<void> grantPermission(int webviewId, int deferralId, bool isGranted) {
    return methodChannel.invokeMethod<void>('grantPermission', {
      "webviewId": webviewId,
      "deferralId": deferralId,
      "isGranted": isGranted
    });
  }

  @override
  Future<void> enableZoom(int webviewId, bool isEnable) async {
    await methodChannel.invokeMethod<bool>(
        'enableIsZoomControl', {"webviewId": webviewId, "isEnable": isEnable});
  }

  // ------------------------------------------------------------------------
  // Windows-only methods
  // ------------------------------------------------------------------------

  @override
  Future<void> openDevTools(int webviewId) {
    return methodChannel
        .invokeMethod<void>('openDevTools', {"webviewId": webviewId});
  }

  @override
  Future<void> enableStatusBar(int webviewId, bool isEnable) async {
    await methodChannel.invokeMethod<bool>(
        'enableStatusBar', {"webviewId": webviewId, "isEnable": isEnable});
  }
}
