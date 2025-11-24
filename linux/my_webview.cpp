#include "my_webview.h"

GtkWidget* MyWebView::getWidget() {
    return m_webview;
}

gboolean on_decide_policy(WebKitWebView *web_view,
                          WebKitPolicyDecision *decision,
                          WebKitPolicyDecisionType decisionType, 
                          gpointer user_data) {
    MyWebView *me = (MyWebView*) user_data;
    return me->on_decide_policy(decision, decisionType);
}

gboolean MyWebView::on_decide_policy(WebKitPolicyDecision *decision,
                          WebKitPolicyDecisionType decisionType) {

    if (!m_hasNavigationDecision) return FALSE; // apply default handler
    if (decisionType == WEBKIT_POLICY_DECISION_TYPE_RESPONSE) return FALSE; // apply default handler

    WebKitNavigationPolicyDecision *navigation_decision = WEBKIT_NAVIGATION_POLICY_DECISION (decision);

    // WebKitNavigationAction
    WebKitNavigationAction *navigation_action = webkit_navigation_policy_decision_get_navigation_action(navigation_decision);
    gboolean isUserInitiated = webkit_navigation_action_is_user_gesture(navigation_action);
    //gboolean isRedirected = webkit_navigation_action_is_redirect(navigation_action);

    if (!isUserInitiated) return FALSE; // apply default handler, without dart code confirm

    // WebKitNavigationType
    //WebKitNavigationType navigation_type = webkit_navigation_policy_decision_get_navigation_type(navigation_decision);

    // WebKitURIRequest
    WebKitURIRequest *navigation_request = webkit_navigation_action_get_request(navigation_action);
    auto uri = webkit_uri_request_get_uri(navigation_request);
    //const gchar *httpMethod = webkit_uri_request_get_http_method(navigation_request);
    //bool isPostMethod = strcmp(httpMethod, "POST");

    bool isNewWindow = (decisionType == WEBKIT_POLICY_DECISION_TYPE_NEW_WINDOW_ACTION);


    // allow dart code make decision asynchronously
    static int g_lastNagivationRequestId = 0;
    g_lastNagivationRequestId ++;

    m_createParams.onNavigationRequest(g_lastNagivationRequestId, uri, isNewWindow); // ask dart code to ignore or not
    
    m_navigationRequestMap[g_lastNagivationRequestId] = decision;
    g_object_ref(decision); 
    
    webkit_navigation_action_free(navigation_action); // TODO: ?
    webkit_navigation_action_free(navigation_action); // TODO: ?
    return TRUE;
}

void MyWebView::allowNavigationDecision(int requestId, bool isAllowed) {
    auto decision = m_navigationRequestMap[requestId];
    if (isAllowed) webkit_policy_decision_use(decision);
    else webkit_policy_decision_ignore(decision);
    g_object_unref(decision);     
}

void on_load_changed(WebKitWebView *web_view, WebKitLoadEvent load_event, gpointer user_data) {
    MyWebView *me = (MyWebView*) user_data;
    MyWebViewCreateParams *params = &me->m_createParams;

    const gchar *uri = webkit_web_view_get_uri(web_view);
    if (!uri || uri[0] == '\0') return;

    switch (load_event) {
        case WEBKIT_LOAD_COMMITTED:
            //g_print("on_load_changed: load_event = %d\n", load_event);
            params->onPageStarted(uri);

            // if error occurs in 'on_load_failed', it is triggered before `onPageStarted`
            // and no `onPageFinished` triggered
            if (me->m_load_failed_code >= 0) {
                if (me->m_load_failed_code == 2) { // ssl certification error
                    params->onSslAuthError(uri);
                } else {
                    params->onWebResourceError(uri, -1, "unknown");
                }
                params->onPageFinished(uri);
                me->m_load_failed_code = -1;
            }
            break;
        case WEBKIT_LOAD_FINISHED: {        
            auto resource = webkit_web_view_get_main_resource(web_view);
            auto response = webkit_web_resource_get_response(resource);
            auto httpCode = response != NULL ? webkit_uri_response_get_status_code(response) : 0;
            if (httpCode == 200) {
                params->onPageFinished(uri);    
            } else if (httpCode == 0) {
                // ignore this case
            } else {
                // if http connected and server response error http code
                params->onHttpError(uri, httpCode);
                params->onPageFinished(uri);    
            }
        }
            break;
        case WEBKIT_LOAD_STARTED:
        case WEBKIT_LOAD_REDIRECTED:
            //g_print("on_load_changed: load_event = %d, %s\n", load_event, uri);
            break;
    }
}

gboolean on_load_failed(WebKitWebView *web_view, WebKitLoadEvent load_event, gchar *url,
                        GError *error, gpointer user_data) {
    MyWebView *me = (MyWebView*) user_data;

    // TODO: how to get error code? error->code always 0 for non-ssl error...
    me->m_load_failed_code = error->code;

    // NOTE:
    //   return TRUE:  no error page shown, this failed url won't added into url history, no 'onPageStarted' triggered
    //   return FALSE: everything works well, but 'onPageStarted' will be traiggered later...
    return FALSE; // fallback to default handler
}

/*
gboolean on_load_failed_with_tls_error(
  WebKitWebView* web_view,
  gchar* url,
  GTlsCertificate* certificate,
  GTlsCertificateFlags errors,
  gpointer user_data
) {
    MyWebViewCreateParams *params = (MyWebViewCreateParams*) user_data;
    params->onSslAuthError(url);
    return FALSE; // fallback to default handler
}
*/

void on_url_changed(WebKitWebView *web_view, GParamSpec *pspec, gpointer user_data)
{
    const gchar *url = webkit_web_view_get_uri(web_view);
    MyWebViewCreateParams *params = (MyWebViewCreateParams*) user_data;
    params->onUrlChange(url);
}

void on_title_changed(WebKitWebView *web_view, GParamSpec *pspec, gpointer user_data) {
    MyWebViewCreateParams *params = (MyWebViewCreateParams*) user_data;
    const gchar *title = webkit_web_view_get_title(web_view);
    if (!title) return;
    params->onPageTitleChanged(title);
}

void on_enter_fullscreen(WebKitWebView *web_view, gpointer user_data) {
    MyWebViewCreateParams *params = (MyWebViewCreateParams*) user_data;
    params->onFullScreenChanged(true);
}

void on_leave_fullscreen(WebKitWebView *web_view, gpointer user_data) {
    MyWebViewCreateParams *params = (MyWebViewCreateParams*) user_data;
    params->onFullScreenChanged(false);
}

enum WinWebViewPermissionResourceType {
  unknown,
  microphone,
  camera,
  geoLocation,
  notification,
  otherSensors,
  clipboardRead, // webkit2gtk not support...
}; //mapping to 'WinWebViewPermissionResourceType' in dart code

int g_last_permission_request_id = 1;
std::map<int, WebKitPermissionRequest*> g_permissionMap;
gboolean on_permission_request(WebKitWebView* web_view, WebKitPermissionRequest* request, gpointer user_data) {
    const gchar *url = webkit_web_view_get_uri(web_view);
    if (!url) {
        webkit_permission_request_deny(request);
        return TRUE;
    }

    // all types of request : https://webkitgtk.org/reference/webkit2gtk/2.35.1/WebKitPermissionRequest.html
    // int kind: mapping to 'WinWebViewPermissionResourceType' in this package
    int kind = unknown;
    if (WEBKIT_IS_NOTIFICATION_PERMISSION_REQUEST(request)) {
        kind = notification;
    } else if (WEBKIT_IS_GEOLOCATION_PERMISSION_REQUEST(request)) {
        kind = geoLocation;
    } else if (WEBKIT_IS_USER_MEDIA_PERMISSION_REQUEST(request)) { // camera / microphone
        WebKitUserMediaPermissionRequest *media_request =
            WEBKIT_USER_MEDIA_PERMISSION_REQUEST(request);
        if (webkit_user_media_permission_is_for_video_device(media_request)) {
            kind = camera;
        } else if (webkit_user_media_permission_is_for_audio_device(media_request)) {
            kind = microphone;
        }
    } else if (WEBKIT_IS_DEVICE_INFO_PERMISSION_REQUEST(request)) {
        kind = otherSensors;
    }

    if (kind == unknown) {
        webkit_permission_request_deny(request);
        return TRUE;
    }

    int requestId = g_last_permission_request_id ++;


    MyWebViewCreateParams *params = (MyWebViewCreateParams*) user_data;
    params->onAskPermission(url, kind, requestId);
    g_permissionMap[requestId] = request;
    g_object_ref(request); // keep 'request' object before user make decision

    return TRUE;
}

GtkWidget* on_new_window(
  WebKitWebView* self,
  WebKitNavigationAction* navigation_action,
  gpointer user_data
) {
    // when try to open link in new window, we just open link in current webview
    WebKitURIRequest *request = webkit_navigation_action_get_request(navigation_action);
    const char *url = webkit_uri_request_get_uri(request);

    MyWebView *webview = (MyWebView*) user_data;
    webview->loadUrl((char*)url);
    return NULL;
}

MyWebView::MyWebView(GtkWidget* container, MyWebViewCreateParams params, const gchar *userDataFolder) {
    m_createParams = params;
    
    m_user_content_manager = webkit_user_content_manager_new();
    m_webview = webkit_web_view_new_with_user_content_manager(m_user_content_manager);

    // NOTE: there is no way to set userDataFolder(cacheDir) and 'user_content_manager' at the same time...
    if (userDataFolder) g_print("[webview_win_floating] 'userDataFolder' is not allowed in Linux\n");

    m_container = container; // GtkFixed   
    gtk_fixed_put(GTK_FIXED(m_container), m_webview, 50, 0); // left-top
    gtk_widget_show_all(m_container);

    // listen webview events
    g_signal_connect(m_webview, "decide-policy", G_CALLBACK(::on_decide_policy), this);
    g_signal_connect(m_webview, "load-changed", G_CALLBACK(on_load_changed), this);
    g_signal_connect(m_webview, "load-failed", G_CALLBACK(on_load_failed), this);
    //g_signal_connect(m_webview, "load-failed-with-tls-errors", G_CALLBACK(on_load_failed_with_tls_error), &m_createParams);
    //g_signal_connect(m_webview, "notify::estimated-load-progress", G_CALLBACK(on_progress), &m_createParams);
    g_signal_connect(m_webview, "notify::uri", G_CALLBACK(on_url_changed), &m_createParams);
    g_signal_connect(m_webview, "notify::title", G_CALLBACK(on_title_changed), &m_createParams);
    g_signal_connect(m_webview, "enter-fullscreen", G_CALLBACK(on_enter_fullscreen), &m_createParams);
    g_signal_connect(m_webview, "leave-fullscreen", G_CALLBACK(on_leave_fullscreen), &m_createParams);
    g_signal_connect(m_webview, "permission-request", G_CALLBACK(on_permission_request), &m_createParams);
    g_signal_connect(m_webview, "create", G_CALLBACK(on_new_window), this);
    // TODO: onMoveFocusRequest...
    // TODO: onHistoryChanged...
}

MyWebView::~MyWebView() {
    g_print("[webview_win_floating] ~MyWebView() deleted\n");
    gtk_widget_destroy(m_webview);
}

void MyWebView::updateBounds(RECT& bounds) {
    //g_print("=====> updateBounds: (%d, %d), %d x %d\n", bounds.left, bounds.top, bounds.right - bounds.left, bounds.bottom - bounds.top);
    int width = bounds.right - bounds.left;
    int height = bounds.bottom - bounds.top;
    gtk_fixed_move(GTK_FIXED(m_container), m_webview, bounds.left, bounds.top); // left-top
    gtk_widget_set_size_request(m_webview, width, height); // width-height
}

void MyWebView::enableJavascript(bool bEnable) {
    WebKitSettings* settings = webkit_web_view_get_settings(WEBKIT_WEB_VIEW(m_webview));
    if (!settings) return;
    webkit_settings_set_enable_javascript(settings, bEnable);
}

void MyWebView::setUserAgent(gchar* userAgent) {
    WebKitSettings* settings = webkit_web_view_get_settings(WEBKIT_WEB_VIEW(m_webview));
    if (!settings) return;
    webkit_settings_set_user_agent(settings, userAgent);
}

void MyWebView::setHasNavigationDecision(bool hasNavigationDecision) {
    m_hasNavigationDecision = hasNavigationDecision;
}

void MyWebView::loadUrl(gchar* url) {
    webkit_web_view_load_uri(WEBKIT_WEB_VIEW(m_webview), url);
}

void MyWebView::loadHtmlString(gchar* html, gchar* baseUrl) {
    webkit_web_view_load_html(WEBKIT_WEB_VIEW(m_webview), html, baseUrl);
}

void MyWebView::runJavascript(gchar* script) {
    webkit_web_view_evaluate_javascript(WEBKIT_WEB_VIEW(m_webview), script, -1, NULL, NULL, NULL, NULL, NULL);
}

#include <map>
std::map<long, std::function<void(bool, gchar*)>> g_jsCallbackMap;
long g_last_jsCallbackId = 0;
/// callback of webkit_web_view_evaluate_javascript()
static void web_view_javascript_finished(GObject *object, GAsyncResult *result, gpointer user_data) {
    long cbId = (long) user_data;
    auto callback = g_jsCallbackMap[cbId];
    g_jsCallbackMap.erase(cbId);

    GError *error = NULL;
    JSCValue* value = webkit_web_view_evaluate_javascript_finish(WEBKIT_WEB_VIEW(object), result, &error);

    if (!value) {
        g_warning("Error running javascript: %s", error->message);
        callback(false, const_cast<char *>(error->message));
        g_error_free(error);
        return;
    }

    JSCException *exception = jsc_context_get_exception(jsc_value_get_context(value));
    if (exception) {
        auto errMsg = jsc_exception_get_message (exception);
        callback(false, const_cast<char *>(errMsg));
        //free(errMsg);
        return;
    }

    if (jsc_value_is_null(value)
        || jsc_value_is_undefined(value)) {
        callback(true, NULL);
        return;
    }

    gchar* str_value = jsc_value_to_json(value, 0);
    if (str_value) {
        callback(true, str_value);
    } else {
        callback(false, (char*)"jsc_value_to_json() return NULL");
    }
    g_free(str_value);
}

void MyWebView::runJavascript(gchar* script, std::function<void(bool, gchar*)> resultCallback) {
    g_jsCallbackMap[++g_last_jsCallbackId] = resultCallback;
    webkit_web_view_evaluate_javascript(
        WEBKIT_WEB_VIEW(m_webview),
        script,
        -1,
        NULL,
        NULL,
        NULL,
        web_view_javascript_finished,
        (gpointer) g_last_jsCallbackId
    );
}

static void on_script_message_received(WebKitUserContentManager *manager,
                                       WebKitJavascriptResult *result,
                                       gpointer user_data) {

    _JsChannelInfo *info = (_JsChannelInfo*) user_data;
    JSCValue *value = webkit_javascript_result_get_js_value(result);
    
    gchar *str_value;
    if (jsc_value_is_null(value)
        || jsc_value_is_undefined(value)) {
        str_value = NULL;
    } else {
        str_value = jsc_value_to_json(value, 0);
    }

    gchar *channelName = info->channel_name + 25; // skip the prefix "script-message-received::"

    info->params->onWebMessageReceived(channelName, str_value);
    g_free(str_value);

    webkit_javascript_result_unref(result);
}

void MyWebView::addScriptChannelByName(gchar* channelName) {
    if (strlen(channelName) > 30) {
        g_print("[webview_win_floating] addScriptChannelByName(): channelName too long. length should be less than 30. name = %s\n", channelName);
        return;
    }

    gboolean b = webkit_user_content_manager_register_script_message_handler(
        m_user_content_manager, channelName
    );
    if (!b) return;

    const int signalNameMaxLen = 1024;
    char *signal_name = (char*) malloc(signalNameMaxLen);
    snprintf(signal_name, signalNameMaxLen, "script-message-received::%s", channelName);

    _JsChannelInfo *info = (_JsChannelInfo*) malloc(sizeof(_JsChannelInfo));
    gulong signal_id = g_signal_connect(m_user_content_manager, signal_name,
                     G_CALLBACK(on_script_message_received), info);

    info->signal_id = signal_id;
    info->channel_name = signal_name;
    info->params = &m_createParams;
    m_jsChannels[channelName] = info;


    // set shortcut variable for the channel
    //   ex. const Flutter = window.webkit.messageHandlers.Flutter;
    //   than user can call Flutter.postMessage() directly
    char script[1024];
    snprintf(script, sizeof(script), "const %s = window.webkit.messageHandlers.%s;", channelName, channelName);
    info->initScript = webkit_user_script_new(script, WEBKIT_USER_CONTENT_INJECT_TOP_FRAME,
                             WEBKIT_USER_SCRIPT_INJECT_AT_DOCUMENT_START,
                             NULL, NULL);
    webkit_user_content_manager_add_script(m_user_content_manager, info->initScript);
    webkit_user_script_unref(info->initScript);
}

void MyWebView::removeScriptChannelByName(gchar* channelName) {
    _JsChannelInfo *info = m_jsChannels[channelName];
    if (!info) return; // not exists
    m_jsChannels.erase(channelName);
    g_signal_handler_disconnect(m_user_content_manager, info->signal_id);

    webkit_user_content_manager_remove_script(m_user_content_manager, info->initScript);

    free(info->channel_name);
    free(info);
}

void MyWebView::setVisible(bool isVisible) {
    if (isVisible) {
        gtk_widget_show(m_webview);
    } else {
        gtk_widget_hide(m_webview);
    }
}

void MyWebView::setBackgroundColor(int32_t argb) {
    int a = (argb >> 24) | 0xFF;
    int r = (argb >> 16) | 0xFF;
    int g = (argb >> 8) | 0xFF;
    int b = argb | 0xFF;
    GdkRGBA color = { (float)r/255, (float)g/255, (float)b/255, (float)a/255};
    webkit_web_view_set_background_color(WEBKIT_WEB_VIEW(m_webview), &color);
}

void MyWebView::requestFocus(bool isNext) {
    gtk_widget_grab_focus(m_webview);
}

gboolean MyWebView::canGoBack() {
    return webkit_web_view_can_go_back(WEBKIT_WEB_VIEW(m_webview));
}

gboolean MyWebView::canGoForward() {
    return webkit_web_view_can_go_forward(WEBKIT_WEB_VIEW(m_webview));
}

void MyWebView::goBack() {
    webkit_web_view_go_back(WEBKIT_WEB_VIEW(m_webview));
}

void MyWebView::goForward() {
    webkit_web_view_go_forward(WEBKIT_WEB_VIEW(m_webview));
}

void MyWebView::reload() {
    webkit_web_view_reload(WEBKIT_WEB_VIEW(m_webview));
}

void MyWebView::cancelNavigate() {
    webkit_web_view_stop_loading(WEBKIT_WEB_VIEW(m_webview));
}

void MyWebView::clearCache() {
    auto *context = webkit_web_context_get_default();
    auto *manager = webkit_web_context_get_website_data_manager(context);
    webkit_website_data_manager_clear(manager, WEBKIT_WEBSITE_DATA_ALL, 0, NULL, NULL, NULL);
}

void MyWebView::clearCookies() {
    // no api to clear cookies only in webkt2gtk...
    // webkit_cookie_manager_delete_all_cookies() is deprecated
    clearCache();
}

void MyWebView::suspend() {
    setVisible(false);
}

void MyWebView::resume() {
    setVisible(true);
}

void MyWebView::grantPermission(int deferralId, bool isGranted) {
    WebKitPermissionRequest *request = g_permissionMap[deferralId];
    if (!request) return;

    if (isGranted) webkit_permission_request_allow(request);
    else webkit_permission_request_deny(request);

    g_object_unref(request);
    g_permissionMap.erase(deferralId);
}

void MyWebView::openDevTools() {
    WebKitSettings *settings = webkit_web_view_get_settings(WEBKIT_WEB_VIEW(m_webview));
    if (!settings) return;
    g_object_set(G_OBJECT(settings), "enable-developer-extras", TRUE, NULL);

    WebKitWebInspector* inspector = webkit_web_view_get_inspector(WEBKIT_WEB_VIEW(m_webview));
    if (!inspector) return;
    webkit_web_inspector_show(inspector);
}
