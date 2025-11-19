This document lists all the breaking changes in the `webview_win_floating` package.

# from 2.x to 3.0

## return value type of runJavaScriptReturningResult()

For consistency with the behavior of `webview_flutter` on `Android`, the return value types in the following cases will differ from those in version 2.x:

```dart
// The following cases originally returned data in string format in version 2.x
runJavaScriptReturningResult("99");  // now return int 99
runJavaScriptReturningResult("1.8"); // now return double 1.8
runJavaScriptReturningResult("true"); // now return boolean true
runJavaScriptReturningResult("null"); // now return String "null"
runJavaScriptReturningResult("undefined"); // now return String "null"
```

The following cases remain unchanged from the previous version:

```dart
runJavaScriptReturningResult("'msg'");  // return String "msg"
runJavaScriptReturningResult("['cc', 1, true]");  // return String "['cc', 1, true]"
runJavaScriptReturningResult("var c = {'type':true, 'model':9}; c;"); // return String "{'type':true, 'model':9}"
```


## NavigationDelegate.onWebResourceError

In the old version of `webview_flutter` package only supported `onWebResourceError`. However, the newer versions of `webview_flutter` introduced `onHttpError` and `onSslAuthError`. As a result, certain web errors that previously triggered `onWebResourceError`, such as `404 Not Found` and `expired SSL certificate` errors, will now call `onHttpError` and `onSslAuthError` instead.