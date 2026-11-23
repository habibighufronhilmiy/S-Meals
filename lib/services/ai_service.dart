import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ai_config.dart';

/// Mode pengiriman ke Worker.
enum AiMode { text, food, label }

/// Klien streaming ke Sona AI Proxy (Cloudflare Worker).
///
/// Worker membalas Server-Sent Events: tiap baris `data: {"text":"..."}`
/// lalu `data: [DONE]`. Instans ini menyatukan potongan-potongan itu menjadi
/// satu stream teks yang mulus untuk UI.
class AiService {
  AiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Mengirim prompt (opsional dengan gambar base64) dan mengembalikan
  /// stream potongan teks jawaban.
  Stream<String> stream({
    required String prompt,
    AiMode mode = AiMode.text,
    String? imageBase64,
    String? mimeType,
    List<ChatTurn> history = const [],
  }) async* {
    final request = http.Request('POST', AiConfig.chatUri());
    request.headers['content-type'] = 'application/json';
    final content = imageBase64 == null
        ? prompt
        : [
            {'type': 'text', 'text': prompt},
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:${mimeType ?? 'image/jpeg'};base64,$imageBase64',
              },
            },
          ];
    request.body = jsonEncode({
      'model': 'sona',
      'stream': true,
      'mode': mode.name,
      'messages': [
        if (history.isNotEmpty)
          for (final turn in history)
            {'role': turn.role, 'content': turn.text},
        {'role': 'user', 'content': content},
      ],
      'imageBase64': ?imageBase64,
      'mimeType': ?mimeType,
    });

    final response =
        await _client.send(request).timeout(AiConfig.requestTimeout);

    if (response.statusCode != 200) {
      final detail = await response.stream.bytesToString();
      throw AiException('HTTP ${response.statusCode}: ${detail.trim()}');
    }

    final lines = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in lines) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('data:')) continue;
      final data = trimmed.substring(5).trim();
      if (data.isEmpty || data == '[DONE]') continue;
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map && decoded['text'] is String) {
          final piece = decoded['text'] as String;
          if (piece.isNotEmpty) yield piece;
        }
      } catch (_) {
        // Lewati frame yang tidak valid.
      }
    }
  }

  /// Sekali panggil: mengumpulkan seluruh jawaban menjadi satu string.
  Future<String> complete({
    required String prompt,
    AiMode mode = AiMode.text,
    String? imageBase64,
    String? mimeType,
    List<ChatTurn> history = const [],
  }) async {
    final buffer = StringBuffer();
    await for (final piece in stream(
      prompt: prompt,
      mode: mode,
      imageBase64: imageBase64,
      mimeType: mimeType,
      history: history,
    )) {
      buffer.write(piece);
    }
    return buffer.toString();
  }

  void dispose() => _client.close();
}

/// Satu giliran percakapan yang dikirim sebagai konteks ke AI.
class ChatTurn {
  const ChatTurn({required this.role, required this.text});

  final String role; // 'user' atau 'assistant'
  final String text;
}

class AiException implements Exception {
  AiException(this.message);
  final String message;

  @override
  String toString() => message;
}
