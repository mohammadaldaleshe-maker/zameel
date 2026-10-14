/** Call with a user-scoped Supabase client AFTER Auth validates its bearer JWT. */
export async function deviceAllowed160(userClient) {
  try {
    const {data,error}=await userClient.rpc('zameel_device_authorized160');
    return !error && data === true;
  } catch { return false; }
}
