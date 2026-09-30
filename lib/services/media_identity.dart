/// A storage object keeps its identity when a signed URL is renewed. Keep
/// transformation parameters (width/quality/etc.) so variants never collide.
String mediaIdentity(String value, {String? storageOrigin}) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null) return value;
  if (uri.scheme == 'zameel-private') {
    final authority = Uri.tryParse(storageOrigin ?? '')?.authority ?? '';
    return 'storage:$authority/${uri.host}/${uri.queryParameters['path'] ?? ''}';
  }
  final parts = uri.pathSegments;
  final object = parts.indexOf('object');
  if (object > 1 && parts[object - 1] == 'v1' && parts[object - 2] == 'storage' &&
      object + 3 < parts.length && ['public', 'sign'].contains(parts[object + 1])) {
    final params = Map<String, String>.from(uri.queryParameters)..remove('token');
    final suffix = params.isEmpty ? '' : '?${Uri(queryParameters: params).query}';
    return 'storage:${uri.authority}/${parts.sublist(object + 2).join('/')}$suffix';
  }
  return value.trim();
}

bool isStorageMedia(String value) => mediaIdentity(value).startsWith('storage:');
