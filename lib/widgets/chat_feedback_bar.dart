import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';

/// Thumbs up/down on a single Vidya or EduTrack Support reply. Thumbs-down
/// opens a reason-chip picker before submitting; thumbs-up submits directly.
/// Self-contained — owns its own submitted/rating state, independent of the
/// chat screen's message list.
class ChatFeedbackBar extends StatefulWidget {
  final String bot; // 'vidya' | 'support'
  final String question;
  final String reply;

  const ChatFeedbackBar({super.key, required this.bot, required this.question, required this.reply});

  @override
  State<ChatFeedbackBar> createState() => _ChatFeedbackBarState();
}

class _ChatFeedbackBarState extends State<ChatFeedbackBar> {
  String? _rating;
  bool _showReasons = false;
  bool _submitting = false;

  static const _reasons = [
    ('wrong_data', 'Wrong data'),
    ('didnt_understand', "Didn't understand"),
    ('not_helpful', 'Not helpful'),
  ];

  Future<void> _submit(String rating, {String? reason}) async {
    if (_submitting || _rating != null) return;
    setState(() { _submitting = true; _rating = rating; _showReasons = false; });
    try {
      await ParentApiClient.submitChatFeedback(
        bot: widget.bot, question: widget.question, reply: widget.reply,
        rating: rating, reason: reason,
      );
    } catch (_) {
      // Silent — feedback is a nice-to-have, not worth interrupting the chat.
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_rating != null) {
      return Padding(
        padding: const EdgeInsets.only(left: 36, top: 2, bottom: 6),
        child: Text(
          'Thanks for the feedback',
          style: TextStyle(fontSize: 11, color: AppColors.muted.withOpacity(0.8)),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(left: 36, top: 2, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _RateIcon(icon: Icons.thumb_up_outlined, onTap: () => _submit('up')),
              const SizedBox(width: 12),
              _RateIcon(
                icon: Icons.thumb_down_outlined,
                onTap: () => setState(() => _showReasons = true),
              ),
            ],
          ),
          if (_showReasons) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: _reasons.map((r) => GestureDetector(
                onTap: () => _submit('down', reason: r.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.coralLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.coral.withOpacity(0.4)),
                  ),
                  child: Text(r.$2, style: const TextStyle(fontSize: 11, color: AppColors.text2, fontWeight: FontWeight.w600)),
                ),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _RateIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RateIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, size: 16, color: AppColors.muted),
    );
  }
}
