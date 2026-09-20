import 'package:audioplayers/audioplayers.dart';

class AppSoundService {
  AppSoundService._();
  static final AppSoundService instance = AppSoundService._();

  final AudioPlayer _player = AudioPlayer();

  Future<void> playRingback() async {
    await stop();
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.play(AssetSource('sounds/zameel_ringback.wav'));
  }

  Future<void> stop() => _player.stop();

  Future<void> dispose() => _player.dispose();
}
