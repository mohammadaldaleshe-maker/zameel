export function incomingCallData(session, notification, callerName, now = Date.now()) {
  const created = Date.parse(String(session?.created_at ?? ''));
  if (!session || session.status !== 'ringing' ||
      session.callee_id !== notification.user_id ||
      String(session.room_id) !== String(notification.data?.room_id) ||
      !Number.isFinite(created) || created > now || now - created >= 45_000) return null;
  return {
    recipient_id: String(session.callee_id),
    caller_id: String(session.caller_id),
    caller_name: String(callerName || 'زميل').slice(0, 80),
    expires_at_ms: String(created + 45_000),
  };
}
export function isNativeCallDevice(platform) {
  return String(platform).toLowerCase() === 'android_call_v3';
}
export function callEndRecipients(session) {
  if (!session || session.status === 'ringing') return [];
  return [...new Set([session.caller_id, session.callee_id].filter(Boolean))];
}
