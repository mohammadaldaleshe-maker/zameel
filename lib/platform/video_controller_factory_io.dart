import 'dart:io';
import 'package:video_player/video_player.dart';

VideoPlayerController videoControllerFromLocalPath(String path) =>
    VideoPlayerController.file(File(path));
