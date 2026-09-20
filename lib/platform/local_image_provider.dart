import 'package:flutter/widgets.dart';

import 'local_image_provider_stub.dart'
    if (dart.library.io) 'local_image_provider_io.dart' as platform;

ImageProvider<Object> localImageProviderFromPath(String path) =>
    platform.localImageProviderFromPath(path);
