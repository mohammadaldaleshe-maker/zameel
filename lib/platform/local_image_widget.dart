import 'package:flutter/material.dart';

import 'local_image_widget_stub.dart'
    if (dart.library.io) 'local_image_widget_io.dart' as platform;

Widget localImageFromPath(
  String path, {
  double? width,
  double? height,
  BoxFit? fit,
  ImageErrorWidgetBuilder? errorBuilder,
}) => platform.localImageFromPath(
      path,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: errorBuilder,
    );
