// Preparatory server module. Not an HTTP endpoint and does not grant entitlements.
// Trusted intent must be loaded by the server after authenticating the caller.
const PACKAGE = 'com.zameel.app';
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export class PurchaseError extends Error {
  constructor(code) { super(code); this.name = 'PurchaseError'; this.code = code; }
}
const fail = (code) => { throw new PurchaseError(code); };
export function productForIntent(intent) {
  if (!intent || !UUID.test(intent.id ?? '') || !UUID.test(intent.userId ?? '')) fail('invalid_intent');
  if (intent.kind === 'verification' && intent.days == null) return 'zameel_verification_month';
  if (intent.kind === 'promotion' && Number.isInteger(intent.days) && intent.days >= 1 && intent.days <= 30) {
    return `zameel_promotion_${String(intent.days).padStart(2, '0')}_days`;
  }
  fail('invalid_intent_product');
}
export function validateInput(input, authenticatedUserId, intent) {
  if (!UUID.test(authenticatedUserId ?? '')) fail('authentication_required');
  const productId = productForIntent(intent);
  if (intent.userId !== authenticatedUserId) fail('intent_owner_mismatch');
  if (intent.state !== 'awaiting_payment' && intent.state !== 'paid') fail('intent_unavailable');
  if (!input || typeof input !== 'object' || Array.isArray(input)) fail('invalid_input');
  // Do not accept URLs, package names, prices or user identities from the device.
  if (Object.keys(input).some(k => !['intentId', 'purchaseToken'].includes(k))) fail('unexpected_input');
  if (input.intentId !== intent.id) fail('intent_mismatch');
  if (typeof input.purchaseToken !== 'string' || input.purchaseToken.length < 1 || input.purchaseToken.length > 4096 || /[\s\x00-\x1f\x7f]/.test(input.purchaseToken)) fail('invalid_purchase_token');
  for (const key of ['accountBinding', 'intentBinding']) {
    if (typeof intent[key] !== 'string' || !/^[a-f0-9]{64}$/.test(intent[key])) fail('missing_purchase_binding');
  }
  return { packageName: PACKAGE, productId, purchaseToken: input.purchaseToken };
}
export function validateGooglePurchase(purchase, expected, { allowTest = false, recordedToken = false } = {}) {
  if (!purchase || typeof purchase !== 'object' || Array.isArray(purchase)) fail('invalid_google_response');
  if (purchase.purchaseState === 2) fail('purchase_pending');
  if (purchase.purchaseState !== 0) fail('purchase_not_completed');
  if (purchase.productId != null && purchase.productId !== expected.productId) fail('product_mismatch');
  if (purchase.purchaseToken != null && purchase.purchaseToken !== expected.purchaseToken) fail('token_mismatch');
  if (purchase.obfuscatedExternalAccountId !== expected.accountBinding || purchase.obfuscatedExternalProfileId !== expected.intentBinding) fail('purchase_binding_mismatch');
  if ((purchase.quantity ?? 1) !== 1) fail('unsupported_quantity');
  if (purchase.refundableQuantity !== undefined && purchase.refundableQuantity !== 1) fail('purchase_refunded');
  if (![0, 1].includes(purchase.consumptionState) || ![0, 1].includes(purchase.acknowledgementState)) fail('invalid_google_state');
  if (purchase.consumptionState === 1 && !recordedToken) fail('unrecognized_consumed_purchase');
  if (purchase.purchaseType !== undefined && purchase.purchaseType !== 0) fail('unsupported_purchase_type');
  if (purchase.purchaseType === 0 && !allowTest) fail('test_purchase_disabled');
  const purchasedAt = Number(purchase.purchaseTimeMillis);
  if (!Number.isSafeInteger(purchasedAt) || purchasedAt <= 0) fail('invalid_purchase_time');
  // Order IDs are optional. Dedupe must use the token, never orderId.
  return Object.freeze({ productId: expected.productId, purchasedAt,
    orderId: typeof purchase.orderId === 'string' ? purchase.orderId : null,
    needsAcknowledgement: purchase.acknowledgementState === 0,
    consumed: purchase.consumptionState === 1, isTest: purchase.purchaseType === 0 });
}
export async function verifyWithGoogle({ input, authenticatedUserId, intent, getAccessToken, fetchImpl = fetch,
  allowTest = false, recordedToken = false }) {
  const requested = validateInput(input, authenticatedUserId, intent);
  const accessToken = await getAccessToken();
  if (typeof accessToken !== 'string' || !accessToken || /[\r\n]/.test(accessToken)) fail('provider_credentials_unavailable');
  const url = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${PACKAGE}/purchases/products/${encodeURIComponent(requested.productId)}/tokens/${encodeURIComponent(requested.purchaseToken)}`;
  let response;
  try { response = await fetchImpl(url, { method: 'GET', redirect: 'error',
    headers: { Authorization: `Bearer ${accessToken}`, Accept: 'application/json' }, signal: AbortSignal.timeout(10000) }); }
  catch { fail('google_verification_unavailable'); }
  if (!response.ok) {
    // Never include provider bodies, credentials or purchase tokens in errors.
    fail(response.status === 404 || response.status === 400 ? 'purchase_not_found' : 'google_verification_unavailable');
  }
  let purchase;
  try { purchase = await response.json(); } catch { fail('invalid_google_response'); }
  return validateGooglePurchase(purchase, { ...requested, accountBinding: intent.accountBinding,
    intentBinding: intent.intentBinding }, { allowTest, recordedToken });
}
