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
  WebViewController? controller;
  final srollController = ScrollController();
  bool isShown = true;

  @override
  void initState() {
    super.initState();
    createController();
  }

  void createController() {
    controller = WebViewController();
    controller!.setJavaScriptMode(JavaScriptMode.unrestricted);
    controller!.setBackgroundColor(Colors.cyanAccent);
    controller!.setNavigationDelegate(NavigationDelegate(
      onNavigationRequest: (request) {
        if (request.url.startsWith("https://www.youtube.com")) {
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
    controller!.loadRequest(Uri.parse("https://www.youtube.com/"));

    isShown = true;
  }

  void createOrDelete() {
    if (controller == null) {
      createController();
    } else {
      controller = null;
    }
    setState(() {});
  }

  void hideOrShow() {
    isShown = !isShown;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    Widget webview = (controller != null && isShown)
        ? WebViewWidget(controller: controller!)
        : const SizedBox.shrink();

    Widget buttons = Row(children: [
      ElevatedButton(
          onPressed: createOrDelete,
          child:
              controller != null ? const Text("Delete") : const Text("Create")),
      if (controller != null)
        ElevatedButton(
            onPressed: hideOrShow,
            child: isShown ? const Text("Hide") : const Text("Show")),
    ]);

    webview = SingleChildScrollView(
      child: Column(children: [
        buttons,
        Container(height: 200, color: Colors.blue[700]),
        Container(height: 500, color: Colors.red[700], child: webview),
        Container(height: 1300, color: Colors.green[700]),
      ]),
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
