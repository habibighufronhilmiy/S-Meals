import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Pembaca suara (text-to-speech) berbahasa Indonesia.
///
/// Suara hanya berbunyi saat user menekan tombol — tidak pernah otomatis.
class TtsService extends ChangeNotifier {
  TtsService._();

  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  bool _speaking = false;
  String? _currentText;

  bool get isSpeaking => _speaking;

  Future<void> _init() async {
    if (_ready) return;
    await _tts.setLanguage('id-ID');
    await _tts.setSpeechRate(0.47);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
    await _tts.awaitSpeakCompletion(true);
    _tts.setCompletionHandler(_finish);
    _tts.setCancelHandler(_finish);
    _tts.setErrorHandler((_) => _finish());
    _ready = true;
  }

  void _finish() {
    _speaking = false;
    _currentText = null;
    notifyListeners();
  }

  /// Baca [text]. Bila teks yang sama sedang dibacakan, hentikan.
  Future<void> toggle(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (_speaking && _currentText == trimmed) {
      await stop();
      return;
    }
    await stop();
    await _init();
    _speaking = true;
    _currentText = trimmed;
    notifyListeners();
    try {
      await _tts.speak(trimmed);
      // Sebagian perangkat tidak memanggil handler selesai.
      _finish();
    } catch (_) {
      _finish();
    }
  }

  Future<void> stop() async {
    if (!_speaking) return;
    try {
      await _tts.stop();
    } catch (_) {
      // Abaikan.
    }
    _finish();
  }

  Future<void> disposeTts() async {
    await stop();
    _tts.stop();
  }
}
