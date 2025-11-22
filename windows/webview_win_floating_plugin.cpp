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
std::shared_ptr<WCHAR[]> utf8ToUtf16(std::string str8) {
  int arrSize = (int) str8.length() + 1;
  std::shared_ptr<WCHAR[]> str16(new WCHAR[arrSize]);
  auto convResult = MultiByteToWideChar(CP_UTF8, 0, str8.c_str(), -1, str16.get(), arrSize);
  if (convResult < 0) {
    std::cout << "[webview_win_floating] native convert tring to utf16 (WCHAR*) failed: str = " << str8 << std::endl;
  }

  return str16;
}

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

void createWebview(const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> &result,
    int webviewId, std::string url, std::string userDataFolder) {

  std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>> shared_result = std::move(result);
  MyWebViewCreateParams params;

  params.onCreated = [shared_result, webviewId, url](HRESULT hr, MyWebView *webview) -> void {
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

  params.onNavigationRequest = [webviewId](int requestId, std::string url, bool isNewWindow) -> void {
    flutter::EncodableMap arguments;
    arguments[flutter::EncodableValue("webviewId")] = flutter::EncodableValue(webviewId);
    arguments[flutter::EncodableValue("requestId")] = flutter::EncodableValue(requestId);
    arguments[flutter::EncodableValue("url")] = flutter::EncodableValue(url);
    arguments[flutter::EncodableValue("isNewWindow")] = flutter::EncodableValue(isNewWindow);
    gMethodChannel->InvokeMethod("onNavigationRequest", std::make_unique<flutter::EncodableValue>(arguments));
  };
  
  params.onPageStarted = [webviewId, params](std::string url) -> void {
    flutter::EncodableMap arguments;
    arguments[flutter::EncodableValue("webviewId")] = flutter::EncodableValue(webviewId);
    arguments[flutter::EncodableValue("url")] = flutter::EncodableValue(url);
    gMethodChannel->InvokeMethod("onPageStarted", std::make_unique<flutter::EncodableValue>(arguments));
  };
  
  params.onPageFinished = [webviewId](std::string url) -> void {
    flutter::EncodableMap arguments;
    arguments[flutter::EncodableValue("webviewId")] = flutter::EncodableValue(webviewId);
    arguments[flutter::EncodableValue("url")] = flutter::EncodableValue(url);
    gMethodChannel->InvokeMethod("onPageFinished", std::make_unique<flutter::EncodableValue>(arguments));
  };
  
  params.onHttpError = [webviewId](std::string url, int errCode) -> void {
    flutter::EncodableMap arguments;
    arguments[flutter::EncodableValue("webviewId")] = flutter::EncodableValue(webviewId);
    arguments[flutter::EncodableValue("url")] = flutter::EncodableValue(url);
    arguments[flutter::EncodableValue("errCode")] = flutter::EncodableValue(errCode);
    gMethodChannel->InvokeMethod("onHttpError", std::make_unique<flutter::EncodableValue>(arguments));
  };
  
  params.onSslAuthError = [webviewId](std::string url) -> void {
    flutter::EncodableMap arguments;
    arguments[flutter::EncodableValue("webviewId")] = flutter::EncodableValue(webviewId);
    arguments[flutter::EncodableValue("url")] = flutter::EncodableValue(url);
    gMethodChannel->InvokeMethod("onSslAuthError", std::make_unique<flutter::EncodableValue>(arguments));
  };

  params.onWebResourceError = [webviewId](std::string url, int errCode, std::string errType) -> void {
    flutter::EncodableMap arguments;
    arguments[flutter::EncodableValue("webviewId")] = flutter::EncodableValue(webviewId);
    arguments[flutter::EncodableValue("url")] = flutter::EncodableValue(url);
    arguments[flutter::EncodableValue("errCode")] = flutter::EncodableValue(errCode);
    arguments[flutter::EncodableValue("errType")] = flutter::EncodableValue(errType);
    gMethodChannel->InvokeMethod("onWebResourceError", std::make_unique<flutter::EncodableValue>(arguments));
  };

  params.onUrlChange = [webviewId](std::string url) -> void {
    flutter::EncodableMap arguments;
    arguments[flutter::EncodableValue("webviewId")] = flutter::EncodableValue(webviewId);
    arguments[flutter::EncodableValue("url")] = flutter::EncodableValue(url);
    gMethodChannel->InvokeMethod("onUrlChange", std::make_unique<flutter::EncodableValue>(arguments));
  };

  params.onPageTitleChanged = [webviewId](std::string title) -> void {
    flutter::EncodableMap arguments;
    arguments[flutter::EncodableValue("webviewId")] = flutter::EncodableValue(webviewId);
    arguments[flutter::EncodableValue("title")] = flutter::EncodableValue(title);
    gMethodChannel->InvokeMethod("onPageTitleChanged", std::make_unique<flutter::EncodableValue>(arguments));
  };
  
  params.onWebMessageReceived = [=](std::string message) -> void {
    flutter::EncodableMap arguments;
    arguments[flutter::EncodableValue("webviewId")] = flutter::EncodableValue(webviewId);
    arguments[flutter::EncodableValue("message")] = flutter::EncodableValue(message);
    gMethodChannel->InvokeMethod("OnWebMessageReceived", std::make_unique<flutter::EncodableValue>(arguments));
  };
  
  params.onMoveFocusRequest = [=](bool isNext) -> void {
    flutter::EncodableMap arguments;
    arguments[flutter::EncodableValue("webviewId")] = flutter::EncodableValue(webviewId);
    arguments[flutter::EncodableValue("isNext")] = flutter::EncodableValue(isNext);
    gMethodChannel->InvokeMethod("onMoveFocusRequest", std::make_unique<flutter::EncodableValue>(arguments));
  };
  
  params.onFullScreenChanged = [=](BOOL isFullScreen) -> void {
    // TODO: Android webview does'n support fullscreen listener... should we support ONLY in windows ???
    flutter::EncodableMap arguments;
    arguments[flutter::EncodableValue("webviewId")] = flutter::EncodableValue(webviewId);
    arguments[flutter::EncodableValue("isFullScreen")] = flutter::EncodableValue(isFullScreen ? true : false);
    gMethodChannel->InvokeMethod("OnFullScreenChanged", std::make_unique<flutter::EncodableValue>(arguments));
  };
  
  params.onHistoryChanged = [=]() -> void {
    flutter::EncodableMap arguments;
    arguments[flutter::EncodableValue("webviewId")] = flutter::EncodableValue(webviewId);
    gMethodChannel->InvokeMethod("onHistoryChanged", std::make_unique<flutter::EncodableValue>(arguments));
  };
  
  params.onAskPermission = [=](std::string url, int kind, int deferralId) -> void {
    flutter::EncodableMap arguments;
    arguments[flutter::EncodableValue("webviewId")] = flutter::EncodableValue(webviewId);
    arguments[flutter::EncodableValue("url")] = flutter::EncodableValue(url);
    arguments[flutter::EncodableValue("kind")] = flutter::EncodableValue(kind);
    arguments[flutter::EncodableValue("deferralId")] = flutter::EncodableValue(deferralId);
    gMethodChannel->InvokeMethod("onAskPermission", std::make_unique<flutter::EncodableValue>(arguments));
  };

  PCWSTR pwUserDataFolder = NULL;
  WCHAR wUserDataFolder[1024];
  if (!userDataFolder.empty()) {
    auto convResult = MultiByteToWideChar(CP_UTF8, 0, userDataFolder.c_str(), -1, wUserDataFolder, sizeof(wUserDataFolder) / sizeof(WCHAR));
    if (convResult < 0) {
      std::cout << "[webview_win_floating] native convert userDataFolder to utf16 (WCHAR*) failed: path = " << userDataFolder << std::endl;
    } else {
      pwUserDataFolder = wUserDataFolder;
    }
  }

  MyWebView::Create(g_NativeHWND, params, pwUserDataFolder);
}

void WebviewWinFloatingPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

  //std::cout << "native HandleMethodCall(): " << method_call.method_name() << std::endl;

  if (method_call.method_name().compare("init") == 0) {
    // called when hot-restart in debug mode, and clear all the old webviews which created before hot-restart
    for(auto iter = webviewMap.begin(); iter != webviewMap.end(); iter++) {
      std::cout << "[webview_win_floating] old webview found, deleting" << std::endl;
      delete iter->second;
    }
    webviewMap.clear();
    result->Success();
    return;
  }

  flutter::EncodableMap arguments = std::get<flutter::EncodableMap>(*method_call.arguments());
  auto webviewId = std::get<int>(arguments[flutter::EncodableValue("webviewId")]);

  bool isCreateCall = method_call.method_name().compare("create") == 0;
  auto webview = webviewMap[webviewId];
  if (webview == NULL && !isCreateCall) {
    result->Error("webview hasn't created");
    return;
  }

  if (isCreateCall) {
    auto url = std::get<std::string>(arguments[flutter::EncodableValue("url")]);
    auto userDataFolder = std::get<std::string>(arguments[flutter::EncodableValue("userDataFolder")]);
    createWebview(method_call, result, webviewId, url, userDataFolder);
  } else if (method_call.method_name().compare("setHasNavigationDecision") == 0) {
    auto hasNavigationDecision = std::get<bool>(arguments[flutter::EncodableValue("hasNavigationDecision")]);
    webview->setHasNavigationDecision(hasNavigationDecision);
    result->Success();
  } else if (method_call.method_name().compare("allowNavigationRequest") == 0) {
    auto requestId = std::get<int>(arguments[flutter::EncodableValue("requestId")]);
    auto isAllowed = std::get<bool>(arguments[flutter::EncodableValue("isAllowed")]);
    webview->allowNavigationRequest(requestId, isAllowed);
    result->Success();
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

    if (!arguments[flutter::EncodableValue("baseUrl")].IsNull()) {
      static bool g_isPrompted_baseUrl = false;
      if (!g_isPrompted_baseUrl) {
        std::cout << "[win_webview_floating] loadHtmlString() ignore 'baseUrl' parameter in Windows. WebView2 doesn't support. ref: https://github.com/MicrosoftEdge/WebView2Feedback/issues/530" << std::endl;
        g_isPrompted_baseUrl = true;
      }
    }

  } else if (method_call.method_name().compare("runJavascript") == 0) {
    std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>> shared_result = std::move(result);
    auto javaScriptString = std::get<std::string>(arguments[flutter::EncodableValue("javaScriptString")]);
    auto ignoreResult = std::get<bool>(arguments[flutter::EncodableValue("ignoreResult")]);
    auto hr = webview->runJavascript(utf8ToUtf16(javaScriptString).get(), ignoreResult, [shared_result, ignoreResult](std::string result) -> void {
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
  } else if (method_call.method_name().compare("enableStatusBar") == 0) {
       auto isEnable = std::get<bool>(arguments[flutter::EncodableValue("isEnable")]);
       webview->enableStatusBar(isEnable);
       result->Success(flutter::EncodableValue(true));
  } else if (method_call.method_name().compare("enableIsZoomControl") == 0) {
         auto isEnable = std::get<bool>(arguments[flutter::EncodableValue("isEnable")]);
         webview->enableIsZoomControl(isEnable);
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
  } else if (method_call.method_name().compare("grantPermission") == 0) {
    auto deferralId = std::get<int>(arguments[flutter::EncodableValue("deferralId")]);
    auto isGranted = std::get<bool>(arguments[flutter::EncodableValue("isGranted")]);
    webview->grantPermission(deferralId, isGranted);
    result->Success();    
  } else if (method_call.method_name().compare("openDevTools") == 0) {
    webview->openDevTools();
    result->Success();
  } else {
    result->NotImplemented();
  }
}

}  // namespace webview_win_floating
