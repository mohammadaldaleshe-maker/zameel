import 'dart:io';
import 'package:flutter/material.dart';

Widget localImageFromPath(
  String path, {
  double? width,
  double? height,
  BoxFit? fit,
  ImageErrorWidgetBuilder? errorBuilder,
}) => Image.file(
      File(path),
      width: width,
      height: height,
      fit: fit,
      errorBuilder: errorBuilder,
    );
