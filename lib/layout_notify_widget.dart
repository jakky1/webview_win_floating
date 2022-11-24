import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

typedef OnWidgetLayoutChange = void Function(Offset offset, Size size);

class WidgetLayoutRenderObject extends RenderProxyBox {

  final OnWidgetLayoutChange onLayoutChange;

  WidgetLayoutRenderObject(this.onLayoutChange);

  @override
  void performLayout() {
    super.performLayout();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      onLayoutChange(localToGlobal(Offset.zero), size);
    });
  }
}

class WidgetLayoutWrapper extends SingleChildRenderObjectWidget {

  final OnWidgetLayoutChange onLayoutChange;

  const WidgetLayoutWrapper({
    Key? key,
    required this.onLayoutChange,
    required Widget child,
  }) : super(key: key, child: child);

  @override
  RenderObject createRenderObject(BuildContext context) {
    return WidgetLayoutRenderObject(onLayoutChange);
  }
}
