import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_win_floating/webview_win_floating.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final controller = WebViewController(onPermissionRequest: (request) {
    late final WinWebViewPermissionRequest req;
    if (Platform.isWindows) {
      if (request is WinWebViewPermissionRequest) {
        req = request as WinWebViewPermissionRequest;
      } else {
        req = request.platform as WinWebViewPermissionRequest;
      }
    } else {
      return;
    }

    print("permission: ${req.kind} , ${req.url}");
    req.grant();
  });
  final urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    controller.setBackgroundColor(Colors.cyanAccent);

    controller.setNavigationDelegate(NavigationDelegate(
      /*
      onNavigationRequest: (request) {
        if (request.url.startsWith("https://www.bnext.com.tw")) {
          return NavigationDecision.navigate;
        } else {
          print("prevent user navigate out of google website: ${request.url}");
          return NavigationDecision.prevent;
        }
      },
      */
      onPageStarted: (url) {
        urlController.text = url;
        print("onPageStarted: $url");
      },
      onPageFinished: (url) => print("onPageFinished: $url"),
      onWebResourceError: (error) =>
          print("onWebResourceError: ${error.description}"),
    ));

    controller.addJavaScriptChannel("Flutter", onMessageReceived: (message) {
      print("js -> dart : ${message.message}");
    });
    //controller.loadRequest(Uri.parse("https://www.google.com"));
    controller.loadRequest(Uri.parse(
        "https://www.bennish.net/web-notifications.html")); // javascript notification test
    //controller.loadRequest(Uri.parse("https://www.bnext.com.tw"));
    //controller.loadRequest(Uri.parse("https://www.w3schools.com/tags/tryit.asp?filename=tryhtml_a_target"));
  }

  void testJavascript() {
    controller.runJavaScript("Flutter.postMessage('Chinese 中文')");
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
      MyCircleButton(icon: Icons.refresh, onTap: controller.reload),
      Expanded(child: urlBox),
    ]);

    Widget body =
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      buttonRow,
      Expanded(child: WebViewWidget(controller: controller)),
    ]);

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
