## 2.3.0

* Feature: implement Permission request
* Feature: add controller.enableZoom(bool)

## 2.2.10

* Feature: add controller.setStatusBar(bool) to show/hide status bar (Windows only)

## 2.2.9

* Fix @30: click "_blank" url with no response after @28 code change.

## 2.2.8

* Fix @29: post non-ascii string from js to dart via javascriptChannel

## 2.2.7

* Fix: call twice javascript `history.back()` not work as expected. ([#28](https://github.com/jakky1/webview_win_floating/issues/28))

## 2.2.6

* Fix: runJavaScript() doesn't support non-ASCII characters.

## 2.2.5

* Fix: destroy all old webviews when hot-restart in debugging mode

## 2.2.4

* Fix: no need to call registerWith()

## 2.2.3

* Fix: cannot login into www.facebook.com since http POST method not working

## 2.2.2

* Fix: cannot change url when user clicking link if setNavigationDelegate() not called.

## 2.2.0
* support userDataFolder settings

## 2.0.0

* migrate to webview_flutter_platform_interface: ^2.0.0
* dispose controller when finalizer called
* call webview2's suspend / resume when WebViewWidget activate / deactivated
* Fix: cannot update position when parent scrolling after flutter 3.7.0
* Fix issue with canGoBack / canGoForward
* (Windows only) add WinWebViewController.openDevTools()
* (Windows only) add onHistoryChanged in WinNavigationDelegate

## 1.0.4

* if the webview is put in a scrollable, update layout when scrolling

## 1.0.3

* fix compile error

## 1.0.2

* change sdk version limitation

## 1.0.1

* Add some information in pubcspec.yaml

## 1.0.0

* Initial version
