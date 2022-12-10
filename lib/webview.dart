export 'webview_plugin.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:fullscreen_window/fullscreen_window.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'layout_notify_widget.dart';
import 'webview_win_floating_platform_interface.dart';

enum WinNavigationDecision { prevent, navigate }
class WinNavigationRequest {
  String url;
  bool isForMainFrame;
  WinNavigationRequest(this.url, this.isForMainFrame);
}
typedef NavigationDelegate  = FutureOr<WinNavigationDecision> Function(WinNavigationRequest navigation);

typedef WebViewCreatedCallback = void Function(WinWebViewController webViewController);
typedef PageStartedCallback = void Function(String url);
typedef PageFinishedCallback = void Function(String url);
typedef PageTitleChangedCallback = void Function(String title);
typedef WebResourceErrorCallback = void Function(WebResourceError error);
typedef FullScreenChangedCallback = void Function(bool isFullScreen);
typedef JavascriptChannelMessageCallback = void Function(String channelName, String message);
typedef MoveFocusRequestCallback = void Function(bool isNext);

class WinWebView extends StatefulWidget {
  final String? initialUrl;
  final WebViewCreatedCallback? onWebViewCreated;
  final NavigationDelegate? navigationDelegate;
  final PageStartedCallback? onPageStarted;
  final PageFinishedCallback? onPageFinished;
  final PageTitleChangedCallback? onPageTitleChanged;
  final WebResourceErrorCallback? onWebResourceError;
  final FullScreenChangedCallback? onFullScreenChanged;
  final Set<JavascriptChannel>? javascriptChannels;
  final JavascriptMode javascriptMode;
  final String? userAgent;
  final Color? backgroundColor;

  const WinWebView({
    Key? key,
    this.initialUrl,
    this.onWebViewCreated,
    this.navigationDelegate,
    this.onPageStarted,
    this.onPageFinished,
    this.onPageTitleChanged,
    this.onWebResourceError,
    this.onFullScreenChanged,
    this.javascriptChannels,
    this.javascriptMode = JavascriptMode.disabled,
    this.userAgent,
    this.backgroundColor,
    }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _WinWebViewState();
}

class _WinWebViewState extends State<WinWebView> {

  final WinWebViewController _controller = WinWebViewController();
  late double devicePixelRatio;

  @override
  void initState() {
    super.initState();
    _controller._init(this, widget.initialUrl);

    if (widget.javascriptMode == JavascriptMode.disabled) _controller.enableJavascript(false);
    if (widget.onWebViewCreated != null) widget.onWebViewCreated!(_controller);
    if (widget.userAgent != null) _controller.setUserAgent(widget.userAgent!);
    if (widget.backgroundColor != null) _controller.setBackgroundColor(widget.backgroundColor!);

    widget.javascriptChannels?.forEach((channel) {
      _controller.addScriptChannelByName(channel.name);
    });
  }

  @override
  void didUpdateWidget(WinWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.javascriptMode != oldWidget.javascriptMode) {
      _controller.enableJavascript(widget.javascriptMode == JavascriptMode.unrestricted);
    }
    if (widget.userAgent != null && widget.userAgent != oldWidget.userAgent) {
      _controller.setUserAgent(widget.userAgent!);
    }

    // compare javascriptChannels
    if (widget.javascriptChannels != null || oldWidget.javascriptChannels != null) {
      Set<String> oldNames = oldWidget.javascriptChannels?.map((e) => e.name).toSet() ?? <String>{};
      Set<String> nowNames = widget.javascriptChannels?.map((e) => e.name).toSet() ?? <String>{};
      var addNames = nowNames.difference(oldNames);
      var removeNames = oldNames.difference(nowNames);
      for (var name in addNames) {
        _controller.addScriptChannelByName(name);
      }
      for (var name in removeNames) {
        _controller.removeScriptChannelByName(name);
      }
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
    _controller._dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.backgroundColor,
      child: WidgetLayoutWrapperWithScroll(
        onLayoutChange: (offset, size) {
          _controller._updateBounds(offset, size, devicePixelRatio);
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
  Future<bool>? _initFuture;
  late _WinWebViewState _widgetState;
  String? _currentUrl;
  String? _currentTitle;
  JavascriptChannelMessageCallback? _channelMessageCallback;

  Future<bool> _init(_WinWebViewState widgetState, String? initialUrl) async {
    WebviewWinFloatingPlatform.instance.registerWebView(_webviewId, this);
    _initFuture = WebviewWinFloatingPlatform.instance.create(_webviewId, initialUrl);
    _widgetState = widgetState;
    return _initFuture!;
  }

  void setJavascriptChannelMessageCallback(JavascriptChannelMessageCallback cb) {
    _channelMessageCallback = cb;
  }

  void notifyMessageReceived_(String message) {
    //_channelMessageCallback
    //print("notifyMessageReceived_: $message");
    final jobj = json.decode(message);
    var channelName = jobj["JkChannelName"];
    if (channelName != null) {
      String jStr = jobj["msg"];
      if (_channelMessageCallback != null) {
        _channelMessageCallback!(channelName, jStr);
      }

      _widgetState.widget.javascriptChannels?.forEach((e) {
        if (e.name == channelName) {
          e.onMessageReceived(JavascriptMessage(jStr));
        }
      });
    }
  }
  void notifyOnPageStarted_(String url, bool isNewWindow, bool isUserInitiated) async {
    // NOTE: in [webview_flutter], every time user click a url will cancel it first,
    //       and ask client by onNavigationRequest().
    //       if client returns cancel, then do nothing
    //       if client returns yes, then call loadUrl(url)

    if (isUserInitiated) {
      bool isAllowed = true;
      if (_widgetState.widget.navigationDelegate != null) {
        WinNavigationDecision decision = await _widgetState.widget.navigationDelegate!(WinNavigationRequest(url, !isNewWindow));
        isAllowed = (decision == WinNavigationDecision.navigate);
      }

      if (isAllowed) loadUrl(url);
      return;
    }

    _currentUrl = url;
    if (_widgetState.widget.onPageStarted != null) {
      _widgetState.widget.onPageStarted!(url);
    }
  }
  void notifyOnPageFinished_(String url, int errCode) {
    if (errCode == 0) {
      if (_widgetState.widget.onPageFinished != null) {
        _widgetState.widget.onPageFinished!(url);
      }
    } else {
      if (_widgetState.widget.onWebResourceError != null) {
        var err = WebResourceError(errorCode: errCode, description: "", failingUrl: url);
        _widgetState.widget.onWebResourceError!(err);
      }
    }
  }
  void notifyOnPageTitleChanged_(String title) {
    _currentTitle = title;
    if (_widgetState.widget.onPageTitleChanged == null) return;
    _widgetState.widget.onPageTitleChanged!(title);
  }
  MoveFocusRequestCallback? onMoveFocusRequestCallback;
  void notifyOnFocusRequest_(bool isNext) {
    if (onMoveFocusRequestCallback != null) onMoveFocusRequestCallback!(isNext);
  }
  void notifyFullScreenChanged_(bool isFullScreen) {
    setFullScreen(isFullScreen);
    FullScreenWindow.setFullScreen(isFullScreen);
    if (_widgetState.widget.onFullScreenChanged != null) {
      _widgetState.widget.onFullScreenChanged!(isFullScreen);
    }
  }

  bool _isNowFullScreen = false;
  late Offset _lastLayoutOffset;
  late Size _lastLayoutSize;
  late double _lastDevicePixelRatio;
  Future<void> _updateBounds(Offset offset, Size size, double devicePixelRatio) async {
    await _initFuture!;
    if (!_isNowFullScreen) {
      _lastLayoutOffset = offset;
      _lastLayoutSize = size;
      _lastDevicePixelRatio = devicePixelRatio;
      // NOTE: DO NOT update webview bounds when fullscreen
      await WebviewWinFloatingPlatform.instance.updateBounds(_webviewId, _lastLayoutOffset, _lastLayoutSize, _lastDevicePixelRatio);
    }
  }

  void setFullScreen(bool bEnable) async {
    _isNowFullScreen = bEnable;
    WebviewWinFloatingPlatform.instance.setFullScreen(_webviewId, bEnable);
    if (!bEnable) {
      await WebviewWinFloatingPlatform.instance.updateBounds(_webviewId, _lastLayoutOffset, _lastLayoutSize, _lastDevicePixelRatio);
    }
  }

  Future<void> loadUrl(String url) async {
    await _initFuture!;
    await WebviewWinFloatingPlatform.instance.loadUrl(_webviewId, url);
  }

  Future<void> loadHtmlString(String html) async {
    await _initFuture!;
    await WebviewWinFloatingPlatform.instance.loadHtmlString(_webviewId, html);
  }

  Future<void> runJavascript(String javaScriptString) async {
    await _initFuture!;
    await WebviewWinFloatingPlatform.instance.runJavascript(_webviewId, javaScriptString);
  }

  Future<String> runJavascriptReturningResult(String javaScriptString) async {
    await _initFuture!;
    return await WebviewWinFloatingPlatform.instance.runJavascriptReturningResult(_webviewId, javaScriptString);
  }

  Future<void> addScriptChannelByName(String channelName) async {
    await _initFuture!;
    await WebviewWinFloatingPlatform.instance.addScriptChannelByName(_webviewId, channelName);
  }

  Future<void> removeScriptChannelByName(String channelName) async {
    await _initFuture!;
    await WebviewWinFloatingPlatform.instance.removeScriptChannelByName(_webviewId, channelName);
  }

  Future<void> enableJavascript(bool isEnable) async {
    await _initFuture!;
    await WebviewWinFloatingPlatform.instance.enableJavascript(_webviewId, isEnable);
  }

  Future<void> setUserAgent(String userAgent) async {
    await _initFuture!;
    await WebviewWinFloatingPlatform.instance.setUserAgent(_webviewId, userAgent);
  }

  Future<void> requestFocus() async {
    await _initFuture!;
    return await WebviewWinFloatingPlatform.instance.requestFocus(_webviewId);
  }

  Future<void> setBackgroundColor(Color color) async {
    await _initFuture!;
    return await WebviewWinFloatingPlatform.instance.setBackgroundColor(_webviewId, color);
  }
  //

  Future<bool> canGoBack() async {
    await _initFuture!;
    return await WebviewWinFloatingPlatform.instance.canGoBack(_webviewId);
  }

  Future<bool> canGoForward() async {
    await _initFuture!;
    return await WebviewWinFloatingPlatform.instance.canGoForward(_webviewId);
  }

  Future<void> goBack() async {
    await _initFuture!;
    await WebviewWinFloatingPlatform.instance.goBack(_webviewId);
  }

  Future<void> goForward() async {
    await _initFuture!;
    await WebviewWinFloatingPlatform.instance.goForward(_webviewId);
  }

  Future<void> reload() async {
    await _initFuture!;
    await WebviewWinFloatingPlatform.instance.reload(_webviewId);
  }

  Future<void> cancelNavigate() async {
    await _initFuture!;
    await WebviewWinFloatingPlatform.instance.cancelNavigate(_webviewId);
  }

  Future<void> clearCache() async {
    await _initFuture!;
    await WebviewWinFloatingPlatform.instance.clearCache(_webviewId);
  }

  Future<void> clearCookies() async {
    await _initFuture!;
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
    await _initFuture!;
    WebviewWinFloatingPlatform.instance.unregisterWebView(_webviewId);
    await WebviewWinFloatingPlatform.instance.dispose(_webviewId);
  }
}
