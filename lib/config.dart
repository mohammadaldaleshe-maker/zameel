/// Runtime configuration for Zameel.
///
/// Values can be overridden at build time with --dart-define. The publishable
/// Supabase key is safe to ship in a client app; never put a service-role key
/// or other privileged secret here.
class ZameelConfig {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://jwuqyykjmltroneqtjoc.supabase.co',
  );

  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_TC_UtlL14Q0LVhLejd27lQ_MZphnhlv',
  );



  // Optional TURN relay. Leave empty when no TURN service is configured.
  // Use --dart-define in Codemagic/CI rather than hard-coding credentials.
  static const webrtcTurnUrl = String.fromEnvironment('WEBRTC_TURN_URL');
  static const webrtcTurnUsername = String.fromEnvironment('WEBRTC_TURN_USERNAME');
  static const webrtcTurnCredential = String.fromEnvironment('WEBRTC_TURN_CREDENTIAL');

  static const appName = 'Zameel';
  static const appVersion = String.fromEnvironment(
    'ZAMEEL_VERSION',
    defaultValue: '1.3.8+31',
  );
}
