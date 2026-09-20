import 'package:flutter/material.dart';

Widget localImageFromPath(
  String path, {
  double? width,
  double? height,
  BoxFit? fit,
  ImageErrorWidgetBuilder? errorBuilder,
}) => Image.network(
      path,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: errorBuilder,
    );
