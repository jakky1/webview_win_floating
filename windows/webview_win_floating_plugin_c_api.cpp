#include "include/webview_win_floating/webview_win_floating_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "webview_win_floating_plugin.h"

void WebviewWinFloatingPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  webview_win_floating::WebviewWinFloatingPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
