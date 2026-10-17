import fs from 'node:fs';
import assert from 'node:assert/strict';

const read = rel => fs.readFileSync(new URL(`../${rel}`, import.meta.url), 'utf8');
let checks = 0;
const ok = (cond, msg) => { assert.ok(cond, msg); checks++; };

const publish = read('lib/services/post_publish_service.dart');
ok(publish.includes('_maxPhotoSide = 1600') && publish.includes('_photoQuality = 85'), 'photo size and quality limits are defined');
ok((publish.match(/maxWidth: _maxPhotoSide/g) || []).length === 2 && (publish.match(/maxHeight: _maxPhotoSide/g) || []).length === 2, 'both multi pickers resize photos');
ok(publish.includes('ImagePicker().pickMultiImage(') && publish.includes('ImagePicker().pickMultipleMedia('), 'picker call shapes required by the contract tests are kept');

const secure = read('lib/services/secure_media_service.dart');
ok(secure.includes('static Future<void> prewarm(') && secure.includes('createSignedUrls('), 'batched signing exists');
ok(/prewarm[\s\S]*mediaIdentity\(text, storageOrigin: ZameelConfig\.supabaseUrl\)/.test(secure), 'prewarm uses the same cache key as resolve');
ok(secure.includes("publicRef.bucket == 'posts'") && secure.includes("'graduation_book'"), 'prewarm only signs the buckets resolve signs');

const home = read('lib/features/home_feed.dart');
ok(home.includes('SecureMediaService.prewarm(') && home.includes('Duration(milliseconds: 1500)'), 'feed signs a page of media in one capped batch');
ok(home.includes('loaded.take(8)') && home.includes('limit: 6'), 'more images are prefetched');
{
  const batch = home.indexOf('SecureMediaService.prewarm(');
  const shown = home.indexOf('_networkFeedShown = true;');
  const guard = home.indexOf('requestVersion != _postsRequestVersion', batch);
  ok(batch > 0 && guard > batch && shown > guard, 'stale responses are dropped after the batch signing, before the feed is shown');
}

console.log(`PASS: performance 170 (${checks} checks).`);
