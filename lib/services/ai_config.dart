/// Konfigurasi endpoint & model AI.
///
/// Semua panggilan AI lewat Cloudflare Worker proxy agar API key tidak
/// tertanam di APK. Base URL diakhiri "/" dan client menambahkan path.
class AiConfig {
  AiConfig._();

  /// Worker proxy live (Gemini + Groq).
  static const proxyBaseUrl = 'https://sona-proxy.habibighufron.workers.dev/v1/';

  /// Timeout jaringan.
  static const requestTimeout = Duration(seconds: 120);

  /// OAuth Client ID (tipe Web/server) dari Google Cloud Console.
  /// Dipakai `google_sign_in` sebagai `serverClientId` agar mendapat ID token.
  static const googleServerClientId =
      '322729861602-qgbcdbcnc817ncvn0ic0386rp9uubr0s.apps.googleusercontent.com';

  static Uri chatUri() => Uri.parse('${proxyBaseUrl}chat/completions');
}
