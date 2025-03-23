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

// ignore: must_be_immutable
class WinWebViewPermissionRequest extends PlatformWebViewPermissionRequest {
  final WinWebViewController _controller;
  final int _deferralId;
  final String url;
  final WinPermissionKind kind;
  bool _isDone = false;

  WinWebViewPermissionRequest._(
      this._controller, this._deferralId, this.url, this.kind)
      : super(types: {
          WebViewPermissionResourceType.camera,
          WebViewPermissionResourceType.microphone
        });

  @override
  Future<void> grant() async {
    if (_isDone) {
      print(
          "WinWebViewPermissionRequest: already called grant() or deny() before. ignored");
      return;
    }

    _controller.grantPermission(_deferralId, true);
    _isDone = true;
  }

  @override
  Future<void> deny() async {
    if (_isDone) {
      print(
          "WinWebViewPermissionRequest: already called grant() or deny() before. ignored");
      return;
    }

    _controller.grantPermission(_deferralId, false);
    _isDone = true;
  }
}

enum WinPermissionKind {
  unknown,
  microphone,
  camera,
  geoLocation,
  notification,
  otherSensors,
  clipboardRead
} //mapping to COREWEBVIEW2_PERMISSION_KIND

typedef WebViewCreatedCallback = void Function(
    WinWebViewController webViewController);
typedef PageStartedCallback = void Function(String url);
typedef PageFinishedCallback = void Function(String url);
typedef PageTitleChangedCallback = void Function(String title);
typedef JavaScriptMessageCallback = void Function(JavaScriptMessage message);
typedef FullScreenChangedCallback = void Function(bool isFullScreen);
typedef MoveFocusRequestCallback = void Function(bool isNext);
typedef HistoryChangedCallback = void Function();
typedef AskPermissionCallback = bool Function(
    String url, WinPermissionKind kind);

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
  void initState() {
    super.initState();
    widget.controller._resume();
  }

  @override
  void activate() {
    super.activate();
    widget.controller._resume();
  }

  @override
  void deactivate() {
    super.deactivate();
    widget.controller._suspend();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.controller._backgroundColor,
      child: WidgetLayoutWrapperWithScroll(
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
  WinNavigationDelegate _navigationDelegate = WinNavigationDelegate();
  final _javaScriptMessageCallbacks = <String, JavaScriptMessageCallback>{};
  String? _currentUrl;
  String? _currentTitle;
  Color? _backgroundColor;
  void Function(WinWebViewPermissionRequest request)? _onPermissionRequest;

  static final Finalizer<int> _finalizer = Finalizer((id) {
    log("webview controller finalizer: $id");
    _disposeById(id);
  });

  WinWebViewController(
      {String? userDataFolder,
      void Function(WinWebViewPermissionRequest request)?
          onPermissionRequest}) {
    _onPermissionRequest = onPermissionRequest;
    _finalizer.attach(this, _webviewId, detach: this);
    WebviewWinFloatingPlatform.instance.registerWebView(_webviewId, this);
    _initFuture = WebviewWinFloatingPlatform.instance
        .create(_webviewId, initialUrl: null, userDataFolder: userDataFolder);
  }

  Future<void> setNavigationDelegate(WinNavigationDelegate delegate) async {
    _navigationDelegate = delegate;

    bool hasNavigationDecision =
        _navigationDelegate.onNavigationRequest != null;
    await _initFuture;
    await WebviewWinFloatingPlatform.instance
        .setHasNavigationDecision(_webviewId, hasNavigationDecision);
  }

  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {
    bool isEnable = javaScriptMode == JavaScriptMode.unrestricted;
    await _initFuture;
    await WebviewWinFloatingPlatform.instance
        .enableJavascript(_webviewId, isEnable);
  }

  Future<void> addJavaScriptChannel(String name,
      {required JavaScriptMessageCallback onMessageReceived}) async {
    bool isExists = _javaScriptMessageCallbacks.containsKey(name);
    _javaScriptMessageCallbacks[name] = onMessageReceived;
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
    // isUserInitiated==true when user click a link
    // isUserInitiated==false when loadRequest() called
    // NOTE: in [webview_flutter], every time user click a url will cancel it first,
    //       and ask client by onNavigationRequest().
    //       if client returns cancel, then do nothing
    //       if client returns yes, then call loadUrl(url)

    if (isUserInitiated && _navigationDelegate.onNavigationRequest != null) {
      NavigationDecision decision = NavigationDecision.navigate;
      decision = await _navigationDelegate.onNavigationRequest!(
          NavigationRequest(url: url, isMainFrame: !isNewWindow));
      bool isAllowed = (decision == NavigationDecision.navigate);
      if (isAllowed) loadRequest_(url);
      return;
    }

    _currentUrl = url;
    if (_navigationDelegate.onPageStarted != null) {
      _navigationDelegate.onPageStarted!(url);
    }
  }

  void notifyOnPageFinished_(String url, int errCode) {
    if (errCode == 0) {
      if (_navigationDelegate.onPageFinished != null) {
        _navigationDelegate.onPageFinished!(url);
      }
    } else {
      if (_navigationDelegate.onWebResourceError != null) {
        var err = WebResourceError(errorCode: errCode, description: "");
        _navigationDelegate.onWebResourceError!(err);
      }
    }
  }

  void notifyOnPageTitleChanged_(String title) {
    _currentTitle = title;
    if (_navigationDelegate.onPageTitleChanged == null) return;
    _navigationDelegate.onPageTitleChanged!(title);
  }

  MoveFocusRequestCallback? onMoveFocusRequestCallback;
  void notifyOnFocusRequest_(bool isNext) {
    if (onMoveFocusRequestCallback != null) onMoveFocusRequestCallback!(isNext);
  }

  void notifyFullScreenChanged_(bool isFullScreen) {
    setFullScreen(isFullScreen);
    FullScreenWindow.setFullScreen(isFullScreen);
    if (_navigationDelegate.onFullScreenChanged != null) {
      _navigationDelegate.onFullScreenChanged!(isFullScreen);
    }
  }

  void notifyHistoryChanged_() {
    if (_navigationDelegate.onHistoryChanged != null) {
      _navigationDelegate.onHistoryChanged!();
    }
  }

  void setOnPlatformPermissionRequest_(
      void Function(PlatformWebViewPermissionRequest request)
          onPermissionRequest) {
    _onPermissionRequest = onPermissionRequest;
  }

  void notifyAskPermission_(
      String url, WinPermissionKind kind, int deferralId) {
    if (_onPermissionRequest != null) {
      var req = WinWebViewPermissionRequest._(this, deferralId, url, kind);
      _onPermissionRequest!(req);
    } else {
      // if user not listen to permission request, always deny
      grantPermission(deferralId, false);
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

  Future<void> _suspend() async {
    await _initFuture;
    await WebviewWinFloatingPlatform.instance.suspend(_webviewId);
  }

  Future<void> _resume() async {
    await _initFuture;
    await WebviewWinFloatingPlatform.instance.resume(_webviewId);
  }

  Future<void> dispose() async {
    await _initFuture;
    _finalizer.detach(this);
    _disposeById(_webviewId);
  }

  static Future<void> _disposeById(int webviewId) async {
    WebviewWinFloatingPlatform.instance.unregisterWebView(webviewId);
    await WebviewWinFloatingPlatform.instance.dispose(webviewId);
  }

  Future<void> grantPermission(int deferralId, bool isGranted) async {
    await _initFuture;
    await WebviewWinFloatingPlatform.instance
        .grantPermission(_webviewId, deferralId, isGranted);
  }

  Future<void> enableZoom(bool isEnable) async {
    await _initFuture;
    await WebviewWinFloatingPlatform.instance.enableZoom(_webviewId, isEnable);
  }

  // ------------------------------------------------------------------------
  // Windows-only methods
  // ------------------------------------------------------------------------

  Future<void> openDevTools() async {
    await _initFuture;
    await WebviewWinFloatingPlatform.instance.openDevTools(_webviewId);
  }

  Future<void> setStatusBar(bool isEnable) async {
    await _initFuture;
    await WebviewWinFloatingPlatform.instance
        .enableStatusBar(_webviewId, isEnable);
  }
}
