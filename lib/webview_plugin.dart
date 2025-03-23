import 'dart:developer';

import 'package:flutter/widgets.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:webview_win_floating/webview.dart';

class WindowsWebViewPlatform extends WebViewPlatform {
  /// Registers this class as the default instance of [WebViewPlatform].
  static void registerWith() {
    WebViewPlatform.instance = WindowsWebViewPlatform();
  }

  @override
  WindowsPlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) {
    return WindowsPlatformNavigationDelegate(params);
  }

  @override
  WindowsPlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    return WindowsPlatformWebViewController(params);
  }

  @override
  WindowsPlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) {
    return WindowsPlatformWebViewWidget(params);
  }

  @override
  WindowsPlatformWebViewCookieManager createPlatformCookieManager(
    PlatformWebViewCookieManagerCreationParams params,
  ) {
    return WindowsPlatformWebViewCookieManager(params);
  }
}

// --------------------------------------------------------------------------
// navigation delegate
// --------------------------------------------------------------------------

class WindowsPlatformNavigationDelegate extends PlatformNavigationDelegate {
  NavigationRequestCallback? onNavigationRequest;
  PageEventCallback? onPageStarted;
  PageEventCallback? onPageFinished;
  WebResourceErrorCallback? onWebResourceError;

  WindowsPlatformNavigationDelegate(
      PlatformNavigationDelegateCreationParams params)
      : super.implementation(params);

  @override
  Future<void> setOnNavigationRequest(
      NavigationRequestCallback onNavigationRequest) async {
    this.onNavigationRequest = onNavigationRequest;
  }

  @override
  Future<void> setOnPageStarted(PageEventCallback onPageStarted) async {
    this.onPageStarted = onPageStarted;
  }

  @override
  Future<void> setOnPageFinished(PageEventCallback onPageFinished) async {
    this.onPageFinished = onPageFinished;
  }

  @override
  Future<void> setOnProgress(ProgressCallback onProgress) async {
    log("[webview_win_floating] ProgressCallback not support");
  }

  @override
  Future<void> setOnWebResourceError(
      WebResourceErrorCallback onWebResourceError) async {
    this.onWebResourceError = onWebResourceError;
  }
}

// --------------------------------------------------------------------------
// webview
// --------------------------------------------------------------------------

@immutable
class WindowsPlatformWebViewWidgetCreationParams
    extends PlatformWebViewWidgetCreationParams {
  const WindowsPlatformWebViewWidgetCreationParams({
    super.key,
    required super.controller,
  });
}

class WindowsPlatformWebViewWidget extends PlatformWebViewWidget {
  WindowsPlatformWebViewWidget(PlatformWebViewWidgetCreationParams params)
      : super.implementation(params);

  @override
  Widget build(BuildContext context) {
    var controller = params.controller as WindowsPlatformWebViewController;
    return WinWebViewWidget(controller: controller.controller);
  }
}

// --------------------------------------------------------------------------
// controller
// --------------------------------------------------------------------------

@immutable
class WindowsPlatformWebViewControllerCreationParams
    extends PlatformWebViewControllerCreationParams {
  final String? userDataFolder;

  /// Creates a new [WindowsPlatformWebViewControllerCreationParams] instance.
  const WindowsPlatformWebViewControllerCreationParams({this.userDataFolder})
      : super();

  /// Creates a [WindowsPlatformWebViewControllerCreationParams] instance based on [PlatformWebViewControllerCreationParams].
  factory WindowsPlatformWebViewControllerCreationParams.fromPlatformWebViewControllerCreationParams(
      // Recommended placeholder to prevent being broken by platform interface.
      // ignore: avoid_unused_constructor_parameters
      PlatformWebViewControllerCreationParams params) {
    return const WindowsPlatformWebViewControllerCreationParams();
  }
}

class WindowsPlatformWebViewController extends PlatformWebViewController {
  late final WinWebViewController controller;

  WindowsPlatformWebViewController(
      PlatformWebViewControllerCreationParams params)
      : super.implementation(params) {
    String? userDataFolder;
    if (params is WindowsPlatformWebViewControllerCreationParams) {
      userDataFolder = params.userDataFolder;
    }
    controller = WinWebViewController(userDataFolder: userDataFolder);
  }

  @override
  Future<void> setPlatformNavigationDelegate(
      PlatformNavigationDelegate handler) async {
    var delegate = handler as WindowsPlatformNavigationDelegate;
    controller.setNavigationDelegate(WinNavigationDelegate(
      onNavigationRequest: delegate.onNavigationRequest,
      onPageStarted: delegate.onPageStarted,
      onPageFinished: delegate.onPageFinished,
      onWebResourceError: delegate.onWebResourceError,
    ));
  }

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) {
    return controller.setJavaScriptMode(javaScriptMode);
  }

  @override
  Future<void> addJavaScriptChannel(
      JavaScriptChannelParams javaScriptChannelParams) async {
    controller.addJavaScriptChannel(javaScriptChannelParams.name,
        onMessageReceived: javaScriptChannelParams.onMessageReceived);
  }

  @override
  Future<void> removeJavaScriptChannel(String javaScriptChannelName) async {
    controller.removeJavaScriptChannel(javaScriptChannelName);
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
  Future<void> clearLocalStorage() {
    return controller.clearLocalStorage();
  }

  @override
  Future<String?> currentUrl() {
    return controller.currentUrl();
  }

  @override
  Future<Offset> getScrollPosition() async {
    // WebView2 not support
    log("[webview_win_floating] getScrollPosition() not support for WebView2");
    return Offset.zero;
  }

  @override
  Future<String?> getTitle() {
    return controller.getTitle();
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
    return controller.loadRequest_(absoluteFilePath);
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
  Future<void> loadRequest(LoadRequestParams params) {
    return controller.loadRequest(params.uri,
        method: params.method, headers: params.headers, body: params.body);
  }

  @override
  Future<void> reload() {
    return controller.reload();
  }

  @override
  Future<void> runJavaScript(String javaScript) {
    return controller.runJavaScript(javaScript);
  }

  @override
  Future<Object> runJavaScriptReturningResult(String javaScript) {
    return controller.runJavaScriptReturningResult(javaScript);
  }

  @override
  Future<void> setUserAgent(String? userAgent) {
    return controller.setUserAgent(userAgent);
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
  Future<void> setBackgroundColor(Color color) {
    return controller.setBackgroundColor(color);
  }

  @override
  Future<void> setOnPlatformPermissionRequest(
    void Function(PlatformWebViewPermissionRequest request) onPermissionRequest,
  ) async {
    controller.setOnPlatformPermissionRequest_(onPermissionRequest);
  }

  @override
  Future<void> enableZoom(bool isEnable) {
    return controller.enableZoom(isEnable);
  }

  // ------------------------------------------------------------------------
  // Windows-only methods
  // ------------------------------------------------------------------------

  Future<void> openDevTools() {
    return controller.openDevTools();
  }

  Future<void> setStatusBar(bool isEnable) {
    return controller.setStatusBar(isEnable);
  }
}

// --------------------------------------------------------------------------
// cookie manager
// --------------------------------------------------------------------------

@immutable
class WindowsPlatformWebViewCookieManagerCreationParams
    extends PlatformWebViewCookieManagerCreationParams {
  const WindowsPlatformWebViewCookieManagerCreationParams._(
    PlatformWebViewCookieManagerCreationParams params,
  ) : super();

  factory WindowsPlatformWebViewCookieManagerCreationParams.fromPlatformWebViewCookieManagerCreationParams(
      PlatformWebViewCookieManagerCreationParams params) {
    return WindowsPlatformWebViewCookieManagerCreationParams._(params);
  }
}

class WindowsPlatformWebViewCookieManager extends PlatformWebViewCookieManager {
  WindowsPlatformWebViewCookieManager(
      PlatformWebViewCookieManagerCreationParams params)
      : super.implementation(params);

  @override
  Future<bool> clearCookies() async {
    log("[webview_win_floating] clearCookies() not support. try controller.clearCache() instead");
    return false;
  }

  @override
  Future<void> setCookie(WebViewCookie cookie) async {
    log("[webview_win_floating] setCookie() not support");
  }
}
