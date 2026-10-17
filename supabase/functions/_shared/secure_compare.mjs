/**
 * Constant-time comparison of two secrets.
 *
 * Both values are hashed with SHA-256 first, so the comparison always runs over
 * 32 bytes regardless of input length and never short-circuits on the first
 * differing byte. Returns false for empty or non-string values, so a missing
 * server secret can never authorise a request.
 */
export async function secretsEqual(provided, expected) {
  if (typeof provided !== 'string' || typeof expected !== 'string') return false;
  if (provided.length === 0 || expected.length === 0) return false;
  const encoder = new TextEncoder();
  const [a, b] = await Promise.all([
    crypto.subtle.digest('SHA-256', encoder.encode(provided)),
    crypto.subtle.digest('SHA-256', encoder.encode(expected)),
  ]);
  const left = new Uint8Array(a);
  const right = new Uint8Array(b);
  let difference = 0;
  for (let index = 0; index < left.length; index += 1) difference |= left[index] ^ right[index];
  return difference === 0;
}
