import 'package:flutter/material.dart';

import '../services/tts_service.dart';
import '../theme/app_theme.dart';

/// Tombol dengar jawaban AI. Hanya berbunyi saat ditekan.
class SpeakButton extends StatelessWidget {
  const SpeakButton({
    super.key,
    required this.text,
    this.compact = false,
    this.label,
  });

  final String text;
  final bool compact;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final tts = TtsService.instance;
    return ListenableBuilder(
      listenable: tts,
      builder: (context, _) {
        final active = tts.isSpeaking;
        final textLabel = label ?? (active ? 'Berhenti' : 'Dengarkan');
        if (compact) {
          return IconButton(
            tooltip: textLabel,
            onPressed: text.trim().isEmpty
                ? null
                : () => tts.toggle(text),
            icon: Icon(
              active ? Icons.stop_circle_outlined : Icons.volume_up_outlined,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
          );
        }
        return TextButton.icon(
          onPressed: text.trim().isEmpty ? null : () => tts.toggle(text),
          icon: Icon(
            active ? Icons.stop_circle_outlined : Icons.volume_up_outlined,
            size: 18,
          ),
          label: Text(textLabel),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.primary,
            padding: const EdgeInsets.symmetric(horizontal: SonaSpacing.sm),
          ),
        );
      },
    );
  }
}
