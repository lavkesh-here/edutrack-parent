import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class ForumScreen extends StatefulWidget {
  const ForumScreen({super.key});

  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> {
  List<ForumPost>? _posts;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await ParentApiClient.getForumPosts();
      setState(() { _posts = list; _loading = false; });
    } on ApiError catch (e) {
      setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      setState(() { _error = 'Failed to load forum'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Forum'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
            color: AppColors.muted,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.teal,
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('😕', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        Text(_error!, style: const TextStyle(color: AppColors.muted)),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  )
                : _posts == null || _posts!.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 120),
                          Center(
                            child: Column(
                              children: [
                                Text('📢', style: TextStyle(fontSize: 48)),
                                SizedBox(height: 12),
                                Text('No announcements yet',
                                    style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600, fontSize: 15)),
                              ],
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: _posts!.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _ForumPostCard(
                          post: _posts![i],
                          onCommentTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => _ForumCommentsScreen(post: _posts![i]))),
                        ),
                      ),
      ),
    );
  }
}

// ── Post card ─────────────────────────────────────────────────────────────────

class _ForumPostCard extends StatelessWidget {
  final ForumPost post;
  final VoidCallback? onCommentTap;
  const _ForumPostCard({required this.post, this.onCommentTap});

  @override
  Widget build(BuildContext context) {
    final p = post;
    final preview = p.previewComment;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: p.isPinned ? AppColors.teal.withOpacity(0.4) : AppColors.border,
          width: p.isPinned ? 2 : 1.5,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: AppColors.tealLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    (p.authorName ?? 'S').substring(0, 1).toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.teal, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (p.isPinned) ...[
                          const Text('📌', style: TextStyle(fontSize: 12)),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            p.authorName ?? 'School',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Text(fmtDate(p.createdAt),
                        style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          if (p.title.isNotEmpty) ...[
            Text(p.title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.text)),
            const SizedBox(height: 4),
          ],

          if (p.body.isNotEmpty)
            Text(
              p.body,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: AppColors.text2, height: 1.5),
            ),

          // Images strip
          if (p.images.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: p.images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    p.images[i]['gcs_url'] as String? ?? '',
                    width: 90, height: 90,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 90, height: 90,
                      color: AppColors.bg,
                      child: const Icon(Icons.broken_image_outlined, color: AppColors.muted),
                    ),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 8),

          // Action bar
          Row(
            children: [
              const Icon(Icons.favorite_border_rounded, size: 16, color: AppColors.muted),
              const SizedBox(width: 4),
              Text('${p.likeCount}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600)),
              if (p.allowComments) ...[
                const SizedBox(width: 14),
                const Icon(Icons.mode_comment_outlined, size: 15, color: AppColors.muted),
                const SizedBox(width: 4),
                Text('${p.commentCount}',
                    style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600)),
              ],
              const Spacer(),
              if (p.allowComments && onCommentTap != null)
                GestureDetector(
                  onTap: onCommentTap,
                  child: Row(
                    children: [
                      Text(
                        p.commentCount > 0
                            ? 'View ${p.commentCount} comment${p.commentCount == 1 ? '' : 's'}'
                            : 'Add comment',
                        style: const TextStyle(fontSize: 11, color: AppColors.teal, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.chevron_right_rounded, size: 14, color: AppColors.teal),
                    ],
                  ),
                ),
            ],
          ),

          // Preview comment
          if (preview != null && p.allowComments) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onCommentTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: RichText(
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: const TextStyle(fontSize: 12, color: AppColors.text2),
                    children: [
                      TextSpan(
                        text: '${preview['author'] ?? ''} ',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.text),
                      ),
                      TextSpan(text: preview['body'] as String? ?? ''),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Comments screen ───────────────────────────────────────────────────────────

class _ForumCommentsScreen extends StatefulWidget {
  final ForumPost post;
  const _ForumCommentsScreen({required this.post});

  @override
  State<_ForumCommentsScreen> createState() => _ForumCommentsScreenState();
}

class _ForumCommentsScreenState extends State<_ForumCommentsScreen> {
  List<ForumComment> _comments = [];
  bool _loading = true;
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _posting = false;
  String? _replyToId;
  String? _replyToAuthor;
  bool _showBackToTop = false;

  @override
  void initState() {
    super.initState();
    _load();
    _scrollCtrl.addListener(() {
      final show = _scrollCtrl.offset > 400;
      if (show != _showBackToTop) setState(() => _showBackToTop = show);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ParentApiClient.getForumComments(widget.post.id);
      setState(() { _comments = data; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _post() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _posting) return;
    setState(() => _posting = true);
    try {
      await ParentApiClient.createForumComment(widget.post.id, text, parentId: _replyToId);
      _ctrl.clear();
      setState(() { _replyToId = null; _replyToAuthor = null; });
      await _load();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        }
      });
    } on ApiError catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topLevel = _comments.where((c) => c.parentId == null).toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(widget.post.title.isNotEmpty ? widget.post.title : 'Comments'),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
                : Stack(
                    children: [
                      _comments.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('💬', style: TextStyle(fontSize: 40)),
                                  SizedBox(height: 10),
                                  Text('No comments yet.\nBe the first!',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: AppColors.muted, fontSize: 13)),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              color: AppColors.teal,
                              onRefresh: _load,
                              child: ListView.builder(
                                controller: _scrollCtrl,
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                                itemCount: topLevel.length,
                                itemBuilder: (_, i) {
                                  final c = topLevel[i];
                                  final replies = _comments.where((r) => r.parentId == c.id).toList();
                                  return _ForumCommentBlock(
                                    comment: c,
                                    replies: replies,
                                    onReply: (id, author) => setState(() {
                                      _replyToId = id;
                                      _replyToAuthor = author;
                                    }),
                                  );
                                },
                              ),
                            ),
                      if (_showBackToTop)
                        Positioned(
                          bottom: 12, left: 0, right: 0,
                          child: Center(
                            child: GestureDetector(
                              onTap: () => _scrollCtrl.animateTo(0,
                                  duration: const Duration(milliseconds: 350), curve: Curves.easeOut),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.text.withOpacity(0.75),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text('Back to top',
                                    style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),

          if (_replyToAuthor != null)
            Container(
              color: AppColors.tealLight,
              padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
              child: Row(
                children: [
                  const Icon(Icons.reply_rounded, size: 14, color: AppColors.teal),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Replying to $_replyToAuthor',
                      style: const TextStyle(fontSize: 12, color: AppColors.teal, fontWeight: FontWeight.w600),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() { _replyToId = null; _replyToAuthor = null; }),
                    child: const Icon(Icons.close, size: 16, color: AppColors.teal),
                  ),
                ],
              ),
            ),

          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    decoration: InputDecoration(
                      hintText: _replyToAuthor != null ? 'Reply to $_replyToAuthor…' : 'Say something…',
                      filled: true,
                      fillColor: AppColors.bg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    ),
                    onSubmitted: (_) => _post(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _post,
                  child: Container(
                    width: 40, height: 40,
                    decoration: const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle),
                    child: _posting
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ForumCommentBlock extends StatelessWidget {
  final ForumComment comment;
  final List<ForumComment> replies;
  final void Function(String id, String author) onReply;

  const _ForumCommentBlock({required this.comment, required this.replies, required this.onReply});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ForumCommentTile(comment: comment, onReply: onReply),
        ...replies.map((r) => Padding(
          padding: const EdgeInsets.only(left: 32),
          child: _ForumCommentTile(comment: r, onReply: onReply, isReply: true),
        )),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _ForumCommentTile extends StatefulWidget {
  final ForumComment comment;
  final void Function(String id, String author) onReply;
  final bool isReply;

  const _ForumCommentTile({required this.comment, required this.onReply, this.isReply = false});

  @override
  State<_ForumCommentTile> createState() => _ForumCommentTileState();
}

class _ForumCommentTileState extends State<_ForumCommentTile> {
  late bool _liked;
  late int _likeCount;

  @override
  void initState() {
    super.initState();
    _liked = widget.comment.likedByMe;
    _likeCount = widget.comment.likeCount;
  }

  Future<void> _toggleLike() async {
    final was = _liked;
    setState(() { _liked = !_liked; _likeCount += _liked ? 1 : -1; });
    try {
      await ParentApiClient.toggleForumCommentLike(widget.comment.id);
    } catch (_) {
      if (mounted) setState(() { _liked = was; _likeCount += was ? 1 : -1; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.comment;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: widget.isReply ? 28 : 32,
            height: widget.isReply ? 28 : 32,
            decoration: BoxDecoration(
              color: widget.isReply ? AppColors.skyLight : AppColors.tealLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                (c.authorName ?? 'S').substring(0, 1).toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: widget.isReply ? AppColors.sky : AppColors.teal,
                  fontSize: widget.isReply ? 12 : 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.authorName ?? 'Teacher',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.text),
                        ),
                      ),
                      Text(fmtDate(c.createdAt),
                          style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(c.body, style: const TextStyle(fontSize: 13, color: AppColors.text2, height: 1.4)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _toggleLike,
                        child: Row(
                          children: [
                            Icon(
                              _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              size: 14,
                              color: _liked ? AppColors.coral : AppColors.muted,
                            ),
                            const SizedBox(width: 3),
                            Text('$_likeCount',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: _liked ? AppColors.coral : AppColors.muted,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      if (!widget.isReply) ...[
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => widget.onReply(c.id, c.authorName ?? 'Teacher'),
                          child: const Row(
                            children: [
                              Icon(Icons.reply_rounded, size: 14, color: AppColors.muted),
                              SizedBox(width: 3),
                              Text('Reply',
                                  style: TextStyle(
                                      fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ],
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
