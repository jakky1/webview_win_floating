#pragma once

#include <gtk/gtk.h>
#include <webkit2/webkit2.h>
//#include <webkit2/webkitwebsettings.h>

#include <functional>
#include <string>
#include <map>

typedef struct RECT {
    int left, top, right, bottom;
} RECT;

class MyWebViewCreateParams {
public:
    std::function<void(int requestId, const gchar *url, bool isNewWindow)> onNavigationRequest;
    std::function<void(const gchar *url)> onPageStarted;
    std::function<void(const gchar *url)> onPageFinished;
    std::function<void(const gchar *url, int errCode)> onHttpError;
    std::function<void(const gchar *url)> onSslAuthError;
	std::function<void(const gchar *url, int errCode, const gchar *errType)> onWebResourceError;	
    std::function<void(const gchar *url)> onUrlChange;
    std::function<void(const gchar *title)> onPageTitleChanged;
    std::function<void(gchar *channelName, gchar *msg)> onWebMessageReceived;
    //std::function<void(bool)> onMoveFocusRequest;
    std::function<void(bool)> onFullScreenChanged;
    //std::function<void()> onHistoryChanged;
    std::function<void(const gchar *url, int kind, int deferralId)> onAskPermission;
};

typedef struct _JsChannelInfo {
	gulong signal_id;
	char *channel_name;
	MyWebViewCreateParams *params;
	WebKitUserScript *initScript;
} _JsChannelInfo;

class MyWebView {
public:
	MyWebView(GtkWidget* container, MyWebViewCreateParams params, const gchar *userDataFolder);
    GtkWidget* getWidget(); // return m_scrolled_window

	//MyWebView();
	virtual ~MyWebView();

    
	void setHasNavigationDecision(bool hasNavigationDecision);
	void allowNavigationDecision(int requestId, bool isAllowed);

	void loadUrl(gchar* url);
	void loadHtmlString(gchar* html, gchar* baseUrl);
	
    void runJavascript(gchar* script);
    void runJavascript(gchar* script, std::function<void(bool, gchar*)> resultCallback);

	void addScriptChannelByName(gchar* channelName);
	void removeScriptChannelByName(gchar* channelName);

	void enableJavascript(bool bEnable);
	//void enableStatusBar(bool bEnable);
	//void enableIsZoomControl(bool bEnable);

	void setUserAgent(gchar* userAgent);

	void updateBounds(RECT& bounds);
	//HRESULT getBounds(RECT& bounds);
	void setVisible(bool isVisible);
	void setBackgroundColor(int32_t argb);
	void requestFocus(bool isNext = true);

	gboolean canGoBack();
	gboolean canGoForward();
	void goBack();
	void goForward();
	void reload();
	void cancelNavigate();

	void clearCache();
	void clearCookies();

	void suspend();
	void resume();

	void grantPermission(int deferralId, bool isGranted);

	void openDevTools();

	// callbacks only used internally
	gboolean on_decide_policy(WebKitPolicyDecision *decision, WebKitPolicyDecisionType decisionType);
    MyWebViewCreateParams m_createParams;
	gint m_load_failed_code = -1;

private:
    std::map<std::string, _JsChannelInfo*> m_jsChannels;
    std::map<int, WebKitPolicyDecision*> m_navigationRequestMap;
	bool m_hasNavigationDecision = false;

    GtkWidget* m_container; // GtkFixed
    GtkWidget* m_webview;
    WebKitUserContentManager* m_user_content_manager;
};