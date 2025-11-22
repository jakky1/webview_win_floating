import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_win_floating/webview_win_floating.dart';

//typedef WebViewController = WinWebViewController;
//typedef WebViewWidget = WinWebViewWidget;
//typedef NavigationDelegate = WinNavigationDelegate;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  Widget buildMultiple() {
    return const Row(
      textDirection: TextDirection.ltr,
      children: [
        Expanded(child: MyWebViewTab(url: "https://badssl.com")),
        //Expanded(child: MyWebViewTab(url: "https://www.youtube.com")),
        //Expanded(child: MyWebViewTab(url: "https://www.bennish.net/web-notifications.html")),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    //return const MyWebViewTab(url: "https://www.youtube.com");
    return buildMultiple();
  }
}

class MyWebViewTab extends StatefulWidget {
  final String? url;
  const MyWebViewTab({Key? key, this.url}) : super(key: key);

  @override
  State<MyWebViewTab> createState() => _MyWebViewTabState();
}

class _MyWebViewTabState extends State<MyWebViewTab> {
  void cancelNavigate() {
    if (controller is WinWebViewController) {
      (controller as WinWebViewController).cancelNavigate();
    }
  }

  void openDevTools() {
    if (controller is WinWebViewController) {
      (controller as WinWebViewController).openDevTools();
    }
  }

  final mIsLoadingWeb = ValueNotifier<bool>(false);
  final mTitle = ValueNotifier<String>("Untitled");
  final urlController = TextEditingController();

  final String? cacheDir = "d:\\cache_web\\";
  late final params =
      WindowsWebViewControllerCreationParams(userDataFolder: cacheDir);

  late final controller = WebViewController.fromPlatformCreationParams(params,
      onPermissionRequest: (request) {
    if (request.platform is WinWebViewPermissionRequest) {
      var req = request.platform as WinWebViewPermissionRequest;
      req.grant();
    } else {
      request.deny();
    }
  });

  @override
  void initState() {
    super.initState();
    controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    controller.setBackgroundColor(Colors.cyanAccent);

    controller.setNavigationDelegate(NavigationDelegate(
      /*
      onNavigationRequest: (request) {
        if (request.url.startsWith("https://www.google.com")) {
          print("[dart] allow url: ${request.url}");
          return NavigationDecision.navigate;
        } else {
          print("prevent user navigate out of google website: ${request.url}");
          return NavigationDecision.prevent;
        }
      },
      */
      onUrlChange: (change) {
        urlController.text = change.url ?? "";
      },
      onPageStarted: (url) {
        mIsLoadingWeb.value = true;
        print("onPageStarted: $url");
      },
      onPageFinished: (url) {
        mIsLoadingWeb.value = false;
        print("onPageFinished: $url");
      },
      onHttpError: (error) {
        int httpCode = error.response!.statusCode;
        String url = error.response!.uri.toString();
        print("onHttpError: code=$httpCode, url : $url");
      },
      onSslAuthError: (error) {
        if (error is WinSslAuthError) {
          print("onSslAuthError: ${(error as WinSslAuthError).url}");
        } else {
          print("onSslAuthError: unknown url}");
        }
        error.cancel();
      },
      onWebResourceError: (error) {
        mIsLoadingWeb.value = false;
        print("onWebResourceError: ${error.url} => ${error.description}");
      },
      /*
      onPageTitleChanged: (title) {
        // only works on Windows/Linux
        mTitle.value = title;
      },
      */
    ));

    controller.addJavaScriptChannel("Flutter", onMessageReceived: (message) {
      print("===> js channel postMessage : ${message.message}");
    });

    if (widget.url != null) {
      controller.loadRequest(Uri.parse(widget.url!));
    }

    //controller.loadRequest(Uri.parse("https://www.youtube.com"));
    //controller.loadRequest(Uri.parse("https://www.google.com"));
    //controller.loadRequest(Uri.parse("https://www.bennish.net/web-notifications.html")); // javascript notification test
    //controller.loadRequest(Uri.parse("https://www.bnext.com.tw"));
    //controller.loadRequest(Uri.parse("https://www.w3schools.com/tags/tryit.asp?filename=tryhtml_a_target"));
  }

  void runJavaScriptReturningResult(String script) async {
    try {
      var ret = await controller.runJavaScriptReturningResult(script);
      print(
          "[dart] javascript($script) => return type: ${ret.runtimeType}, value : $ret");
    } catch (e) {
      print("[dart] javascript($script) => error: $e");
    }
  }

  void testJavascript() async {
    /*
    if (true) {
      controller.loadHtmlString(youtube_iframe, baseUrl: "https://www.dd.com/");
      return;
    }
    */

    controller.runJavaScript("Flutter.postMessage('Chinese 中文')");

    runJavaScriptReturningResult("null");
    runJavaScriptReturningResult("undefined");
    runJavaScriptReturningResult(";");
    runJavaScriptReturningResult("99");
    runJavaScriptReturningResult("1.8");
    runJavaScriptReturningResult("true");
    runJavaScriptReturningResult("'msg'");
    runJavaScriptReturningResult("['cc', 1, true]");
    runJavaScriptReturningResult("var c = {'type':true, 'model':9}; c;");
    runJavaScriptReturningResult("#@%^&");
    controller.runJavaScript("window.alert('hello')");

    openDevTools();
  }

  final isShown = ValueNotifier<bool>(true);
  void showOrHide() async {
    isShown.value = !isShown.value;
  }

  @override
  Widget build(BuildContext context) {
    Widget urlBox = TextField(
      controller: urlController,
      onSubmitted: (url) {
        url = url.trim();
        if (!url.startsWith("http")) {
          url = "https://$url";
        }
        controller.loadRequest(Uri.parse(url));
      },
    );
    Widget buttonRow = Row(children: [
      MyCircleButton(icon: Icons.question_mark, onTap: showOrHide),
      MyCircleButton(icon: Icons.javascript, onTap: testJavascript),
      MyCircleButton(icon: Icons.arrow_back, onTap: controller.goBack),
      MyCircleButton(icon: Icons.arrow_forward, onTap: controller.goForward),
/*
      MyCircleButton(
          icon: Icons.arrow_back,
          onTap: () {
            controller.runJavaScript("history.back();");
          }),
      MyCircleButton(
          icon: Icons.arrow_forward,
          onTap: () {
            controller.runJavaScript("history.forward();");
          }),
*/
      ValueListenableBuilder<bool>(
          valueListenable: mIsLoadingWeb,
          builder: (context, isLoading, _) {
            if (!isLoading) {
              return MyCircleButton(
                  icon: Icons.refresh, onTap: controller.reload);
            } else {
              return MyCircleButton(icon: Icons.cancel, onTap: cancelNavigate);
            }
          }),
      Expanded(child: urlBox),
    ]);

    Widget web = ValueListenableBuilder<bool>(
        valueListenable: isShown,
        builder: (context, value, _) {
          if (value) {
            return WebViewWidget(controller: controller);
          } else {
            return const SizedBox.expand();
          }
        });

    Widget body =
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ValueListenableBuilder<String>(
          valueListenable: mTitle,
          builder: (context, title, _) {
            return Text(title);
          }),
      buttonRow,
      Expanded(child: web),
    ]);

    body = Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.redAccent, // Color of the border
          width: 2.0, // Thickness of the border
          style: BorderStyle.solid, // Style of the border (solid, dashed, etc.)
        ),
        borderRadius:
            BorderRadius.circular(30.0), // Optional: for rounded corners
        color: Colors.white, // Optional: background color of the container
      ),
      child: body,
    );

    return MaterialApp(home: Scaffold(body: body));
  }
}

class MyCircleButton extends StatelessWidget {
  final GestureTapCallback? onTap;
  final IconData icon;
  final double size;

  const MyCircleButton(
      {super.key, required this.onTap, required this.icon, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Material(
        color: Colors.blue, // Button color
        child: InkWell(
          splashColor: Colors.red, // Splash color
          onTap: onTap,
          child: SizedBox(width: size, height: size, child: Icon(icon)),
        ),
      ),
    );
  }
}

final String youtube_iframe = """

<!DOCTYPE html>
<html>
  <body>
    <!-- 1. The <iframe> (and video player) will replace this <div> tag. -->
    <div id="player"></div>

    <script>
      // 2. This code loads the IFrame Player API code asynchronously.
      var tag = document.createElement('script');

      tag.src = "https://www.youtube.com/iframe_api";
      var firstScriptTag = document.getElementsByTagName('script')[0];
      firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);

      // 3. This function creates an <iframe> (and YouTube player)
      //    after the API code downloads.
      var player;
      function onYouTubeIframeAPIReady() {
        player = new YT.Player('player', {
          height: '390',
          width: '640',
          videoId: 'ylYJSBUgaMA',
          playerVars: {
            'enablejsapi': 1,
            'iv_load_policy': 3,
            'autoplay': 1,
            'rel': 0,
            'controls': 1,
            'fs': 0,
            'disablekb': 0,
          },
          events: {
            'onReady': onPlayerReady,
            'onStateChange': onPlayerStateChange
          }
        });
      }

      // 4. The API will call this function when the video player is ready.
      function onPlayerReady(event) {
        event.target.playVideo();
      }

      // 5. The API calls this function when the player's state changes.
      //    The function indicates that when playing a video (state=1),
      //    the player should play for six seconds and then stop.
      var done = false;
      function onPlayerStateChange(event) {
      }
      function stopVideo() {
        player.stopVideo();
      }
    </script>
  </body>
</html>
""";
