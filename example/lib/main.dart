import 'package:flutter/material.dart';
import 'package:webview_win_floating/webview.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State createState() => _MyAppState();
}

class _MyAppState extends State {
  final controller = WinWebViewController();

  @override
  void initState() {
    super.initState();
    //controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    /*
    controller.setNavigationDelegate(NavigationDelegate(
      onNavigationRequest: (request) {
        //return NavigationDecision.navigate;
        return NavigationDecision.prevent;
      },
    ));
    */
    controller.loadRequest(Uri.parse("https://www.facebook.com/"));
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: WinWebViewWidget(controller: controller),
      ),
    );
  }
}
