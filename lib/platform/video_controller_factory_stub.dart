import 'package:video_player/video_player.dart';

VideoPlayerController videoControllerFromLocalPath(String path) =>
    VideoPlayerController.networkUrl(Uri.parse(path));
