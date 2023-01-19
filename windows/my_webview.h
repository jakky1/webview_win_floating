#pragma once

#include <string>
#include <functional>

#include <windows.h>

// NOTE (Jacky, 2022/11/03) :
//		include "WebView2.h" twice, or include in two .cpp files, may cause compile error (keyword "interface" not defined)...
//		so I move WebView2-related identifiers to my_webview.cpp to avoid include WebView2.h here...
//#include <WebView2.h>

class MyWebView
{
public:
	static MyWebView* Create(HWND hWnd,
		std::function<void(HRESULT, MyWebView*)> onCreated,
		std::function<void(std::string url, bool isNewWindow, bool isUserInitiated)> onPageStarted,
		std::function<void(std::string, int errCode)> onPageFinished,
		std::function<void(std::string)> onPageTitleChanged,
		std::function<void(std::string)> onWebMessageReceived,
		std::function<void(bool)> onMoveFocusRequest,
		std::function<void(bool)> onFullScreenChanged,
		std::function<void()> onHistoryChanged);
		
	//MyWebView();
	virtual ~MyWebView() {};

	virtual HRESULT loadUrl(LPCWSTR url) = 0;
	virtual HRESULT loadHtmlString(LPCWSTR html) = 0;
	virtual HRESULT runJavascript(LPCWSTR javaScriptString, bool ignoreResult = true, std::function<void(std::string)> callback = NULL) = 0;

	virtual HRESULT addScriptChannelByName(LPCWSTR channelName) = 0;
	virtual void removeScriptChannelByName(LPCWSTR channelName) = 0;

	virtual void enableJavascript(bool bEnable) = 0;
	virtual HRESULT setUserAgent(LPCWSTR userAgent) = 0;

	virtual HRESULT updateBounds(RECT& bounds) = 0;
	virtual HRESULT getBounds(RECT& bounds) = 0;
	virtual HRESULT setVisible(bool isVisible) = 0;
	virtual HRESULT setBackgroundColor(int32_t argb) = 0;
	virtual HRESULT requestFocus(bool isNext = true) = 0;

	virtual bool canGoBack() = 0;
	virtual bool canGoForward() = 0;
	virtual void goBack() = 0;
	virtual void goForward() = 0;
	virtual void reload() = 0;
	virtual void cancelNavigate() = 0;

	virtual HRESULT clearCache() = 0;
	virtual HRESULT clearCookies() = 0;

	virtual void openDevTools() = 0;
};