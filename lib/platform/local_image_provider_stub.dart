import 'package:flutter/widgets.dart';

ImageProvider<Object> localImageProviderFromPath(String path) =>
    NetworkImage(path);
