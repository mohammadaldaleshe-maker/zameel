import 'package:flutter_test/flutter_test.dart';
import 'package:zameel/services/media_identity.dart';

void main() {
  const origin = 'https://project.supabase.co';
  test('signatures and original private refs share an immutable object identity', () {
    final marker = Uri(scheme: 'zameel-private', host: 'posts',
        queryParameters: {'path': 'alice/photo.jpg'}).toString();
    final signed = '$origin/storage/v1/object/sign/posts/alice/photo.jpg?token=old';
    expect(mediaIdentity(marker, storageOrigin: origin), mediaIdentity(signed));
    expect(mediaIdentity(signed), mediaIdentity(signed.replaceAll('old', 'new')));
    expect(mediaIdentity('$origin/storage/v1/object/public/posts/alice/photo.jpg'), mediaIdentity(signed));
  });
  test('different objects, hosts and image variants cannot collide', () {
    const path = '/storage/v1/object/sign/posts/a.jpg';
    expect(mediaIdentity('$origin$path?width=200&token=x'),
        isNot(mediaIdentity('$origin$path?width=800&token=y')));
    expect(mediaIdentity('$origin$path'), isNot(mediaIdentity('https://other.supabase.co$path')));
    expect(mediaIdentity('$origin$path'), isNot(mediaIdentity('$origin${path.replaceAll('a.jpg', 'b.jpg')}')));
  });
}
