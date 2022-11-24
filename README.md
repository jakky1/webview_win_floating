# webview_win_floating

![pub version][visits-count-image]

[visits-count-image]: https://img.shields.io/badge/dynamic/json?label=Visits%20Count&query=value&url=https://api.countapi.xyz/hit/jakky1_webview_win_floating/visits

WebView for Windows.
A Flutter plugin that implements the interface of [webview_flutter][1].

![](https://raw.githubusercontent.com/jakky1/webview_win_floating/master/screenshot.jpg)

## Platform Support

This package itself support only Windows.

But use it with [webview_flutter][1], you can write once then support Windows / Android / iOS at the same time.

Android / iOS webview is supported by [webview_flutter][1]

## Advantages & Limitations

This package place a native Windows WebView2 component on the window, NO texture involved !

That's why it called "floating". In Windows, all the Flutter widgets will be covered (invisible) by the webview.

However, since it is a native WebView2 component, without texture involved, the display speed is the same with native WebView2.

Advantages:
- fast display speed  (no texture)
- support fullscreen

Limitations:
- all the Flutter widgets will be covered (invisible) by the webview (only in Windows)
- focus switch between webview and flutter widgets is not support (only in Windows)


## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  webview_win_floating: ^1.0.0
  webview_flutter: ^3.0.4
```

Or

```yaml
dependencies:
  webview_win_floating:
    git:
      url: https://github.com/jakky1/webview_win_floating.git
      ref: master
  webview_flutter: ^3.0.4
```

# Usage

## register webview first

Before using webview, you should add the following code:
```
import 'package:webview_win_floating/webview.dart';

if (Platform.isWindows) WebView.platform = WindowsWebViewPlugin();
```

## Use webview now

NOTE: all the interface are supplied by [webview_flutter][1]

```
  late WebViewController controller;
  @override
  Widget build(BuildContext context) {

    Widget webview = WebView(
      backgroundColor: Colors.black,
      initialUrl: "https://www.google.com/",
      javascriptMode: JavascriptMode.unrestricted,
      onWebViewCreated: (controller) {
        this.controller = controller;
      },
      navigationDelegate: (navigation) {
        return navigation.url.contains("google") ? NavigationDecision.navigate : NavigationDecision.prevent;
      },
      onPageStarted: (url) => print("onPageStarted: $url"),
      onPageFinished: (url) => print("onPageFinished"),
      onWebResourceError: (error) => print("error: ${error.failingUrl}"),
    );

    return webview;
}
```

#### enable javascript
don't forgot to add this line if you want to enable javascript:
```
 javascriptMode: JavascriptMode.unrestricted,
```

#### restricted user navigation
For example, to disable the facebook / twitter links in youtube website:
```
navigationDelegate: (navigation) {
  return navigation.url.contains("youtube") ? NavigationDecision.navigate : NavigationDecision.prevent;
},
```

#### Communication with javascript

Hint: you can rename the name 'myChannelName' in the following code
```
Widget build(BuildContext context) {
    return WebView(
        ....
        javascriptChannels: <JavascriptChannel> { channels },
        onWebViewCreated: (controller) {
            controller.loadHtmlString(htmlContent);
            controller.runJavascript("callByDart(100)");
        }
    );
}

var channels = JavascriptChannel(name: "myChannelName", onMessageReceived: (jmsg) {
    String message = jmsg.message;
    print(message);  // print "This message is from javascript"
});

var htmlContent = '''
<html>
<body>
<script>
function callByDart(int value) {
    console.log("callByDart: " + value);
}
myChannelName.postMessage("This message is from javascript");
</script>
</body>
</html>
''';
```

## controller operations

- controller.loadUrl(url)
- controller.runJavascript( jsStr )
- controller.runJavascriptReturningResult( jsStr )  // return javascript function's return value
- controller.reload()
- controller.canGoBack()
- controller.goBack()
- controller.goForward()
- controller.canGoForward()
- controller.currentUrl()
- controller.clearCache()

# standalon mode

If your app only runs on Windows, and you want to remove library dependencies as many as possible, you can modify `pubspec.yaml` file:

```yaml
dependencies:
  webview_win_floating: ^1.0.0
  # webview_flutter: ^3.0.4  # mark this line, for Windows only app
```

and modify all the following class name in your code:
```
WebView -> WinWebView  // add "Win" prefix
WebViewController -> WinWebViewController  // add "Win" prefix
NavigationDecision  -> WinNavigationDecision  // add "Win" prefix
```

just only modify class names. All the properties / method are the same with [webview_flutter][1]



# Example

```
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_win_floating/webview.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  if (Platform.isWindows) WebView.platform = WindowsWebViewPlugin();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  @override
  void initState() {
    super.initState();
  }

  late WebViewController controller;
  @override
  Widget build(BuildContext context) {

    Widget webview = WebView(
      initialUrl: "https://www.youtube.com/",
      javascriptMode: JavascriptMode.unrestricted,
      onWebViewCreated: (controller) {
        this.controller = controller;
      },
    );

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Windows Webview example app'),
        ),
        body: webview,
      ),
    );
  }
}
```
[1]: https://pub.dev/packages/webview_flutter "webview_flutter"