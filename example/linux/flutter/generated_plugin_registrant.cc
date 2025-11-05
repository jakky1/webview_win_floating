//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <webview_win_floating/webview_win_floating_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) webview_win_floating_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "WebviewWinFloatingPlugin");
  webview_win_floating_plugin_register_with_registrar(webview_win_floating_registrar);
}
