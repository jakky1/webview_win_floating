#ifndef FLUTTER_PLUGIN_WEBVIEW_WIN_FLOATING_PLUGIN_H_
#define FLUTTER_PLUGIN_WEBVIEW_WIN_FLOATING_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

// Jacky {
#include <windows.h>
#include <map>
#include "my_webview.h"
// Jacky }

namespace webview_win_floating {

class WebviewWinFloatingPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  WebviewWinFloatingPlugin();

  virtual ~WebviewWinFloatingPlugin();

  // Disallow copy and assign.
  WebviewWinFloatingPlugin(const WebviewWinFloatingPlugin&) = delete;
  WebviewWinFloatingPlugin& operator=(const WebviewWinFloatingPlugin&) = delete;

 private:
  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);


  // Jacky {
  HWND m_nativeHWND;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> m_MethodChannel;
  std::map<int, MyWebView*> m_webviewMap;

  void WebviewWinFloatingPlugin::createWebview(const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> &result,
    int webviewId, std::string url, std::string userDataFolder);
  void destroyAllWebViews();
  // Jacky }
};

}  // namespace webview_win_floating

#endif  // FLUTTER_PLUGIN_WEBVIEW_WIN_FLOATING_PLUGIN_H_
