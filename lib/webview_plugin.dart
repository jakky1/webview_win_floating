import 'dart:developer';

import 'package:flutter/src/gestures/recognizer.dart';
import 'package:flutter/src/foundation/basic_types.dart';
import 'package:flutter/widgets.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:webview_win_floating/webview.dart';

class WindowsWebViewPlugin extends WebViewPlatform {
  @override
  Widget build({required BuildContext context,
    required CreationParams creationParams,
    required WebViewPlatformCallbacksHandler webViewPlatformCallbacksHandler,
    required JavascriptChannelRegistry javascriptChannelRegistry,
    WebViewPlatformCreatedCallback? onWebViewPlatformCreated,
    Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers}) {

    late WinWebViewController controller;
    _WindowsWebViewControllerPlugin? controllerPlugin;

    Set<JavascriptChannel>? channels;
    if (creationParams.javascriptChannelNames.isNotEmpty) {
      channels = creationParams.javascriptChannelNames.map((name) {
        return JavascriptChannel(name: name, onMessageReceived: (message) {
          javascriptChannelRegistry.onJavascriptChannelMessage(name, message.message);
        });
      }).toSet();
    }

    return WinWebView(
      initialUrl: creationParams.initialUrl,
      onWebViewCreated: (c) {
        controller = c;
        if (creationParams.backgroundColor != null) controller.setBackgroundColor(creationParams.backgroundColor!);
        if (onWebViewPlatformCreated == null) return;
        controllerPlugin = _WindowsWebViewControllerPlugin(webViewPlatformCallbacksHandler, controller, javascriptChannelRegistry);
        onWebViewPlatformCreated(controllerPlugin);
      },
      navigationDelegate: (navigation) async {
        bool isAllowed = await webViewPlatformCallbacksHandler.onNavigationRequest(url: navigation.url, isForMainFrame: navigation.isForMainFrame);
        return isAllowed ? WinNavigationDecision.navigate : WinNavigationDecision.prevent;
      },
      onPageStarted: (url) => webViewPlatformCallbacksHandler.onPageStarted(url),
      onPageFinished: (url) => webViewPlatformCallbacksHandler.onPageFinished(url),
      onPageTitleChanged: (title) => controllerPlugin?._setTitle(title),
      onWebResourceError: (error) => webViewPlatformCallbacksHandler.onWebResourceError(error),
      javascriptChannels: channels,
      javascriptMode: creationParams.webSettings?.javascriptMode ?? JavascriptMode.unrestricted,
      userAgent: creationParams.webSettings?.userAgent.value,
    );
  }
}

class _WindowsWebViewControllerPlugin extends WebViewPlatformController {
  final WinWebViewController controller;
  final JavascriptChannelRegistry channelRegistry;

  _WindowsWebViewControllerPlugin(super.handler, this.controller, this.channelRegistry) {
    controller.setJavascriptChannelMessageCallback(((channelName, message) {
      channelRegistry.onJavascriptChannelMessage(channelName, message);
    }));
  }

  String title = "";
  void _setTitle(String title) => this.title = title;

  @override
  Future<void> addJavascriptChannels(Set<String> javascriptChannelNames) async {
    for (var channelName in javascriptChannelNames) {
      controller.addScriptChannelByName(channelName);
    }
  }

  @override
  Future<void> removeJavascriptChannels(Set<String> javascriptChannelNames) async {
    for (var channelName in javascriptChannelNames) {
      controller.removeScriptChannelByName(channelName);
    }
  }

  @override
  Future<bool> canGoBack() {
    return controller.canGoBack();
  }

  @override
  Future<bool> canGoForward() {
    return controller.canGoForward();
  }

  @override
  Future<void> clearCache() {
    return controller.clearCache();
  }

  @override
  Future<String?> currentUrl() {
    return controller.currentUrl();
  }

  @override
  Future<String> evaluateJavascript(String javascript) {
    // deprecated in official
    return runJavascriptReturningResult(javascript);
  }

  @override
  Future<int> getScrollX() async {
    // WebView2 not support
    return 0;
  }

  @override
  Future<int> getScrollY() async {
    // WebView2 not support
    return 0;
  }

  @override
  Future<String?> getTitle() async {
    return title;
  }

  @override
  Future<void> goBack() {
    return controller.goBack();
  }

  @override
  Future<void> goForward() {
    return controller.goForward();
  }

  @override
  Future<void> loadFile(String absoluteFilePath) {
    return controller.loadUrl(absoluteFilePath);
  }

  @override
  Future<void> loadFlutterAsset(String key) {
    throw UnimplementedError('Windows webview not support load from assets');
  }

  @override
  Future<void> loadHtmlString(String html, {String? baseUrl}) {
    if (baseUrl != null) {
      log("[webview_win_floating] baseUrl in loadHtmlString() is not support in Windows WebView");
    }
    return controller.loadHtmlString(html);
  }

  @override
  Future<void> loadRequest(WebViewRequest request) {
    throw UnimplementedError();
  }

  @override
  Future<void> loadUrl(String url, Map<String, String>? headers) {
    if (headers != null) {
      log("[webview_win_floating] headers in loadUrl() is not support in Windows WebView");
    }
    return controller.loadUrl(url);
  }

  @override
  Future<void> reload() {
    return controller.reload();
  }

  @override
  Future<void> runJavascript(String javascript) {
    return controller.runJavascript(javascript);
  }

  @override
  Future<String> runJavascriptReturningResult(String javascript) {
    return controller.runJavascriptReturningResult(javascript);
  }

  @override
  Future<void> scrollBy(int x, int y) async {
    log("[webview_win_floaing] scrollBy() is not support in windows webview");
  }

  @override
  Future<void> scrollTo(int x, int y) async {
    log("[webview_win_floaing] scrollTo() is not support in windows webview");
  }

  @override
  Future<void> updateSettings(WebSettings setting) async {
     await controller.enableJavascript(setting.javascriptMode == JavascriptMode.unrestricted);
     if (setting.userAgent.isPresent && setting.userAgent.value != null) controller.setUserAgent(setting.userAgent.value!);
  }
}