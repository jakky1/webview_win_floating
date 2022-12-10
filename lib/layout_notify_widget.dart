import 'dart:developer';

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

class WidgetLayoutWrapperWithScroll extends StatefulWidget {
  final OnWidgetLayoutChange onLayoutChange;
  final Widget child;

  const WidgetLayoutWrapperWithScroll({
    Key? key,
    required this.onLayoutChange,
    required this.child,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _WidgetLayoutWrapperWithScrollState();
}

class _WidgetLayoutWrapperWithScrollState
    extends State<WidgetLayoutWrapperWithScroll> {
  // detect the updated scroll position of the parent scrollable widget
  ScrollController? parentScrollController;
  Offset childOffset = Offset.zero;
  Size childSize = Size.zero;
  double scrollDx = 0;
  double scrollDy = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // support update position when parent scrollable scrolling
    var scrollableState = Scrollable.of(context);
    ScrollController? scrollController = scrollableState?.widget.controller;
    if (scrollableState != null && scrollController == null) {
      log("to correctly layout webview in scrollable, please add a ScrollController to the scrollable widget", name: "webview_win_floating");
    }

    if (parentScrollController != scrollController) {
      if (parentScrollController != null) {
        parentScrollController!.removeListener(onParentScrollControllerUpdate);
      }
      parentScrollController = scrollController;
      if (parentScrollController != null) {
        parentScrollController!.addListener(onParentScrollControllerUpdate);
      }
    }
    //
  }

  @override
  void dispose() {
    super.dispose();
    parentScrollController?.removeListener(onParentScrollControllerUpdate);
  }

  void onParentScrollControllerUpdate() {
    scrollDx = 0;
    scrollDy = 0;
    if (parentScrollController != null) {
      for (var pos in parentScrollController!.positions) {
        if (pos.axis == Axis.vertical) {
          scrollDy += pos.pixels;
        } else {
          scrollDx += pos.pixels;
        }
      }
    }

    Offset offset = childOffset.translate(scrollDx, -scrollDy);
    widget.onLayoutChange(offset, childSize);
  }

  void onLayoutChange(Offset offset, Size size) {
    childOffset = offset;
    childSize = size;

    offset = childOffset.translate(scrollDx, -scrollDy);
    widget.onLayoutChange(offset, size);
  }

  @override
  Widget build(BuildContext context) {
    return WidgetLayoutWrapper(
        onLayoutChange: onLayoutChange, child: widget.child);
  }
}
