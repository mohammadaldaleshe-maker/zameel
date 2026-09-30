class PlaybackSource {
  final String value;
  final bool isLocal;
  const PlaybackSource(this.value, {required this.isLocal});
}

/// Selection policy shared by the native and web player factories.
/// lookupCached must be a cache-only operation, never a downloader.
Future<PlaybackSource> choosePlaybackSource(
  String value, {
  required Future<String?> Function(String) lookupCached,
  required Future<String> Function(String) resolveRemote,
}) async {
  final local = await lookupCached(value);
  if (local != null && local.isNotEmpty) return PlaybackSource(local, isLocal: true);
  return PlaybackSource(await resolveRemote(value), isLocal: false);
}
