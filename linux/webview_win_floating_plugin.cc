#include "include/webview_win_floating/webview_win_floating_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

#include "webview_win_floating_plugin_private.h"

#define WEBVIEW_WIN_FLOATING_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), webview_win_floating_plugin_get_type(), \
                              WebviewWinFloatingPlugin))

#include "my_webview.h" //Jacky
struct _WebviewWinFloatingPlugin {
  GObject parent_instance;  
  
  // Jacky {
  FlPluginRegistrar *registrar;
  GHashTable *webviewMap;

  GtkWidget *webviewContainer;
  GtkWidget *flView;

  GtkEventController *event_controller;
  gulong motion_signal_id;
  // Jacky }
};

G_DEFINE_TYPE(WebviewWinFloatingPlugin, webview_win_floating_plugin, g_object_get_type())



// Jacky {

void setVoidResult(FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;
  g_autoptr(FlValue) result = fl_value_new_null();
  response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  fl_method_call_respond(method_call, response, NULL);
}

void setBoolResult(FlMethodCall* method_call, bool b) {
  g_autoptr(FlMethodResponse) response = nullptr;
  g_autoptr(FlValue) result = fl_value_new_bool(b);
  response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  fl_method_call_respond(method_call, response, NULL);
}

void setStringResult(FlMethodCall* method_call, gchar* msg) {
  g_autoptr(FlMethodResponse) response = nullptr;
  g_autoptr(FlValue) result = fl_value_new_string(msg);
  response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  fl_method_call_respond(method_call, response, NULL);
}

void setNullResult(FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;
  g_autoptr(FlValue) result = fl_value_new_null();
  response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  fl_method_call_respond(method_call, response, NULL);
}

void setErrorResult(FlMethodCall* method_call, const char *errMsg) {
  g_autoptr(FlMethodResponse) response = nullptr;
  response = FL_METHOD_RESPONSE(fl_method_error_response_new("error", errMsg, NULL));
  fl_method_call_respond(method_call, response, NULL);
}

void setNotImplementedResult(FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;
  response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());  
  fl_method_call_respond(method_call, response, NULL);
}

// --------

GtkWindow* get_window(WebviewWinFloatingPlugin* self) {
  FlView* view = fl_plugin_registrar_get_view(self->registrar);
  return GTK_WINDOW(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

gboolean on_flutter_view_motion(GtkEventController *controller, gdouble x, gdouble y, gpointer user_data) {
  // when mouse hover the flutter view, and flutter view is not flcused
  //g_print("===========> on_flutter_view_motion\n");
  WebviewWinFloatingPlugin* self = (WebviewWinFloatingPlugin*) user_data;
  gtk_widget_grab_focus(GTK_WIDGET(self->flView)); // focus flutter view
  return FALSE;
}

gboolean on_flview_focus_out(GtkWidget *widget, GdkEventFocus *event, gpointer user_data) {
  // when flutter view lose focus, listen 'motion' event for flutter view
  //g_print("===========> on_flview_focus_out\n");
  WebviewWinFloatingPlugin* self = (WebviewWinFloatingPlugin*) user_data;
  self->motion_signal_id = g_signal_connect(self->event_controller, "motion", G_CALLBACK(on_flutter_view_motion), self);
  return FALSE;
}

gboolean on_flview_focus_in(GtkWidget *widget, GdkEventFocus *event, gpointer user_data) {
  // when flutter view gain focus, stop listening 'motion' event for flutter view
  //g_print("===========> on_flview_focus_in\n");
  WebviewWinFloatingPlugin* self = (WebviewWinFloatingPlugin*) user_data;
  g_signal_handler_disconnect(self->event_controller, self->motion_signal_id);
  self->motion_signal_id = 0;
  return FALSE;
}

typedef struct {
    GtkFixed parent_instance;
    GtkWidget *main_widget;
} MyFixed;

typedef struct {
    GtkFixedClass parent_class;
} MyFixedClass;

G_DEFINE_TYPE(MyFixed, my_fixed, GTK_TYPE_FIXED)

static void my_fixed_size_allocate(GtkWidget *widget, GtkAllocation *allocation) {
  //g_print("===========> my_fixed_size_allocate: width = %d\n", allocation->width);

  // make the flutter view (FLView) fill the container
  gtk_widget_set_size_request(((MyFixed*)widget)->main_widget, allocation->width, allocation->height);
  gtk_fixed_move(GTK_FIXED(widget), ((MyFixed*)widget)->main_widget, 0, 0); // left-top

  // call the original size_allocate() in GtkFixedWidget
  GTK_WIDGET_CLASS(my_fixed_parent_class)->size_allocate(widget, allocation);
}

static void my_fixed_get_preferred_width(GtkWidget *widget, gint *minimum_width, gint *natural_width) {
  //g_print("===========> my_fixed_get_preferred_width\n");
  //GTK_WIDGET_CLASS(my_fixed_parent_class)->get_preferred_width(widget, minimum_width, natural_width);
  *minimum_width = 0;
  *natural_width = 0;
}
static void my_fixed_get_preferred_height(GtkWidget *widget, gint *minimum_height, gint *natural_height) {
  //g_print("===========> my_fixed_get_preferred_height\n");
  //GTK_WIDGET_CLASS(my_fixed_parent_class)->get_preferred_height(widget, minimum_height, natural_height);
  *minimum_height = 0;
  *natural_height = 0;
}

static void my_fixed_class_init(MyFixedClass *klass) {
    GtkWidgetClass *widget_class = GTK_WIDGET_CLASS(klass);
    widget_class->size_allocate = my_fixed_size_allocate;
    widget_class->get_preferred_width = my_fixed_get_preferred_width;
    widget_class->get_preferred_height = my_fixed_get_preferred_height;
}

static void my_fixed_init(MyFixed *self) {
}

void initWidgetContainer(WebviewWinFloatingPlugin* self) {
  if (self->webviewContainer) return;

  // for plugin first-time init, 
  //   - get FLView widget added by flutter
  //   - create a GtkFixed container and put into GtkWindow
  //   - put FLView into GtkFixed container
  //   - put all webview widget into GtkFixed container

  // get FLView (flutter view)
  GtkWindow *window = get_window(self);
  self->flView = gtk_bin_get_child(GTK_BIN(window));
  
  // NOTE: my_fixed_get_type() is a custom GtkFixedWidget. It support:
  //   - can assign a 'main_widget' and make it always fill parent size
  //   - make natural size as zero in get_preferred_width() and get_preferred_height()
  //     so it won't ask parent to enlarge size even if its child out of bounds

  // create webviewContainer
  self->webviewContainer = GTK_WIDGET(g_object_new(my_fixed_get_type(), NULL));
  ((MyFixed*)self->webviewContainer)->main_widget = self->flView;
  //self->webviewContainer = gtk_fixed_new();


  // remove FLView from GtkWindow
  g_object_ref(self->flView);
  gtk_container_remove(GTK_CONTAINER(window), self->flView);

  // put FLView into webviewContainer (FixedWidget)
  //gtk_container_add(GTK_CONTAINER(self->webviewContainer), self->flView); 
  gtk_fixed_put(GTK_FIXED(self->webviewContainer), self->flView, 0, 0);
  gtk_widget_set_size_request(self->flView, 800, 500); // width-height
  g_object_unref(self->flView);
  //gtk_fixed_move(GTK_FIXED(self->webviewContainer), self->flView, 0, 0); // left-top


              
  // listen FLView focus-change event
  g_signal_connect(self->flView, "focus-in-event", G_CALLBACK(on_flview_focus_in), self);            
  g_signal_connect(self->flView, "focus-out-event", G_CALLBACK(on_flview_focus_out), self);

  // TODO: use gtk_gesture_click_new() instead to monitor mouse click, after Flutter migrate to GTK-4
  self->event_controller = gtk_event_controller_motion_new(self->flView);
  gtk_event_controller_set_propagation_phase(self->event_controller, GTK_PHASE_CAPTURE);
  //g_signal_connect(self->event_controller, "motion", G_CALLBACK(on_flutter_view_motion), self);


  // put webviewContainer into window
  gtk_container_add(GTK_CONTAINER(window), self->webviewContainer);
  gtk_widget_show_all(GTK_WIDGET(window));

  gtk_widget_set_can_focus(self->flView, TRUE);
  gtk_widget_set_focus_on_click(self->flView, TRUE);
  gtk_widget_grab_focus(GTK_WIDGET(self->flView));
}

void cb_delete_webview(gpointer key, gpointer value, gpointer user_data) {
  g_print("[webview_win_floating] old webview found, deleting");
  delete (MyWebView*)value;
}

void onInit(WebviewWinFloatingPlugin* self) {
  initWidgetContainer(self);

  // clear all webview in map
  g_hash_table_foreach(self->webviewMap, cb_delete_webview, NULL);
  g_hash_table_destroy(self->webviewMap);
  self->webviewMap = g_hash_table_new(g_direct_hash, g_direct_equal);
}

void createWebview(FlMethodChannel *method_channel, WebviewWinFloatingPlugin* self, int webviewId, const gchar* url, const gchar* userDataFolder) {
  MyWebViewCreateParams params;

  params.onNavigationRequest = [=](int requestId, const gchar *url, bool isNewWindow) -> void {
    auto *args = fl_value_new_map();
    fl_value_set(args, fl_value_new_string("webviewId"), fl_value_new_int(webviewId));
    fl_value_set(args, fl_value_new_string("requestId"), fl_value_new_int(requestId));
    fl_value_set(args, fl_value_new_string("url"), fl_value_new_string(url));
    fl_value_set(args, fl_value_new_string("isNewWindow"), fl_value_new_bool(isNewWindow));
    fl_method_channel_invoke_method(FL_METHOD_CHANNEL(method_channel),
                  "onNavigationRequest", args, NULL, NULL, NULL);
  };

  params.onPageStarted = [=](const gchar *url) -> void {
    auto *args = fl_value_new_map();
    fl_value_set(args, fl_value_new_string("webviewId"), fl_value_new_int(webviewId));
    fl_value_set(args, fl_value_new_string("url"), fl_value_new_string(url));
    fl_method_channel_invoke_method(FL_METHOD_CHANNEL(method_channel),
                  "onPageStarted", args, NULL, NULL, NULL);
  };

  params.onPageFinished = [=](const gchar *url) -> void {
    auto *args = fl_value_new_map();
    fl_value_set(args, fl_value_new_string("webviewId"), fl_value_new_int(webviewId));
    fl_value_set(args, fl_value_new_string("url"), fl_value_new_string(url));
    fl_method_channel_invoke_method(FL_METHOD_CHANNEL(method_channel),
                  "onPageFinished", args, NULL, NULL, NULL);
  };

  params.onHttpError = [=](const gchar *url, int errCode) -> void {
    auto *args = fl_value_new_map();
    fl_value_set(args, fl_value_new_string("webviewId"), fl_value_new_int(webviewId));
    fl_value_set(args, fl_value_new_string("url"), fl_value_new_string(url));
    fl_value_set(args, fl_value_new_string("errCode"), fl_value_new_int(errCode));
    fl_method_channel_invoke_method(FL_METHOD_CHANNEL(method_channel),
                  "onHttpError", args, NULL, NULL, NULL);
  };

  params.onSslAuthError = [=](const gchar *url) -> void {
    auto *args = fl_value_new_map();
    fl_value_set(args, fl_value_new_string("webviewId"), fl_value_new_int(webviewId));
    fl_value_set(args, fl_value_new_string("url"), fl_value_new_string(url));
    fl_method_channel_invoke_method(FL_METHOD_CHANNEL(method_channel),
                  "onSslAuthError", args, NULL, NULL, NULL);
  };

  params.onUrlChange = [=](const gchar *url) -> void {
    auto *args = fl_value_new_map();
    fl_value_set(args, fl_value_new_string("webviewId"), fl_value_new_int(webviewId));
    fl_value_set(args, fl_value_new_string("url"), fl_value_new_string(url));
    fl_method_channel_invoke_method(FL_METHOD_CHANNEL(method_channel),
                  "onUrlChange", args, NULL, NULL, NULL);
  };

  params.onPageTitleChanged = [=](const gchar *title) -> void {
    auto *args = fl_value_new_map();
    fl_value_set(args, fl_value_new_string("webviewId"), fl_value_new_int(webviewId));
    fl_value_set(args, fl_value_new_string("title"), fl_value_new_string(title));
    fl_method_channel_invoke_method(FL_METHOD_CHANNEL(method_channel),
                  "onPageTitleChanged", args, NULL, NULL, NULL);
  };

  params.onFullScreenChanged = [=](bool isFullScreen) -> void {
    auto *args = fl_value_new_map();
    fl_value_set(args, fl_value_new_string("webviewId"), fl_value_new_int(webviewId));
    fl_value_set(args, fl_value_new_string("isFullScreen"), fl_value_new_bool(isFullScreen));
    fl_method_channel_invoke_method(FL_METHOD_CHANNEL(method_channel),
                  "OnFullScreenChanged", args, NULL, NULL, NULL);
  };

  params.onAskPermission = [=](const gchar *url, int kind, int deferralId) -> void {
    auto *args = fl_value_new_map();
    fl_value_set(args, fl_value_new_string("webviewId"), fl_value_new_int(webviewId));
    fl_value_set(args, fl_value_new_string("url"), fl_value_new_string(url));
    fl_value_set(args, fl_value_new_string("kind"), fl_value_new_int(kind));
    fl_value_set(args, fl_value_new_string("deferralId"), fl_value_new_int(deferralId));
    fl_method_channel_invoke_method(FL_METHOD_CHANNEL(method_channel),
                  "onAskPermission", args, NULL, NULL, NULL);
  };
  
  params.onWebMessageReceived = [=](gchar *channelName, gchar *message) -> void {
    auto *args = fl_value_new_map();
    fl_value_set(args, fl_value_new_string("webviewId"), fl_value_new_int(webviewId));
    fl_value_set(args, fl_value_new_string("JkChannelName"), fl_value_new_string(channelName));
    fl_value_set(args, fl_value_new_string("message"), fl_value_new_string(message));
    fl_method_channel_invoke_method(FL_METHOD_CHANNEL(method_channel),
                  "OnWebMessageReceived", args, NULL, NULL, NULL);
  };

  MyWebView *webview = new MyWebView(self->webviewContainer, params, userDataFolder);

  g_hash_table_insert(self->webviewMap, GINT_TO_POINTER(webviewId), webview);
  g_print("[webview] native create: id = %d\n", webviewId);

  if (url) webview->loadUrl((gchar*)url);
}

// Jacky }


// Called when a method call is received from Flutter.
static void webview_win_floating_plugin_handle_method_call(
    FlMethodChannel* channel,
    WebviewWinFloatingPlugin* self,
    FlMethodCall* method_call) {

  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);

  if (strcmp(method, "init") == 0) {
    // called when hot-restart in debug mode, and clear all the old webviews which created before hot-restart
    onInit(self);
    setVoidResult(method_call); // result->Success();
    return;
  }

  int webviewId = fl_value_get_int(fl_value_lookup_string(args, "webviewId"));
  //g_print("[webview] native method: %s , id = %d\n", method, webviewId);
  bool isCreateCall = strcmp(method, "create") == 0;
  auto webview = (MyWebView*) g_hash_table_lookup(self->webviewMap, GINT_TO_POINTER(webviewId));
  if (webview == NULL && !isCreateCall) {
    setErrorResult(method_call, "webview hasn't created");
    return;
  }

  if (isCreateCall) {
    const gchar* url = fl_value_get_string(fl_value_lookup_string(args, "url"));
    const gchar* userDataFolder = fl_value_get_string(fl_value_lookup_string(args, "userDataFolder"));    
    createWebview(channel, self, webviewId, url, userDataFolder);
    setBoolResult(method_call, true);  
  } else if (strcmp(method, "updateBounds") == 0) {
    RECT rect;
    rect.left = fl_value_get_int(fl_value_lookup_string(args, "left"));
    rect.top = fl_value_get_int(fl_value_lookup_string(args, "top"));
    rect.right = fl_value_get_int(fl_value_lookup_string(args, "right"));
    rect.bottom = fl_value_get_int(fl_value_lookup_string(args, "bottom"));
    webview->updateBounds(rect);
    setBoolResult(method_call, true);
  } else if (strcmp(method, "setHasNavigationDecision") == 0) {
    auto hasNavigationDecision = fl_value_get_bool(fl_value_lookup_string(args, "hasNavigationDecision"));
    webview->setHasNavigationDecision(hasNavigationDecision);
    setVoidResult(method_call);
  } else if (strcmp(method, "allowNavigationRequest") == 0) {
    auto requestId = fl_value_get_int(fl_value_lookup_string(args, "requestId"));
    auto isAllowed = fl_value_get_bool(fl_value_lookup_string(args, "isAllowed"));
    webview->allowNavigationDecision(requestId, isAllowed);
    setVoidResult(method_call);
  } else if (strcmp(method, "loadUrl") == 0) {
    auto url = (gchar*) fl_value_get_string(fl_value_lookup_string(args, "url"));
    webview->loadUrl(url);
    setBoolResult(method_call, true);
  } else if (strcmp(method, "loadHtmlString") == 0) {
    auto html = (gchar*) fl_value_get_string(fl_value_lookup_string(args, "html"));
    auto baseUrl = (gchar*) fl_value_get_string(fl_value_lookup_string(args, "baseUrl")); // TODO
    webview->loadHtmlString(html, baseUrl);
    setBoolResult(method_call, true);
  } else if (strcmp(method, "runJavascript") == 0) {
    auto script = (gchar*) fl_value_get_string(fl_value_lookup_string(args, "javaScriptString"));
    bool ignoreResult = fl_value_get_bool(fl_value_lookup_string(args, "ignoreResult"));
    if (ignoreResult) {
      webview->runJavascript(script);
      setVoidResult(method_call);
    } else {
      webview->runJavascript(script, [method_call](bool bSuccess, gchar* result) -> void {
        if (bSuccess) {
          if (result) {
            setStringResult(method_call, result);
          } else {
            setNullResult(method_call);
          }
        } else {
          setErrorResult(method_call, result);
        }
        g_object_unref(method_call);
      });
      g_object_ref(method_call);
    }   
  } else if (strcmp(method, "addScriptChannelByName") == 0) {
    auto channelName = (gchar*) fl_value_get_string(fl_value_lookup_string(args, "channelName"));
    webview->addScriptChannelByName(channelName);
    setVoidResult(method_call);
  } else if (strcmp(method, "removeScriptChannelByName") == 0) {
    auto channelName = (gchar*) fl_value_get_string(fl_value_lookup_string(args, "channelName"));
    webview->removeScriptChannelByName(channelName);
    setVoidResult(method_call);
  //} else if (strcmp(method, "setFullScreen") == 0) {
  } else if (strcmp(method, "setVisibility") == 0) {
    bool isVisible = fl_value_get_bool(fl_value_lookup_string(args, "isVisible"));
    webview->setVisible(isVisible);
    setBoolResult(method_call, true);
  } else if (strcmp(method, "enableJavascript") == 0) {
    bool isEnable = fl_value_get_bool(fl_value_lookup_string(args, "isEnable"));
    webview->enableJavascript(isEnable);
    setBoolResult(method_call, true);
  //} else if (strcmp(method, "enableStatusBar") == 0) {
  //} else if (strcmp(method, "enableIsZoomControl") == 0) {
  } else if (strcmp(method, "setUserAgent") == 0) {
    auto userAgent = (gchar*) fl_value_get_string(fl_value_lookup_string(args, "userAgent"));
    webview->setUserAgent(userAgent);
    setBoolResult(method_call, true);
  } else if (strcmp(method, "canGoBack") == 0) {
    auto b = webview->canGoBack();
    setBoolResult(method_call, b);
  } else if (strcmp(method, "canGoForward") == 0) {
    auto b = webview->canGoForward();
    setBoolResult(method_call, b);
  } else if (strcmp(method, "goBack") == 0) {
    webview->goBack();
    setVoidResult(method_call);
  } else if (strcmp(method, "goForward") == 0) {
    webview->goForward();
    setVoidResult(method_call);
  } else if (strcmp(method, "reload") == 0) {
    webview->reload();
    setVoidResult(method_call);
  } else if (strcmp(method, "cancelNavigate") == 0) {
    webview->cancelNavigate();
    setVoidResult(method_call);
  } else if (strcmp(method, "clearCache") == 0) {
    webview->clearCache();
    setVoidResult(method_call);
  } else if (strcmp(method, "clearCookies") == 0) {
    webview->clearCookies();
    setVoidResult(method_call);
  } else if (strcmp(method, "requestFocus") == 0) {
    webview->requestFocus(true);
    setVoidResult(method_call);
  } else if (strcmp(method, "setBackgroundColor") == 0) {
    int color = fl_value_get_int(fl_value_lookup_string(args, "color"));
    webview->setBackgroundColor(color);
    setVoidResult(method_call);
  } else if (strcmp(method, "suspend") == 0) {
    webview->suspend();
    setVoidResult(method_call);
  } else if (strcmp(method, "resume") == 0) {
    webview->resume();
    setVoidResult(method_call);
  } else if (strcmp(method, "dispose") == 0) {
    if (webview != NULL) {
      delete webview; //TODO:...
      g_hash_table_remove(self->webviewMap, GINT_TO_POINTER(webviewId));
      g_print("[webview] native dispose: id = %d\n", webviewId);
    }
    setBoolResult(method_call, true);
  } else if (strcmp(method, "grantPermission") == 0) {
    int deferralId = fl_value_get_int(fl_value_lookup_string(args, "deferralId"));
    bool isGranted = fl_value_get_bool(fl_value_lookup_string(args, "isGranted"));
    webview->grantPermission(deferralId, isGranted);
    setVoidResult(method_call);
  } else if (strcmp(method, "openDevTools") == 0) {
    webview->openDevTools();
    setVoidResult(method_call);
  } else {
    g_print("[webview_win_floating] native method not implemented: %s\n", method);
    setNotImplementedResult(method_call);
  }
}

static void webview_win_floating_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(webview_win_floating_plugin_parent_class)->dispose(object);
}

static void webview_win_floating_plugin_class_init(WebviewWinFloatingPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = webview_win_floating_plugin_dispose;
}

static void webview_win_floating_plugin_init(WebviewWinFloatingPlugin* self) {}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  WebviewWinFloatingPlugin* plugin = WEBVIEW_WIN_FLOATING_PLUGIN(user_data);
  webview_win_floating_plugin_handle_method_call(channel, plugin, method_call);
}

void webview_win_floating_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  WebviewWinFloatingPlugin* plugin = WEBVIEW_WIN_FLOATING_PLUGIN(
      g_object_new(webview_win_floating_plugin_get_type(), nullptr));

  // Jacky {
  plugin->registrar = FL_PLUGIN_REGISTRAR(g_object_ref(registrar));
  plugin->webviewMap = g_hash_table_new(g_direct_hash, g_direct_equal);
  // Jacky }

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "webview_win_floating",
                            FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);

  g_object_unref(plugin);
}
