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
  final controller = WebViewController();

  @override
  void initState() {
    super.initState();
    controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    controller.setBackgroundColor(Colors.cyanAccent);
    controller.setNavigationDelegate(NavigationDelegate(
      onNavigationRequest: (request) {
        if (request.url.startsWith("https://www.youtube.com")) {
          return NavigationDecision.navigate;
        } else {
          print("prevent user navigate out of google website!");
          return NavigationDecision.prevent;
        }
      },
      onPageStarted: (url) => print("onPageStarted: $url"),
      onPageFinished: (url) => print("onPageFinished: $url"),
      onWebResourceError: (error) =>
          print("onWebResourceError: ${error.description}"),
    ));
    controller.loadRequest(Uri.parse("https://www.youtube.com/"));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Windows Webview example app'),
        ),
        body: WebViewWidget(controller: controller),
      ),
    );
  }
}
