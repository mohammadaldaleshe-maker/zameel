/** Worker core is dependency-injected so failure ordering can be tested offline. */
export async function processDeletion(job, io, maxBatches = 4) {
  await io.ban(job.user_id);
  await io.discover(job);
  if (!job.data_removed) await io.removeData(job);
  for (let batch = 0; batch < maxBatches; batch++) {
    const files = await io.files(job.id, 100);
    if (files.length === 0) {
      // Catch uploads that finished after the initial snapshot.
      await io.discover(job);
      const remaining = await io.files(job.id, 1);
      if (remaining.length !== 0) continue;
      await io.deleteAuth(job.user_id);
      await io.finish(job);
      return 'completed';
    }
    const buckets = new Map();
    for (const file of files) {
      if (typeof file.bucket_id !== 'string' || typeof file.name !== 'string' || !file.name) {
        throw new Error('invalid_file_manifest');
      }
      const names = buckets.get(file.bucket_id) ?? [];
      names.push(file.name);
      buckets.set(file.bucket_id, names);
    }
    for (const [bucket, names] of buckets) {
      await io.removeStorage(bucket, names);
      // A failure must leave the manifest for an idempotent retry.
      await io.ackFiles(job.id, bucket, names);
    }
  }
  return 'pending';
}
