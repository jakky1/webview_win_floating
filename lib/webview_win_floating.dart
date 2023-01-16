
import 'webview_win_floating_platform_interface.dart';

class WebviewWinFloating {
  Future<String?> getPlatformVersion() {
    return WebviewWinFloatingPlatform.instance.getPlatformVersion();
  }
}
