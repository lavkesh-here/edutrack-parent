import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';

class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({super.key});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_Msg> _messages = [];
  bool _loading = false;

  static const _maxChars = 500;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading) return;

    setState(() {
      _messages.add(_Msg(role: 'user', text: text));
      _loading = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final history = _messages.length > 1
          ? _messages
              .sublist(0, _messages.length - 1)
              .takeLast(10)
              .map((m) => {'role': m.role, 'text': m.text})
              .toList()
          : <Map<String, String>>[];

      final reply = await ParentApiClient.supportChat(
        message: text,
        history: history,
      );
      if (mounted) {
        setState(() => _messages.add(_Msg(role: 'model', text: reply)));
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _messages.add(const _Msg(
          role: 'model',
          text: 'Sorry, I\'m unavailable right now. Please try again in a moment.',
          isError: true,
        )));
        _scrollToBottom();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearChat() => setState(() => _messages.clear());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('EduTrack Support', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            Text('App help only • Replies may not be perfect',
                style: TextStyle(fontSize: 10, color: AppColors.muted, fontWeight: FontWeight.w400)),
          ],
        ),
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (_messages.isNotEmpty)
            TextButton(
              onPressed: _clearChat,
              child: const Text('Clear', style: TextStyle(color: AppColors.muted, fontSize: 13)),
            ),
        ],
      ),
      body: Column(
        children: [
          // Disclaimer banner
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.tealLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.teal.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Text('ℹ️', style: TextStyle(fontSize: 13)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'I can only answer questions about using the EduTrack app.',
                    style: TextStyle(fontSize: 12, color: AppColors.text2),
                  ),
                ),
              ],
            ),
          ),

          // Messages
          Expanded(
            child: _messages.isEmpty
                ? _EmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    itemCount: _messages.length + (_loading ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == _messages.length) return const _TypingBubble();
                      return _MessageBubble(msg: _messages[i]);
                    },
                  ),
          ),

          // Input row
          SafeArea(
            top: false,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.border, width: 1.5)),
              ),
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      maxLength: _maxChars,
                      maxLines: 4,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Ask anything about the app…',
                        hintStyle: TextStyle(color: AppColors.muted, fontSize: 14),
                        border: InputBorder.none,
                        counterText: '',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _loading ? null : _send,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _loading ? AppColors.muted : AppColors.teal,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _loading
                          ? const Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              ),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _Msg {
  const _Msg({required this.role, required this.text, this.isError = false});
  final String role;
  final String text;
  final bool isError;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.msg});
  final _Msg msg;

  @override
  Widget build(BuildContext context) {
    final isUser = msg.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.tealLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(child: Text('👨‍👩‍👧', style: TextStyle(fontSize: 13))),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? AppColors.teal
                    : msg.isError
                        ? const Color(0xFFFFF1F2)
                        : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: isUser
                    ? null
                    : Border.all(
                        color: msg.isError
                            ? const Color(0xFFFDA4AF)
                            : AppColors.border,
                        width: 1.5,
                      ),
              ),
              child: Text(
                msg.text,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: isUser
                      ? Colors.white
                      : msg.isError
                          ? const Color(0xFFBE123C)
                          : AppColors.text,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.tealLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(child: Text('👨‍👩‍👧', style: TextStyle(fontSize: 13))),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: const SizedBox(width: 36, height: 8, child: _DotIndicator()),
          ),
        ],
      ),
    );
  }
}

class _DotIndicator extends StatefulWidget {
  const _DotIndicator();

  @override
  State<_DotIndicator> createState() => _DotIndicatorState();
}

class _DotIndicatorState extends State<_DotIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(3, (i) {
          final phase = ((_ctrl.value * 3) - i).clamp(0.0, 1.0);
          final opacity = (phase < 0.5 ? phase : 1.0 - phase) * 2;
          return Opacity(
            opacity: 0.3 + opacity * 0.7,
            child: Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(color: AppColors.muted, shape: BoxShape.circle),
            ),
          );
        }),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.tealLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(child: Text('👨‍👩‍👧', style: TextStyle(fontSize: 30))),
            ),
            const SizedBox(height: 16),
            const Text(
              'How can I help?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ask me about checking attendance, viewing scores, linking your child, or any other app feature.',
              style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ..._suggestions.map((s) => _SuggestionChip(label: s)),
          ],
        ),
      ),
    );
  }

  static const _suggestions = [
    'How do I link my child?',
    'Where can I see attendance?',
    'How do I check test scores?',
  ];
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final state = context.findAncestorStateOfType<_SupportChatScreenState>();
        state?._controller.text = label;
        state?._send();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.text2)),
      ),
    );
  }
}

extension _ListTakeLast<T> on List<T> {
  List<T> takeLast(int n) => length <= n ? this : sublist(length - n);
}
