import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/sona_store.dart';
import '../../domain/chat_commands.dart';
import '../../domain/text_format.dart';
import '../../services/ai_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/sona_animations.dart';
import '../../widgets/speak_button.dart';

class ChatMessage {
  ChatMessage(this.role, this.text, {this.imagePath, String? id})
      : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();
  final String role; // 'user' | 'assistant'
  final String text;
  final String? imagePath;
  final String id;
  bool error = false;
}

class ConsultScreen extends StatefulWidget {
  const ConsultScreen({super.key, required this.store, required this.ai});

  final SonaStore store;
  final AiService ai;

  @override
  State<ConsultScreen> createState() => _ConsultScreenState();
}

class _ConsultScreenState extends State<ConsultScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _picker = ImagePicker();
  final List<ChatMessage> _messages = [];
  bool _busy = false;
  String? _slashQuery;
  String? _pendingImage;
  int? _editIndex;

  static const _suggestions = [
    'Menu murah tinggi protein buat hari ini?',
    'Makan malam 500 kalori yang sehat apa?',
    'Cara kurangi garam di mie instan?',
  ];

  @override
  void initState() {
    super.initState();
    for (final m in widget.store.loadChat()) {
      final role = m['role'] ?? 'user';
      final text = m['text'] ?? '';
      _messages.add(ChatMessage(
        role,
        role == 'assistant' ? SonaText.cleanAi(text) : text,
        imagePath: m['image'],
      ));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _messages.isNotEmpty) {
        _scrollToBottom(jump: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_scroll.hasClients) return;
      final pos = _scroll.position;
      final target = pos.maxScrollExtent;
      if (target < pos.pixels) return;
      if (jump) {
        pos.jumpTo(target);
      } else {
        await pos.animateTo(
          target,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _controller.text).trim();
    final image = _pendingImage;
    if (text.isEmpty && image == null) return;
    if (_busy) return;
    if (preset == null) _controller.clear();
    setState(() {
      _slashQuery = null;
      _pendingImage = null;
      // Edit: pesan & jawaban tetap terlihat sampai user benar-benar
      // mengirim ulang. Saat kirim, potong dari pesan yang diedit lalu
      // ganti dengan versi barunya.
      final editAt = _editIndex;
      _editIndex = null;
      if (editAt != null && editAt >= 0 && editAt < _messages.length) {
        _messages.removeRange(editAt, _messages.length);
      }
    });
    await _run(text, imagePath: image);
  }

  /// Deteksi apakah kolom teks sedang mengetik `/command`.
  void _onComposerChanged(String value) {
    final q = slashQueryOf(value);
    if (q != _slashQuery) setState(() => _slashQuery = q);
    // Batalkan mode edit bila input dikosongkan.
    if (_editIndex != null && value.trim().isEmpty) {
      _editIndex = null;
    }
  }

  /// Jalankan pintasan: langsung kirim prompt command (+ foto bila dilampirkan).
  void _runCommand(ChatCommand cmd) {
    _controller.clear();
    _send(cmd.prompt);
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_busy) return;
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        imageQuality: 82,
      );
      if (picked == null) return;
      setState(() => _pendingImage = picked.path);
    } catch (e) {
      if (!mounted) return;
      _showNetworkPopup();
      setState(() {
        final m = ChatMessage('assistant',
            'Tidak bisa membuka kamera/galeri. Silakan cek izin aplikasi.');
        m.error = true;
        _messages.add(m);
      });
    }
  }

  Future<void> _showNetworkPopup() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tidak terhubung ke internet'),
        content: const Text(
          'Koneksi ke Sona bermasalah. Silakan cek jaringan Wi-Fi/data kamu lalu coba lagi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Oke'),
          ),
        ],
      ),
    );
  }

  Future<void> _run(String text, {String? imagePath}) async {
    final history = _messages
        .where((m) => !m.error && m.text.trim().isNotEmpty)
        .take(16)
        .map((m) => ChatTurn(role: m.role, text: SonaText.cleanAi(m.text)))
        .toList();

    String? base64Image;
    String? mime;
    if (imagePath != null) {
      try {
        final bytes = await File(imagePath).readAsBytes();
        base64Image = base64Encode(bytes);
        mime =
            imagePath.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
      } catch (_) {
        if (!mounted) return;
        _showNetworkPopup();
        return;
      }
    }

    setState(() {
      _messages.add(ChatMessage('user', text, imagePath: imagePath));
      _messages.add(ChatMessage('assistant', ''));
      _busy = true;
    });
    _scrollToBottom();

    final buffer = StringBuffer();
    try {
      await for (final piece in widget.ai.stream(
        prompt: text.isEmpty ? 'Ini foto makananku, tolong nilai gizinya.' : text,
        mode: base64Image != null ? AiMode.food : AiMode.text,
        imageBase64: base64Image,
        mimeType: mime,
        history: history,
      )) {
        buffer.write(piece);
        if (!mounted) return;
        setState(() {
          _messages[_messages.length - 1] =
              ChatMessage('assistant', SonaText.cleanAi(buffer.toString()));
        });
        _scrollToBottom();
      }
    } on AiException {
      if (!mounted) return;
      _showNetworkPopup();
      setState(() {
        final m = ChatMessage('assistant',
            'Silakan cek koneksi internet kamu. Tidak bisa terhubung ke Sona saat ini.');
        m.error = true;
        _messages[_messages.length - 1] = m;
      });
    } catch (e) {
      if (!mounted) return;
      final s = e.toString().toLowerCase();
      if (s.contains('socket') ||
          s.contains('network') ||
          s.contains('timeout') ||
          s.contains('connection')) {
        _showNetworkPopup();
        setState(() {
          final m = ChatMessage('assistant',
              'Silakan cek koneksi internet kamu. Coba lagi dalam beberapa saat.');
          m.error = true;
          _messages[_messages.length - 1] = m;
        });
      } else {
        setState(() {
          final m = ChatMessage('assistant',
              'Terjadi kendala sementara. Coba kirim ulang pesannya ya.');
          m.error = true;
          _messages[_messages.length - 1] = m;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _persist();
        _scrollToBottom(jump: true);
      }
    }
  }

  void _pickImageSource() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(SonaRadius.lg)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined,
                  color: SonaColors.primary),
              title: const Text('Ambil dari kamera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: SonaColors.primary),
              title: const Text('Pilih dari galeri'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _persist() {
    final data = _messages
        .where((m) => m.text.trim().isNotEmpty || m.imagePath != null)
        .map((m) => {
              'role': m.role,
              'text': m.role == 'assistant' ? SonaText.cleanAi(m.text) : m.text,
            }..addAll(m.imagePath != null ? {'image': m.imagePath!} : const {}))
        .toList();
    widget.store.saveChat(data);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? _emptyState()
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(SonaSpacing.margin),
                  itemCount: _messages.length,
                  itemBuilder: (context, i) {
                    final m = _messages[i];
                    return SonaEntrance(
                      key: ValueKey(m.id),
                      dy: 10,
                      child: _bubble(m),
                    );
                  },
                ),
        ),
        if (_pendingImage != null) _pendingPreview(),
        if (_slashQuery != null) _commandPanel(),
        _composer(),
      ],
    );
  }

  /// Pratinjau foto yang dilampirkan (belum terkirim).
  Widget _pendingPreview() {
    return Container(
      width: double.infinity,
      color: SonaColors.surface,
      padding: const EdgeInsets.fromLTRB(
          SonaSpacing.margin, SonaSpacing.sm, SonaSpacing.margin, 0),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(SonaRadius.sm),
                child: Image.file(
                  File(_pendingImage!),
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                right: -8,
                top: -8,
                child: GestureDetector(
                  onTap: () => setState(() => _pendingImage = null),
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: SonaColors.error,
                    ),
                    padding: const EdgeInsets.all(2),
                    child: const Icon(Icons.close,
                        size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: SonaSpacing.sm),
          Expanded(
            child: Text(
              'Foto siap dikirim. Pilih pintasan / atau ketik pesanmu.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  /// Panel pintasan prompt yang muncul saat user mengetik `/`.
  Widget _commandPanel() {
    final matches = matchChatCommands(_slashQuery ?? '');
    return Container(
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        border: Border(
          top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: matches.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(SonaSpacing.md),
              child: Text(
                'Tidak ada pintasan untuk "$_slashQuery".',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: SonaSpacing.xs),
              itemCount: matches.length,
              itemBuilder: (context, i) {
                final c = matches[i];
                return InkWell(
                  onTap: _busy ? null : () => _runCommand(c),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: SonaSpacing.margin, vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(context).colorScheme.primaryContainer,
                          ),
                          child: Icon(c.icon,
                              size: 18, color: Theme.of(context).colorScheme.primary),
                        ),
                        const SizedBox(width: SonaSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.slash,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: Theme.of(context).colorScheme.primary,
                                      )),
                              Text(c.description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                        Icon(Icons.north_west,
                            size: 16,
                            color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _emptyState() {
    return ListView(
      padding: const EdgeInsets.all(SonaSpacing.margin),
      children: [
        const SizedBox(height: SonaSpacing.lg),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: SonaColors.emeraldTint,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy, size: 36, color: SonaColors.primary),
          ),
        ),
        const SizedBox(height: SonaSpacing.md),
        Text('Tanya Sona soal gizi & budget',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: SonaSpacing.xs),
        Text(
          'Ceritakan makananmu, minta ide menu hemat, atau tanya soal label kemasan.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: SonaSpacing.lg),
        ..._suggestions.map(
          (s) => Padding(
            padding: const EdgeInsets.only(bottom: SonaSpacing.sm),
            child: GestureDetector(
              onTap: () => _send(s),
              child:               Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: SonaSpacing.md, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(SonaRadius.full),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline,
                        size: 16, color: SonaColors.primary),
                    const SizedBox(width: SonaSpacing.sm),
                    Expanded(
                    child: Text(s,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                            )),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _copyText(String text) async {
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Teks disalin')),
    );
  }

  Future<void> _editUserMessage(ChatMessage m, int index) async {
    if (_busy || !mounted) return;
    // Pesan & jawaban tetap tampil. Teks hanya disalin ke kotak input;
    // riwayat dipotong nanti saat user benar-benar mengirim ulang.
    setState(() => _editIndex = index);
    _controller.text = m.text;
    _controller.selection =
        TextSelection.collapsed(offset: m.text.length);
    _scrollToBottom();
  }

  Future<void> _deleteFrom(int index) async {
    if (_busy || !mounted) return;
    setState(() {
      _editIndex = null;
      _messages.removeRange(index, _messages.length);
    });
    _persist();
    _scrollToBottom(jump: true);
  }

  Future<void> _regenerateFrom(int index) async {
    if (_busy || index < 0 || index >= _messages.length) return;
    // Ambil pesan user di index ini
    final userMsg = _messages[index];
    if (userMsg.role != 'user') return;
    // Hapus userMsg dan semua setelahnya, lalu kirim ulang
    setState(() {
      _editIndex = null;
      _messages.removeRange(index, _messages.length);
    });
    _controller.text = userMsg.text;
    if (userMsg.imagePath != null) {
      _pendingImage = userMsg.imagePath;
    }
    await _send();
  }

  void _userActions(ChatMessage m, int index) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(SonaRadius.lg)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit pesan'),
              onTap: () {
                Navigator.of(ctx).pop();
                _editUserMessage(m, index);
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Kirim ulang'),
              onTap: () {
                Navigator.of(ctx).pop();
                _regenerateFrom(index);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Hapus pesan & jawaban setelahnya'),
              onTap: () {
                Navigator.of(ctx).pop();
                _deleteFrom(index);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Salin'),
              onTap: () {
                Navigator.of(ctx).pop();
                _copyText(m.text);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(ChatMessage m) {
    final isUser = m.role == 'user';
    final body = isUser ? m.text : SonaText.cleanAi(m.text);
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: isUser && !_busy
            ? () {
                final idx = _messages.indexOf(m);
                if (idx >= 0) _userActions(m, idx);
              }
            : null,
        onTap: isUser && !_busy
            ? () {
                final idx = _messages.indexOf(m);
                if (idx >= 0) _userActions(m, idx);
              }
            : null,
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: SonaSpacing.xs),
              padding: const EdgeInsets.symmetric(
                  horizontal: SonaSpacing.md, vertical: 10),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              decoration: BoxDecoration(
                color: isUser
                    ? Theme.of(context).colorScheme.primary
                    : (m.error
                        ? Theme.of(context).colorScheme.errorContainer
                        : Theme.of(context).colorScheme.surfaceContainerHigh),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(SonaRadius.md),
                  topRight: const Radius.circular(SonaRadius.md),
                  bottomLeft: Radius.circular(isUser ? SonaRadius.md : SonaRadius.xs),
                  bottomRight: Radius.circular(isUser ? SonaRadius.xs : SonaRadius.md),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0F000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment:
                    isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (m.imagePath != null)
                    Padding(
                      padding: EdgeInsets.only(bottom: body.isEmpty ? 0 : 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(SonaRadius.sm),
                        child: Image.file(
                          File(m.imagePath!),
                          width: 180,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
              if (m.imagePath == null || body.isNotEmpty)
                body.isEmpty && !isUser
                    ? const _TypingDots()
                    : isUser
                        // Pesan kita: ketuk langsung untuk aksi edit/salin/hapus.
                        ? Text(
                            body,
                            style:
                                Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimary,
                                    ),
                          )
                        : SelectableText(
                            body,
                            style:
                                Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: m.error
                                          ? Theme.of(context)
                                              .colorScheme
                                              .onErrorContainer
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                    ),
                          ),
                ],
              ),
            ),
            if (isUser && body.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: SonaSpacing.xs),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Salin pesan',
                      visualDensity: VisualDensity.compact,
                      onPressed: _busy ? null : () => _copyText(m.text),
                      icon: const Icon(Icons.copy, size: 16),
                    ),
                    IconButton(
                      tooltip: 'Edit pesan',
                      visualDensity: VisualDensity.compact,
                      onPressed: _busy
                          ? null
                          : () {
                              final idx = _messages.indexOf(m);
                              if (idx >= 0) _editUserMessage(m, idx);
                            },
                      icon: const Icon(Icons.edit_outlined, size: 16),
                    ),
                  ],
                ),
              ),
            if (!isUser && body.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: SonaSpacing.sm),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SpeakButton(text: body, compact: true),
                    const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Salin jawaban',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _copyText(body),
                    icon: const Icon(Icons.copy, size: 16),
                  ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _composer() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        SonaSpacing.margin,
        SonaSpacing.sm,
        SonaSpacing.margin,
        MediaQuery.of(context).padding.bottom + SonaSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        boxShadow: const [
          BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, -3)),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _busy ? null : _pickImageSource,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: SonaColors.emeraldTint,
              ),
              child: const Icon(Icons.add_photo_alternate_outlined,
                  color: SonaColors.primary, size: 22),
            ),
          ),
          const SizedBox(width: SonaSpacing.sm),
          GestureDetector(
            onTap: _busy
                ? null
                : () => setState(() {
                      _controller.text = '/';
                      _controller.selection = const TextSelection.collapsed(
                          offset: 1);
                      _slashQuery = '';
                    }),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: SonaColors.emeraldTint,
              ),
              child: const Center(
                child: Text('/',
                    style: TextStyle(
                      color: SonaColors.primary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    )),
              ),
            ),
          ),
          const SizedBox(width: SonaSpacing.sm),
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onChanged: _onComposerChanged,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: 'Tanya apa saja... atau ketik / untuk pintasan',
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: SonaSpacing.md, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(SonaRadius.full),
                  borderSide: BorderSide(
                    color: SonaColors.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(SonaRadius.full),
                  borderSide: BorderSide(
                    color: SonaColors.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(SonaRadius.full),
                  borderSide: const BorderSide(color: SonaColors.primary),
                ),
              ),
            ),
          ),
          const SizedBox(width: SonaSpacing.sm),
          GestureDetector(
            onTap: _busy ? null : () => _send(),
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [SonaColors.primary, SonaColors.primaryContainer],
                ),
              ),
              child: _busy
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: SonaColors.onPrimary,
                      ),
                    )
                  : const Icon(Icons.send, color: SonaColors.onPrimary, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final t = ((_c.value * 3) - i).clamp(0.0, 1.0);
            final opacity = 0.3 + 0.7 * (t < 0.5 ? t * 2 : (1 - t) * 2);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: SonaColors.primary.withValues(alpha: opacity.clamp(0.3, 1.0)),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}
