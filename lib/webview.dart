export 'webview_plugin.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:fullscreen_window/fullscreen_window.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'layout_notify_widget.dart';
import 'webview_win_floating_platform_interface.dart';

class WinNavigationDelegate {
  final NavigationRequestCallback? onNavigationRequest;
  final PageEventCallback? onPageStarted;
  final PageEventCallback? onPageFinished;
  final ProgressCallback? onProgress;
  final WebResourceErrorCallback? onWebResourceError;

  final PageTitleChangedCallback? onPageTitleChanged;
  final FullScreenChangedCallback? onFullScreenChanged;
  final HistoryChangedCallback? onHistoryChanged;

  WinNavigationDelegate({
    this.onNavigationRequest,
    this.onPageStarted,
    this.onPageFinished,
    this.onProgress,
    this.onWebResourceError,
    this.onPageTitleChanged,
    this.onFullScreenChanged,
    this.onHistoryChanged,
  });
}

typedef WebViewCreatedCallback = void Function(
    WinWebViewController webViewController);
typedef PageStartedCallback = void Function(String url);
typedef PageFinishedCallback = void Function(String url);
typedef PageTitleChangedCallback = void Function(String title);
typedef JavaScriptMessageCallback = void Function(JavaScriptMessage message);
typedef FullScreenChangedCallback = void Function(bool isFullScreen);
typedef MoveFocusRequestCallback = void Function(bool isNext);
typedef HistoryChangedCallback = void Function();

class WinWebViewWidget extends StatefulWidget {
  final WinWebViewController controller;

  const WinWebViewWidget({
    Key? key,
    required this.controller,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _WinWebViewWidgetState();
}

class _WinWebViewWidgetState extends State<WinWebViewWidget> {
  late double devicePixelRatio;

  @override
  void activate() {
    super.activate();
    widget.controller._setVisibility(true);
  }

  @override
  void deactivate() {
    super.deactivate();
    widget.controller._setVisibility(false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
  }

  @override
  void dispose() {
    super.dispose();
    widget.controller._dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.controller._backgroundColor,
      child: WidgetLayoutWrapper(
        onLayoutChange: (offset, size) {
          widget.controller._updateBounds(offset, size, devicePixelRatio);
        },
        child: Container(),
      ),
    );
  }
}

// --------------------------------------------------------------------------

int _gLastWebViewId = 0;

class WinWebViewController {
  final _webviewId = ++_gLastWebViewId;
  late Future<bool> _initFuture;
  WinNavigationDelegate? _navigationDelegate;
  final _javaScriptMessageCallbacks = <String, JavaScriptMessageCallback>{};
  String? _currentUrl;
  String? _currentTitle;
  Color? _backgroundColor;

  WinWebViewController() {
    WebviewWinFloatingPlatform.instance.registerWebView(_webviewId, this);
    _initFuture = WebviewWinFloatingPlatform.instance.create(_webviewId, null);
  }

  Future<void> setNavigationDelegate(WinNavigationDelegate delegate) async {
    _navigationDelegate = delegate;
  }

  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {
    bool isEnable = javaScriptMode == JavaScriptMode.unrestricted;
    await _initFuture;
    await WebviewWinFloatingPlatform.instance
        .enableJavascript(_webviewId, isEnable);
  }

  Future<void> addJavaScriptChannel(String name,
      {required JavaScriptMessageCallback callback}) async {
    bool isExists = _javaScriptMessageCallbacks.containsKey(name);
    _javaScriptMessageCallbacks[name] = callback;
    if (!isExists) {
      await _initFuture;
      await WebviewWinFloatingPlatform.instance
          .addScriptChannelByName(_webviewId, name);
    }
  }

  Future<void> removeJavaScriptChannel(String name) async {
    bool isExists = _javaScriptMessageCallbacks.containsKey(name);
    _javaScriptMessageCallbacks.remove(name);
    if (!isExists) {
      await _initFuture;
      await WebviewWinFloatingPlatform.instance
          .removeScriptChannelByName(_webviewId, name);
    }
  }

  void notifyMessageReceived_(String message) {
    //print("notifyMessageReceived_: $message");
    final jobj = json.decode(message);
    var channelName = jobj["JkChannelName"];
    if (channelName != null) {
      String jStr = jobj["msg"];

      var callback = _javaScriptMessageCallbacks[channelName];
      if (callback != null) {
        callback(JavaScriptMessage(message: jStr));
      }
    }
  }

  void notifyOnPageStarted_(
      String url, bool isNewWindow, bool isUserInitiated) async {
    // NOTE: in [webview_flutter], every time user click a url will cancel it first,
    //       and ask client by onNavigationRequest().
    //       if client returns cancel, then do nothing
    //       if client returns yes, then call loadUrl(url)

    if (_navigationDelegate == null) return;

    if (isUserInitiated && _navigationDelegate!.onNavigationRequest != null) {
      NavigationDecision decision =
          await _navigationDelegate!.onNavigationRequest!(
              NavigationRequest(url: url, isMainFrame: !isNewWindow));
      bool isAllowed = (decision == NavigationDecision.navigate);
      if (isAllowed) loadRequest_(url);
      return;
    }

    _currentUrl = url;
    if (_navigationDelegate!.onPageStarted != null) {
      _navigationDelegate!.onPageStarted!(url);
    }
  }

  void notifyOnPageFinished_(String url, int errCode) {
    if (errCode == 0) {
      if (_navigationDelegate?.onPageFinished != null) {
        _navigationDelegate!.onPageFinished!(url);
      }
    } else {
      if (_navigationDelegate?.onWebResourceError != null) {
        var err = WebResourceError(errorCode: errCode, description: "");
        _navigationDelegate!.onWebResourceError!(err);
      }
    }
  }

  void notifyOnPageTitleChanged_(String title) {
    _currentTitle = title;
    if (_navigationDelegate?.onPageTitleChanged == null) return;
    _navigationDelegate!.onPageTitleChanged!(title);
  }

  MoveFocusRequestCallback? onMoveFocusRequestCallback;
  void notifyOnFocusRequest_(bool isNext) {
    if (onMoveFocusRequestCallback != null) onMoveFocusRequestCallback!(isNext);
  }

  void notifyFullScreenChanged_(bool isFullScreen) {
    setFullScreen(isFullScreen);
    FullScreenWindow.setFullScreen(isFullScreen);
    if (_navigationDelegate?.onFullScreenChanged != null) {
      _navigationDelegate!.onFullScreenChanged!(isFullScreen);
    }
  }

  void notifyHistoryChanged_() {
    if (_navigationDelegate?.onHistoryChanged != null) {
      _navigationDelegate!.onHistoryChanged!();
    }
  }

  bool _isNowFullScreen = false;
  late Offset _lastLayoutOffset;
  late Size _lastLayoutSize;
  late double _lastDevicePixelRatio;
  Future<void> _updateBounds(
      Offset offset, Size size, double devicePixelRatio) async {
    await _initFuture;
    if (!_isNowFullScreen) {
      _lastLayoutOffset = offset;
      _lastLayoutSize = size;
      _lastDevicePixelRatio = devicePixelRatio;
      // NOTE: DO NOT update webview bounds when fullscreen
      await _initFuture;
      await WebviewWinFloatingPlatform.instance.updateBounds(_webviewId,
          _lastLayoutOffset, _lastLayoutSize, _lastDevicePixelRatio);
    }
  }

  Future<void> _setVisibility(bool isVisible) async {
    await _initFuture;
    await WebviewWinFloatingPlatform.instance
        .setVisibility(_webviewId, isVisible);
  }

  void setFullScreen(bool bEnable) async {
    _isNowFullScreen = bEnable;
    await _initFuture;
    WebviewWinFloatingPlatform.instance.setFullScreen(_webviewId, bEnable);
    if (!bEnable) {
      await WebviewWinFloatingPlatform.instance.updateBounds(_webviewId,
          _lastLayoutOffset, _lastLayoutSize, _lastDevicePixelRatio);
    }
  }

  Future<void> loadRequest(Uri uri,
      {LoadRequestMethod method = LoadRequestMethod.get,
      Map<String, String> headers = const <String, String>{},
      Uint8List? body}) {
    return loadRequest_(uri.toString(),
        method: method, headers: headers, body: body);
  }

  Future<void> loadRequest_(String url,
      {LoadRequestMethod method = LoadRequestMethod.get,
      Map<String, String> headers = const <String, String>{},
      Uint8List? body}) async {
    if (method != LoadRequestMethod.get || headers.isNotEmpty || body != null) {
      log("[webview_win_floating] loadRequest() doesn't support headers / body / post / update / delete");
    }
    await _initFuture;
    await WebviewWinFloatingPlatform.instance.loadUrl(_webviewId, url);
  }

  Future<void> loadHtmlString(String html) async {
    await _initFuture;
    await WebviewWinFloatingPlatform.instance.loadHtmlString(_webviewId, html);
  }

  Future<void> runJavaScript(String javaScriptString) async {
    await _initFuture;
    await WebviewWinFloatingPlatform.instance
        .runJavaScript(_webviewId, javaScriptString);
  }

  Future<Object> runJavaScriptReturningResult(String javaScriptString) async {
    await _initFuture;
    return await WebviewWinFloatingPlatform.instance
        .runJavaScriptReturningResult(_webviewId, javaScriptString);
  }

  Future<void> addScriptChannelByName(String channelName) async {
    await _initFuture;
    await WebviewWinFloatingPlatform.instance
        .addScriptChannelByName(_webviewId, channelName);
  }

  Future<void> removeScriptChannelByName(String channelName) async {
    await _initFuture;
    await WebviewWinFloatingPlatform.instance
        .removeScriptChannelByName(_webviewId, channelName);
  }

  Future<void> setUserAgent(String? userAgent) async {
    if (userAgent == null) return;
    await _initFuture;
    await WebviewWinFloatingPlatform.instance
        .setUserAgent(_webviewId, userAgent);
  }

  Future<void> requestFocus() async {
    await _initFuture;
    return await WebviewWinFloatingPlatform.instance.requestFocus(_webviewId);
  }

  Future<void> setBackgroundColor(Color color) async {
    await _initFuture;
    _backgroundColor = color;
    return await WebviewWinFloatingPlatform.instance
        .setBackgroundColor(_webviewId, color);
  }
  //

  Future<bool> canGoBack() async {
    await _initFuture;
    return await WebviewWinFloatingPlatform.instance.canGoBack(_webviewId);
  }

  Future<bool> canGoForward() async {
    await _initFuture;
    return await WebviewWinFloatingPlatform.instance.canGoForward(_webviewId);
  }

  Future<void> goBack() async {
    await _initFuture;
    await WebviewWinFloatingPlatform.instance.goBack(_webviewId);
  }

  Future<void> goForward() async {
    await _initFuture;
    await WebviewWinFloatingPlatform.instance.goForward(_webviewId);
  }

  Future<void> reload() async {
    await _initFuture;
    await WebviewWinFloatingPlatform.instance.reload(_webviewId);
  }

  Future<void> cancelNavigate() async {
    await _initFuture;
    await WebviewWinFloatingPlatform.instance.cancelNavigate(_webviewId);
  }

  Future<void> clearCache() async {
    await _initFuture;
    await WebviewWinFloatingPlatform.instance.clearCache(_webviewId);
  }

  Future<void> clearLocalStorage() async {
    await _initFuture;
    await WebviewWinFloatingPlatform.instance.clearCache(_webviewId);
  }

  Future<void> clearCookies() async {
    await _initFuture;
    await WebviewWinFloatingPlatform.instance.clearCookies(_webviewId);
  }

  //

  Future<String?> currentUrl() {
    return Future.value(_currentUrl);
  }

  Future<String?> getTitle() {
    return Future.value(_currentTitle);
  }

  //

  Future<void> _dispose() async {
    await _initFuture;
    WebviewWinFloatingPlatform.instance.unregisterWebView(_webviewId);
    await WebviewWinFloatingPlatform.instance.dispose(_webviewId);
  }

  Future<void> openDevTools() async {
    await _initFuture;
    await WebviewWinFloatingPlatform.instance.openDevTools(_webviewId);
  }
}
