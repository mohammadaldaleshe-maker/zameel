import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Reports the image's laid-out size after the frame, never during layout.
class MeasureContent161 extends SingleChildRenderObjectWidget {
  const MeasureContent161(
      {super.key, required this.onSize, required super.child});
  final ValueChanged<Size> onSize;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      MeasureContentRender161(onSize);
  @override
  void updateRenderObject(
          BuildContext context, covariant MeasureContentRender161 renderObject) =>
      renderObject.onSize = onSize;
}

class MeasureContentRender161 extends RenderProxyBox {
  MeasureContentRender161(this.onSize);
  ValueChanged<Size> onSize;
  Size? _last;
  @override
  void performLayout() {
    super.performLayout();
    final measured = size;
    if (_last == measured) return;
    _last = measured;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attached && _last == measured) onSize(measured);
    });
  }
}
