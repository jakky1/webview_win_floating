import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:webview_win_floating/webview.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  WindowsWebViewPlatform.registerWith();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final controller = WebViewController();
  final srollController = ScrollController();

  @override
  void initState() {
    super.initState();
    controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    controller.setBackgroundColor(Colors.cyanAccent);
    controller.setNavigationDelegate(NavigationDelegate(
      onNavigationRequest: (request) {
        if (request.url.startsWith("https://www.google.com")) {
          return NavigationDecision.navigate;
        } else {
          log("prevent user navigate out of google website!");
          return NavigationDecision.prevent;
        }
      },
      onPageStarted: (url) => print("onPageStarted: $url"),
      onPageFinished: (url) => print("onPageFinished: $url"),
      onWebResourceError: (error) =>
          print("onWebResourceError: ${error.description}"),
    ));
    controller.loadRequest(Uri.parse("https://www.google.com/"));
  }

  @override
  Widget build(BuildContext context) {
    Widget webview = WebViewWidget(controller: controller);

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
