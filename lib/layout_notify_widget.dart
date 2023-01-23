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
  Offset childOriginOffset = Offset.zero;
  Size childSize = Size.zero;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // support update position when parent scrollable scrolling
    ScrollableState? scrollableState;
    try {
      scrollableState = Scrollable.of(context);
    } catch (_) {
      // do nothing
      // Scrollable.of() will throw exception in flutter 3.7
      //   if webview not in a scrollable widget
      // but in flutter 3.5 it won't throw exception
    }

    ScrollController? scrollController = scrollableState?.widget.controller;
    if (scrollableState != null && scrollController == null) {
      log("to correctly layout webview in scrollable, please add a ScrollController to the scrollable widget",
          name: "webview_win_floating");
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

  Offset getScrollbarOffset() {
    double dx = 0;
    double dy = 0;
    if (parentScrollController != null) {
      for (var pos in parentScrollController!.positions) {
        if (pos.axis == Axis.vertical) {
          dy += pos.pixels;
        } else {
          dx += pos.pixels;
        }
      }
    }

    return Offset(dx, dy);
  }

  void onParentScrollControllerUpdate() {
    Offset scrollOffset = getScrollbarOffset();

    Offset offset = childOriginOffset.translate(-scrollOffset.dx, -scrollOffset.dy);
    widget.onLayoutChange(offset, childSize);
    //print("onScroll: offset = $offset, scrollDy = $dy");
  }

  void onLayoutChange(Offset offset, Size size) {
    widget.onLayoutChange(offset, size);
    //print("onLayoutChange: offset = $offset");

    Offset scrollOffset = getScrollbarOffset();
    childOriginOffset = offset.translate(scrollOffset.dx, scrollOffset.dy);
    childSize = size;
  }

  @override
  Widget build(BuildContext context) {
    return WidgetLayoutWrapper(
        onLayoutChange: onLayoutChange, child: widget.child);
  }
}
