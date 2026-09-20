import 'package:video_player/video_player.dart';

import 'video_controller_factory_stub.dart'
    if (dart.library.io) 'video_controller_factory_io.dart' as platform;

VideoPlayerController videoControllerFromLocalPath(String path) =>
    platform.videoControllerFromLocalPath(path);
