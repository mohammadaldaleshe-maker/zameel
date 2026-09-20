import 'dart:io';
import 'package:flutter/widgets.dart';

ImageProvider<Object> localImageProviderFromPath(String path) =>
    FileImage(File(path));
