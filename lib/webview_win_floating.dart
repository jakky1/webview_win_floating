export 'webview_plugin.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:fullscreen_window/fullscreen_window.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:webview_win_floating/webview_plugin.dart';

import 'layout_notify_widget.dart';
import 'webview_win_floating_platform_interface.dart';

class WinNavigationDelegate {
  final NavigationRequestCallback? onNavigationRequest;
  final PageEventCallback? onPageStarted;
  final PageEventCallback? onPageFinished;
  final HttpResponseErrorCallback? onHttpError;
  final SslAuthErrorCallback? onSslAuthError;
  final ProgressCallback? onProgress;
  final WebResourceErrorCallback? onWebResourceError;

  final UrlChangedCallback? onUrlChange;
  final PageTitleChangedCallback? onPageTitleChanged;
  final FullScreenChangedCallback? onFullScreenChanged;
  final HistoryChangedCallback? onHistoryChanged;

  WinNavigationDelegate({
    this.onNavigationRequest,
    this.onPageStarted,
    this.onPageFinished,
    this.onHttpError,
    this.onSslAuthError,
    this.onProgress,
    this.onWebResourceError,
    this.onUrlChange,
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
  final WinWebViewPermissionResourceType kind;
  bool _isDone = false;
  late final PlatformWebViewPermissionRequest platform = this;

  WinWebViewPermissionRequest._(
    this._controller,
    this._deferralId,
    this.url,
    this.kind,
  ) : super(
          types: {
            WebViewPermissionResourceType.camera,
            WebViewPermissionResourceType.microphone,
          },
        );

  @override
  Future<void> grant() async {
    if (_isDone) {
      print(
        "[webview_win_floating] WinWebViewPermissionRequest: already called grant() or deny() before. ignored",
      );
      return;
    }

    _controller.grantPermission(_deferralId, true);
    _isDone = true;
  }

  @override
  Future<void> deny() async {
    if (_isDone) {
      print(
        "[webview_win_floating] WinWebViewPermissionRequest: already called grant() or deny() before. ignored",
      );
      return;
    }

    _controller.grantPermission(_deferralId, false);
    _isDone = true;
  }

  Future<void> denyIfNoAction() async {
    if (_isDone) return;
    print(
        "[webview_win_floating] onPermissionRequest() doesn't call grant() or deny()!");
    _controller.grantPermission(_deferralId, false);
    _isDone = true;
  }
}

class WinSslAuthError extends PlatformSslAuthError {
  final String url;
  WinSslAuthError(
      {required this.url,
      required super.certificate,
      required super.description});

  @override
  Future<void> cancel() async {}

  @override
  Future<void> proceed() async {
    print(
        "[webview_win_floating] onSslAuthError(): WinSslAuthError.proceed() do nothing. Always skip websites with ssl auth error");
  }
}

enum WinWebViewPermissionResourceType {
  unknown,
  microphone,
  camera,
  geoLocation,
  notification,
  otherSensors,
  clipboardRead,
} //mapping to COREWEBVIEW2_PERMISSION_KIND

typedef WebViewCreatedCallback = void Function(
    WinWebViewController webViewController);
typedef PageStartedCallback = void Function(String url);
typedef PageFinishedCallback = void Function(String url);
typedef UrlChangedCallback = void Function(UrlChange url);
typedef PageTitleChangedCallback = void Function(String title);
typedef JavaScriptMessageCallback = void Function(JavaScriptMessage message);
typedef FullScreenChangedCallback = void Function(bool isFullScreen);
typedef MoveFocusRequestCallback = void Function(bool isNext);
typedef HistoryChangedCallback = void Function();
typedef AskPermissionCallback = bool Function(
    String url, WinWebViewPermissionResourceType kind);

class WinWebViewWidget extends StatefulWidget {
  final WinWebViewController controller;

  const WinWebViewWidget({Key? key, required this.controller})
      : super(key: key);

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
    if (widget.controller.params.suspendDuringDeactive) {
      widget.controller._resume();
    } else {
      widget.controller._setVisibility(true);
    }
  }

  @override
  void deactivate() {
    super.deactivate();
    if (widget.controller.params.suspendDuringDeactive) {
      widget.controller._suspend();
    } else {
      widget.controller._setVisibility(false);
    }
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
  late final WindowsWebViewControllerCreationParams params;
  void Function(WinWebViewPermissionRequest request)? _onPermissionRequest;

  static final Finalizer<int> _finalizer = Finalizer((id) {
    log("webview controller finalizer: $id");
    _disposeById(id);
  });

  factory WinWebViewController.fromPlatformCreationParams(
      PlatformWebViewControllerCreationParams params,
      {void Function(WinWebViewPermissionRequest request)?
          onPermissionRequest}) {
    return WinWebViewController(
        params: params, onPermissionRequest: onPermissionRequest);
  }

  WinWebViewController({
    PlatformWebViewControllerCreationParams params =
        const WindowsWebViewControllerCreationParams(),
    void Function(WinWebViewPermissionRequest request)? onPermissionRequest,
  }) {
    _onPermissionRequest = onPermissionRequest;
    _finalizer.attach(this, _webviewId, detach: this);
    WebviewWinFloatingPlatform.instance.registerWebView(_webviewId, this);

    if (params is WindowsWebViewControllerCreationParams) {
      this.params = params;
    } else {
      log("[webview_win_floating] variable 'params' is not a 'WindowsWebViewControllerCreationParams' object. type: ${params.runtimeType}");
      this.params = WindowsWebViewControllerCreationParams();
    }

    _initFuture = WebviewWinFloatingPlatform.instance.create(
      _webviewId,
      initialUrl: null,
      userDataFolder: this.params.userDataFolder,
    );
  }

  Future<void> setNavigationDelegate(WinNavigationDelegate delegate) async {
    _navigationDelegate = delegate;

    bool hasNavigationDecision =
        _navigationDelegate.onNavigationRequest != null;
    await _initFuture;
    await WebviewWinFloatingPlatform.instance.setHasNavigationDecision(
      _webviewId,
      hasNavigationDecision,
    );
  }

  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {
    bool isEnable = javaScriptMode == JavaScriptMode.unrestricted;
    await _initFuture;
    await WebviewWinFloatingPlatform.instance.enableJavascript(
      _webviewId,
      isEnable,
    );
  }

  Future<void> addJavaScriptChannel(
    String name, {
    required JavaScriptMessageCallback onMessageReceived,
  }) async {
    bool isExists = _javaScriptMessageCallbacks.containsKey(name);
    _javaScriptMessageCallbacks[name] = onMessageReceived;
    if (!isExists) {
      await _initFuture;
      await WebviewWinFloatingPlatform.instance.addScriptChannelByName(
        _webviewId,
        name,
      );
    }
  }

  Future<void> removeJavaScriptChannel(String name) async {
    bool isExists = _javaScriptMessageCallbacks.containsKey(name);
    _javaScriptMessageCallbacks.remove(name);
    if (!isExists) {
      await _initFuture;
      await WebviewWinFloatingPlatform.instance.removeScriptChannelByName(
        _webviewId,
        name,
      );
    }
  }

  void notifyMessageReceived_(dynamic jobj) {
    //print("notifyMessageReceived_: $message");
    var channelName = jobj["JkChannelName"];
    if (channelName != null) {
      String jStr = jobj["msg"];

      var callback = _javaScriptMessageCallbacks[channelName];
      if (callback != null) {
        callback(JavaScriptMessage(message: jStr));
      }
    }
  }

  void notifyOnNavigationRequest_(
    int requestId,
    String url,
    bool isNewWindow,
  ) async {
    bool isAllowed = true;
    if (_navigationDelegate.onNavigationRequest != null) {
      var decision = await _navigationDelegate.onNavigationRequest!(
        NavigationRequest(url: url, isMainFrame: !isNewWindow),
      );
      isAllowed = (decision == NavigationDecision.navigate);
    }

    await WebviewWinFloatingPlatform.instance.allowNavigationRequest(
      _webviewId,
      requestId,
      isAllowed,
    );
  }

  void notifyOnPageStarted_(String url) async {
    if (_navigationDelegate.onPageStarted != null) {
      _navigationDelegate.onPageStarted!(url);
    }
  }

  void notifyOnPageFinished_(String url) {
    if (_navigationDelegate.onPageFinished != null) {
      _navigationDelegate.onPageFinished!(url);
    }
  }

  void notifyOnHttpError_(String url, int errorCode) {
    if (_navigationDelegate.onPageFinished != null) {
      var uri = Uri.parse(url);
      var request = WebResourceRequest(uri: uri);
      var response = WebResourceResponse(uri: uri, statusCode: errorCode);
      var error = HttpResponseError(request: request, response: response);
      _navigationDelegate.onHttpError!(error);
    }
  }

  void notifyOnSslAuthError_(String url) {
    if (_navigationDelegate.onSslAuthError != null) {
      var error = WinSslAuthError(url: url, certificate: null, description: "");
      _navigationDelegate.onSslAuthError!(error);
    }
  }

  void notifyOnUrlChange_(String url) {
    _currentUrl = url;
    if (_navigationDelegate.onUrlChange == null) return;
    _navigationDelegate.onUrlChange!(UrlChange(url: url));
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
    void Function(PlatformWebViewPermissionRequest request) onPermissionRequest,
  ) {
    _onPermissionRequest = onPermissionRequest;
  }

  void notifyAskPermission_(
    String url,
    WinWebViewPermissionResourceType kind,
    int deferralId,
  ) {
    if (_onPermissionRequest != null) {
      var req = WinWebViewPermissionRequest._(this, deferralId, url, kind);
      _onPermissionRequest!(req);
      req.denyIfNoAction();
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
    Offset offset,
    Size size,
    double devicePixelRatio,
  ) async {
    await _initFuture;
    if (!_isNowFullScreen) {
      _lastLayoutOffset = offset;
      _lastLayoutSize = size;
      _lastDevicePixelRatio = devicePixelRatio;
      // NOTE: DO NOT update webview bounds when fullscreen
      await _initFuture;
      await WebviewWinFloatingPlatform.instance.updateBounds(
        _webviewId,
        _lastLayoutOffset,
        _lastLayoutSize,
        _lastDevicePixelRatio,
      );
    }
  }

  Future<void> _setVisibility(bool isVisible) async {
    await _initFuture;
    await WebviewWinFloatingPlatform.instance.setVisibility(
      _webviewId,
      isVisible,
    );
  }

  void setFullScreen(bool bEnable) async {
    _isNowFullScreen = bEnable;
    await _initFuture;
    WebviewWinFloatingPlatform.instance.setFullScreen(_webviewId, bEnable);
    if (!bEnable) {
      await WebviewWinFloatingPlatform.instance.updateBounds(
        _webviewId,
        _lastLayoutOffset,
        _lastLayoutSize,
        _lastDevicePixelRatio,
      );
    }
  }

  Future<void> loadRequest(
    Uri uri, {
    LoadRequestMethod method = LoadRequestMethod.get,
    Map<String, String> headers = const <String, String>{},
    Uint8List? body,
  }) {
    return loadRequest_(
      uri.toString(),
      method: method,
      headers: headers,
      body: body,
    );
  }

  Future<void> loadRequest_(
    String url, {
    LoadRequestMethod method = LoadRequestMethod.get,
    Map<String, String> headers = const <String, String>{},
    Uint8List? body,
  }) async {
    if (method != LoadRequestMethod.get || headers.isNotEmpty || body != null) {
      log(
        "[webview_win_floating] loadRequest() doesn't support headers / body / post / update / delete",
      );
    }
    await _initFuture;
    await WebviewWinFloatingPlatform.instance.loadUrl(_webviewId, url);
  }

  Future<void> loadHtmlString(String html, {String? baseUrl}) async {
    await _initFuture;
    await WebviewWinFloatingPlatform.instance
        .loadHtmlString(_webviewId, html, baseUrl);
  }

  Future<void> runJavaScript(String javaScriptString) async {
    await _initFuture;
    await WebviewWinFloatingPlatform.instance.runJavaScript(
      _webviewId,
      javaScriptString,
    );
  }

  Future<Object> runJavaScriptReturningResult(String javaScriptString) async {
    await _initFuture;
    return await WebviewWinFloatingPlatform.instance
        .runJavaScriptReturningResult(_webviewId, javaScriptString);
  }

  Future<void> addScriptChannelByName(String channelName) async {
    await _initFuture;
    await WebviewWinFloatingPlatform.instance.addScriptChannelByName(
      _webviewId,
      channelName,
    );
  }

  Future<void> removeScriptChannelByName(String channelName) async {
    await _initFuture;
    await WebviewWinFloatingPlatform.instance.removeScriptChannelByName(
      _webviewId,
      channelName,
    );
  }

  Future<void> setUserAgent(String? userAgent) async {
    if (userAgent == null) return;
    await _initFuture;
    await WebviewWinFloatingPlatform.instance.setUserAgent(
      _webviewId,
      userAgent,
    );
  }

  Future<void> requestFocus() async {
    await _initFuture;
    return await WebviewWinFloatingPlatform.instance.requestFocus(_webviewId);
  }

  Future<void> setBackgroundColor(Color color) async {
    await _initFuture;
    _backgroundColor = color;
    return await WebviewWinFloatingPlatform.instance.setBackgroundColor(
      _webviewId,
      color,
    );
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
    await WebviewWinFloatingPlatform.instance.grantPermission(
      _webviewId,
      deferralId,
      isGranted,
    );
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
    await WebviewWinFloatingPlatform.instance.enableStatusBar(
      _webviewId,
      isEnable,
    );
  }
}
