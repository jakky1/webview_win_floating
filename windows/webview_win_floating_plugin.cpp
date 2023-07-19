#include "webview_win_floating_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

// For getPlatformVersion; remove unless needed for your plugin implementation.
#include <VersionHelpers.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>

// Jacky {
#include "my_webview.h"

HWND g_NativeHWND = 0;
flutter::MethodChannel<flutter::EncodableValue>* gMethodChannel = NULL;
std::map<int, MyWebView*> webviewMap;

#define toWideString(str) std::wstring(str.begin(), str.end()).c_str()

// Jacky }

namespace webview_win_floating {

// static
flutter::PluginRegistrarWindows *g_registrar; // Jacky
void WebviewWinFloatingPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "webview_win_floating",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<WebviewWinFloatingPlugin>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));

  g_registrar = registrar; //Jacky
  g_NativeHWND = GetAncestor(registrar->GetView()->GetNativeWindow(), GA_ROOT); //Jacky
  gMethodChannel = new flutter::MethodChannel<flutter::EncodableValue>(registrar->messenger(), "webview_win_floating",
          &flutter::StandardMethodCodec::GetInstance()); //Jacky
}

WebviewWinFloatingPlugin::WebviewWinFloatingPlugin() {}

WebviewWinFloatingPlugin::~WebviewWinFloatingPlugin() {}

void WebviewWinFloatingPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

  flutter::EncodableMap arguments = std::get<flutter::EncodableMap>(*method_call.arguments());
  auto webviewId = std::get<int>(arguments[flutter::EncodableValue("webviewId")]);

  //std::cout << "native HandleMethodCall(): " << method_call.method_name() << std::endl;

  bool isCreateCall = method_call.method_name().compare("create") == 0;
  auto webview = webviewMap[webviewId];
  if (webview == NULL && !isCreateCall) {
    result->Error("webview hasn't created");
    return;
  }

  if (isCreateCall) {
    auto url = std::get<std::string>(arguments[flutter::EncodableValue("url")]);
    std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>> shared_result = std::move(result);
    auto onCreate = [shared_result, webviewId, url](HRESULT hr, MyWebView *webview) -> void {
      if (webview != NULL) {
        webviewMap[webviewId] = webview;
        std::cout << "[webview] native create: id = " << webviewId << std::endl;
        if (!url.empty()) webview->loadUrl(toWideString(url));
        shared_result->Success(flutter::EncodableValue(true));
      } else {
        std::cerr << "[webview] native create failed. result = " << hr << std::endl;
        shared_result->Error("[webview] native create failed.");
      }
    };
    auto onPageStarted = [webviewId](std::string url, bool isNewWindow, bool isUserInitiated) -> void {
      flutter::EncodableMap arguments;
      arguments[flutter::EncodableValue("webviewId")] = flutter::EncodableValue(webviewId);
      arguments[flutter::EncodableValue("url")] = flutter::EncodableValue(url);
      arguments[flutter::EncodableValue("isNewWindow")] = flutter::EncodableValue(isNewWindow);
      arguments[flutter::EncodableValue("isUserInitiated")] = flutter::EncodableValue(isUserInitiated);
      gMethodChannel->InvokeMethod("onPageStarted", std::make_unique<flutter::EncodableValue>(arguments));
    };
    auto onPageFinished = [webviewId](std::string url, int errCode) -> void {
      flutter::EncodableMap arguments;
      arguments[flutter::EncodableValue("webviewId")] = flutter::EncodableValue(webviewId);
      arguments[flutter::EncodableValue("url")] = flutter::EncodableValue(url);
      arguments[flutter::EncodableValue("errCode")] = flutter::EncodableValue(errCode);
      gMethodChannel->InvokeMethod("onPageFinished", std::make_unique<flutter::EncodableValue>(arguments));
    };
    auto onPageTitleChanged = [webviewId](std::string title) -> void {
      flutter::EncodableMap arguments;
      arguments[flutter::EncodableValue("webviewId")] = flutter::EncodableValue(webviewId);
      arguments[flutter::EncodableValue("title")] = flutter::EncodableValue(title);
      gMethodChannel->InvokeMethod("onPageTitleChanged", std::make_unique<flutter::EncodableValue>(arguments));
    };
    auto onWebMessageReceived = [=](std::string message) -> void {
      flutter::EncodableMap arguments;
      arguments[flutter::EncodableValue("webviewId")] = flutter::EncodableValue(webviewId);
      arguments[flutter::EncodableValue("message")] = flutter::EncodableValue(message);
      gMethodChannel->InvokeMethod("OnWebMessageReceived", std::make_unique<flutter::EncodableValue>(arguments));
    };
    auto onMoveFocusRequest = [=](bool isNext) -> void {
      flutter::EncodableMap arguments;
      arguments[flutter::EncodableValue("webviewId")] = flutter::EncodableValue(webviewId);
      arguments[flutter::EncodableValue("isNext")] = flutter::EncodableValue(isNext);
      gMethodChannel->InvokeMethod("onMoveFocusRequest", std::make_unique<flutter::EncodableValue>(arguments));
    };
    auto onFullScreenChanged = [=](BOOL isFullScreen) -> void {
      // TODO: Android webview does'n support fullscreen listener... should we support ONLY in windows ???
      flutter::EncodableMap arguments;
      arguments[flutter::EncodableValue("webviewId")] = flutter::EncodableValue(webviewId);
      arguments[flutter::EncodableValue("isFullScreen")] = flutter::EncodableValue(isFullScreen ? true : false);
      gMethodChannel->InvokeMethod("OnFullScreenChanged", std::make_unique<flutter::EncodableValue>(arguments));
    };
    auto onHistoryChanged = [=]() -> void {
      flutter::EncodableMap arguments;
      arguments[flutter::EncodableValue("webviewId")] = flutter::EncodableValue(webviewId);
      gMethodChannel->InvokeMethod("onHistoryChanged", std::make_unique<flutter::EncodableValue>(arguments));
    };

    PCWSTR pwUserDataFolder = NULL;
    WCHAR wUserDataFolder[1024];
    auto userDataFolder = std::get<std::string>(arguments[flutter::EncodableValue("userDataFolder")]);
    if (!userDataFolder.empty()) {
      auto convResult = MultiByteToWideChar(CP_UTF8, 0, userDataFolder.c_str(), -1, wUserDataFolder, sizeof(wUserDataFolder) / sizeof(WCHAR));
      if (convResult < 0) {
        std::cout << "[webview_win_floating] native convert userDataFolder to utf16 (WCHAR*) failed: path = " << userDataFolder << std::endl;
      } else {
        pwUserDataFolder = wUserDataFolder;
      }
    }

    MyWebView::Create(g_NativeHWND, onCreate, onPageStarted, onPageFinished, onPageTitleChanged, onWebMessageReceived, onMoveFocusRequest, onFullScreenChanged, onHistoryChanged, pwUserDataFolder);

  } else if (method_call.method_name().compare("updateBounds") == 0) {
    RECT bounds;
    bounds.left = std::get<int>(arguments[flutter::EncodableValue("left")]);
    bounds.top = std::get<int>(arguments[flutter::EncodableValue("top")]);
    bounds.right = std::get<int>(arguments[flutter::EncodableValue("right")]);
    bounds.bottom = std::get<int>(arguments[flutter::EncodableValue("bottom")]);
    webview->updateBounds(bounds);
    result->Success(flutter::EncodableValue(true));
  } else if (method_call.method_name().compare("loadUrl") == 0) {
    auto url = std::get<std::string>(arguments[flutter::EncodableValue("url")]);
    auto hr = webview->loadUrl(toWideString(url));
    result->Success(flutter::EncodableValue(SUCCEEDED(hr)));
  } else if (method_call.method_name().compare("loadHtmlString") == 0) {
    auto html = std::get<std::string>(arguments[flutter::EncodableValue("html")]);
    auto hr = webview->loadHtmlString(toWideString(html));
    result->Success(flutter::EncodableValue(SUCCEEDED(hr)));
  } else if (method_call.method_name().compare("runJavascript") == 0) {
    std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>> shared_result = std::move(result);
    auto javaScriptString = std::get<std::string>(arguments[flutter::EncodableValue("javaScriptString")]);
    auto ignoreResult = std::get<bool>(arguments[flutter::EncodableValue("ignoreResult")]);
    auto hr = webview->runJavascript(toWideString(javaScriptString), ignoreResult, [shared_result, ignoreResult](std::string result) -> void {
      if (ignoreResult) {
        shared_result->Success();
      } else {
        shared_result->Success(flutter::EncodableValue(result));
      }
    });
    if (FAILED(hr)) result->Error("runJavascript() error");
  } else if (method_call.method_name().compare("addScriptChannelByName") == 0) {
    auto channelName = std::get<std::string>(arguments[flutter::EncodableValue("channelName")]);
    webview->addScriptChannelByName(toWideString(channelName));
    result->Success();
  } else if (method_call.method_name().compare("removeScriptChannelByName") == 0) {
    auto channelName = std::get<std::string>(arguments[flutter::EncodableValue("channelName")]);
    webview->removeScriptChannelByName(toWideString(channelName));
    result->Success();
  } else if (method_call.method_name().compare("setFullScreen") == 0) {
    auto isFullScreen = std::get<bool>(arguments[flutter::EncodableValue("isFullScreen")]);
    if (isFullScreen) {
      RECT bounds;
      GetWindowRect(GetDesktopWindow(), &bounds);
      webview->updateBounds(bounds);
    }
    result->Success(flutter::EncodableValue(true));
  } else if (method_call.method_name().compare("setVisibility") == 0) {
    auto isVisible = std::get<bool>(arguments[flutter::EncodableValue("isVisible")]);
    webview->setVisible(isVisible);
    result->Success(flutter::EncodableValue(true));
  } else if (method_call.method_name().compare("enableJavascript") == 0) {
    auto isEnable = std::get<bool>(arguments[flutter::EncodableValue("isEnable")]);
    webview->enableJavascript(isEnable);
    result->Success(flutter::EncodableValue(true));
  } else if (method_call.method_name().compare("setUserAgent") == 0) {
    auto userAgent = std::get<std::string>(arguments[flutter::EncodableValue("userAgent")]);
    HRESULT hr = webview->setUserAgent(toWideString(userAgent));
    result->Success(flutter::EncodableValue(SUCCEEDED(hr) ? true : false));
  } else if (method_call.method_name().compare("canGoBack") == 0) {
    bool allow = webview->canGoBack();
    result->Success(flutter::EncodableValue(allow));
  } else if (method_call.method_name().compare("canGoForward") == 0) {
    bool allow = webview->canGoForward();
    result->Success(flutter::EncodableValue(allow));
  } else if (method_call.method_name().compare("goBack") == 0) {
    webview->goBack();
    result->Success();
  } else if (method_call.method_name().compare("goForward") == 0) {
    webview->goForward();
    result->Success();
  } else if (method_call.method_name().compare("reload") == 0) {
    webview->reload();
    result->Success();
  } else if (method_call.method_name().compare("cancelNavigate") == 0) {
    webview->cancelNavigate();
    result->Success();

  } else if (method_call.method_name().compare("clearCache") == 0) {
    webview->clearCache();
    result->Success();
  } else if (method_call.method_name().compare("clearCookies") == 0) {
    HRESULT hr = webview->clearCookies();
    result->Success(flutter::EncodableValue(SUCCEEDED(hr)));

  } else if (method_call.method_name().compare("requestFocus") == 0) {
    webview->requestFocus(true);
    result->Success();

  } else if (method_call.method_name().compare("setBackgroundColor") == 0) {
    auto color = std::get<int64_t>(arguments[flutter::EncodableValue("color")]);
    webview->setBackgroundColor((int32_t)color);
    result->Success();

  } else if (method_call.method_name().compare("suspend") == 0) {
    webview->setVisible(false);
    webview->suspend();
    result->Success();
  } else if (method_call.method_name().compare("resume") == 0) {
    webview->resume();
    webview->setVisible(true);
    result->Success();

  } else if (method_call.method_name().compare("dispose") == 0) {
    if (webview != NULL) {
      delete webview; //TODO:...
      webviewMap.erase(webviewId);
      std::cout << "[webview] native dispose: id = " << webviewId << std::endl;
    }
    result->Success(flutter::EncodableValue(true));
  } else if (method_call.method_name().compare("openDevTools") == 0) {
    webview->openDevTools();
    result->Success();
  } else {
    result->NotImplemented();
  }
}

}  // namespace webview_win_floating
