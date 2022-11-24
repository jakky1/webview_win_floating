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
