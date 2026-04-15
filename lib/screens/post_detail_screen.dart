import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cached_network_image/cached_network_image.dart';
import '../models.dart';
import '../services/supabase_service.dart';
import '../widgets/common_widgets.dart';
import '../theme/app_theme.dart';
import 'profile_screen.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;
  const PostDetailScreen({super.key, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  PostModel? _post;
  List<CommentModel> _comments = [];
  bool _loading = true;
  bool _likeLoading = false;
  final _commentCtrl = TextEditingController();
  bool _sendingComment = false;

  // Image viewer state
  final _pageCtrl = PageController();
  int _currentImageIndex = 0;

  // Resolved natural dimensions for each image so we can compute max height
  final Map<String, Size> _imageSizes = {};
  bool _sizesResolved = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        postService.getPost(widget.postId),
        commentService.getComments(widget.postId),
      ]);
      if (mounted) {
        setState(() {
          _post     = results[0] as PostModel?;
          _comments = results[1] as List<CommentModel>;
          _loading  = false;
        });
        if (_post != null) _resolveImageSizes(_post!.imageUrls);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Resolve natural sizes of all images so we can set a unified height ──
  Future<void> _resolveImageSizes(List<String> urls) async {
    for (final url in urls) {
      if (_imageSizes.containsKey(url)) continue;
      try {
        final completer = Completer<ui.Image>();
        final imageProvider = NetworkImage(url);
        final stream = imageProvider.resolve(ImageConfiguration.empty);
        stream.addListener(ImageStreamListener((info, _) {
          if (!completer.isCompleted) {
            completer.complete(info.image);
          }
        }, onError: (_, __) {
          if (!completer.isCompleted) {
            completer.completeError('failed');
          }
        }));
        final img = await completer.future;
        if (mounted) {
          setState(() => _imageSizes[url] = Size(
              img.width.toDouble(), img.height.toDouble()));
        }
      } catch (_) {
        if (mounted) {
          setState(() => _imageSizes[url] = const Size(1, 1));
        }
      }
    }
    if (mounted) setState(() => _sizesResolved = true);
  }

  // Returns the height the viewer frame should use:
  // = height of the tallest image when rendered at screen width,
  //   capped at 80% of screen height
  double _resolvedViewerHeight(List<String> urls) {
    if (_imageSizes.isEmpty) return 300;
    final screenW = MediaQuery.of(context).size.width;
    final maxScreenH = MediaQuery.of(context).size.height * 0.80;

    double maxH = 0;
    for (final url in urls) {
      final size = _imageSizes[url];
      if (size == null || size.width == 0) continue;
      final aspect = size.width / size.height;
      final renderedH = screenW / aspect;
      if (renderedH > maxH) maxH = renderedH;
    }
    return maxH.clamp(180.0, maxScreenH);
  }

  Future<void> _toggleLike() async {
    if (_post == null || _likeLoading) return;
    final wasLiked = _post!.isLiked;
    setState(() {
      _likeLoading = true;
      _post!.isLiked = !wasLiked;
      _post!.likesCount += wasLiked ? -1 : 1;
    });
    try {
      if (wasLiked) await postService.unlikePost(_post!.id);
      else await postService.likePost(_post!.id);
    } catch (_) {
      setState(() {
        _post!.isLiked = wasLiked;
        _post!.likesCount += wasLiked ? 1 : -1;
      });
    } finally {
      if (mounted) setState(() => _likeLoading = false);
    }
  }

  Future<void> _sendComment() async {
    final body = _commentCtrl.text.trim();
    if (body.isEmpty || _sendingComment) return;
    setState(() => _sendingComment = true);
    try {
      final comment = await commentService.addComment(widget.postId, body);
      _commentCtrl.clear();
      if (mounted) setState(() => _comments.add(comment));
    } catch (_) {} finally {
      if (mounted) setState(() => _sendingComment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.warmWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.dark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Post',
            style: GoogleFonts.dmSans(
                fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.dark)),
        actions: [
          if (_post != null && _post!.authorId == authService.currentUserId)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.errorRed),
              onPressed: _confirmDeletePost,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.peach))
          : _post == null
              ? const EmptyState(
                  emoji: '😕', title: 'Post not found',
                  subtitle: 'It may have been deleted')
              : Column(children: [
                  Expanded(child: _buildBody()),
                  _buildCommentInput(),
                ]),
    );
  }

  Widget _buildBody() {
    final post = _post!;
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Image viewer ────────────────────────────────────────────────
        _buildImageViewer(post.imageUrls),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Author row
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ProfileScreen(userId: post.authorId))),
              child: Row(children: [
                UserAvatar(url: post.authorAvatar ?? '', size: 36),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(post.authorName ?? post.authorHandle ?? '',
                      style: GoogleFonts.dmSans(
                          fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.dark)),
                  Text('@${post.authorHandle ?? ''}',
                      style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted)),
                ]),
                const Spacer(),
                Text(timeago.format(post.createdAt),
                    style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted)),
              ]),
            ),
            const SizedBox(height: 14),

            Text(post.title,
                style: GoogleFonts.playfairDisplay(
                    fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.dark)),
            const SizedBox(height: 6),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.peachPale,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.peachLight),
              ),
              child: Text(post.category,
                  style: GoogleFonts.dmSans(
                      fontSize: 11, color: AppColors.brown, fontWeight: FontWeight.w500)),
            ),
            const SizedBox(height: 10),

            if (post.description.isNotEmpty) ...[
              Text(post.description,
                  style: GoogleFonts.dmSans(
                      fontSize: 14, color: AppColors.muted, height: 1.6)),
              const SizedBox(height: 10),
            ],

            if (post.tags.isNotEmpty)
              Wrap(spacing: 6, runSpacing: 6,
                  children: post.tags.map((t) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.peachPale,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(t, style: GoogleFonts.dmSans(
                        fontSize: 11, color: AppColors.peach)),
                  )).toList()),
            const SizedBox(height: 16),

            // Like / comment row
            Row(children: [
              GestureDetector(
                onTap: _toggleLike,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                    color: post.isLiked ? AppColors.peach : AppColors.cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: post.isLiked ? AppColors.peach : AppColors.border,
                        width: 1.5),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(post.isLiked ? Icons.favorite : Icons.favorite_border,
                        color: post.isLiked ? Colors.white : AppColors.muted, size: 16),
                    const SizedBox(width: 6),
                    Text('${post.likesCount}',
                        style: GoogleFonts.dmSans(
                            fontSize: 13, fontWeight: FontWeight.w600,
                            color: post.isLiked ? Colors.white : AppColors.muted)),
                  ]),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border, width: 1.5),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.chat_bubble_outline, color: AppColors.muted, size: 16),
                  const SizedBox(width: 6),
                  Text('${_comments.length}',
                      style: GoogleFonts.dmSans(
                          fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.muted)),
                ]),
              ),
            ]),

            const SizedBox(height: 20),
            const Divider(color: AppColors.border),
            const SizedBox(height: 10),

            Text('Comments', style: GoogleFonts.dmSans(
                fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.dark)),
            const SizedBox(height: 12),

            if (_comments.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('No comments yet. Be the first!',
                    style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.muted)),
              )
            else
              ..._comments.map((c) => _CommentTile(
                    comment: c,
                    isOwn: c.authorId == authService.currentUserId,
                    onEdit: (newBody) {
                      setState(() => c.body = newBody);
                      commentService.editComment(c.id, newBody);
                    },
                    onDelete: () {
                      setState(() => _comments.remove(c));
                      commentService.deleteComment(c.id);
                    },
                  )),

            const SizedBox(height: 80),
          ]),
        ),
      ]),
    );
  }

  // ── Fix #9: dynamic height image viewer ─────────────────────────────────
  Widget _buildImageViewer(List<String> urls) {
    final isMulti = urls.length > 1;

    // While we haven't resolved sizes yet, show a shimmer placeholder
    if (isMulti && !_sizesResolved) {
      return Container(height: 300, color: AppColors.border,
          child: const Center(child: CircularProgressIndicator(
              color: AppColors.peach, strokeWidth: 2)));
    }

    final frameHeight = isMulti
        ? _resolvedViewerHeight(urls)
        : null; // single image: unconstrained (BoxFit.contain handles it)

    return Stack(
      children: [
        // The actual image(s)
        SizedBox(
          height: frameHeight,
          width: double.infinity,
          child: isMulti
              ? PageView.builder(
                  controller: _pageCtrl,
                  itemCount: urls.length,
                  onPageChanged: (i) => setState(() => _currentImageIndex = i),
                  itemBuilder: (_, i) => CachedNetworkImage(
                    imageUrl: urls[i],
                    fit: BoxFit.contain,
                    width: double.infinity,
                    placeholder: (_, __) => Container(color: AppColors.border),
                    errorWidget: (_, __, ___) => Container(color: AppColors.border,
                        child: const Icon(Icons.broken_image_outlined, color: AppColors.muted)),
                  ),
                )
              : CachedNetworkImage(
                  imageUrl: urls.first,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  placeholder: (_, __) => Container(height: 300, color: AppColors.border),
                  errorWidget: (_, __, ___) => Container(height: 300,
                      color: AppColors.border,
                      child: const Icon(Icons.broken_image_outlined, color: AppColors.muted)),
                ),
        ),

        // ── Counter badge: "2 / 5" top-right, only for multi-image ──────
        if (isMulti)
          Positioned(
            top: 12, right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_currentImageIndex + 1} / ${urls.length}',
                style: const TextStyle(
                    color: Colors.white, fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),

        // ── Left / Right chevron hints ───────────────────────────────────
        if (isMulti && _currentImageIndex > 0)
          Positioned(
            left: 8, top: 0, bottom: 0,
            child: Center(
              child: GestureDetector(
                onTap: () => _pageCtrl.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut),
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.35),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chevron_left, color: Colors.white, size: 20),
                ),
              ),
            ),
          ),
        if (isMulti && _currentImageIndex < urls.length - 1)
          Positioned(
            right: 8, top: 0, bottom: 0,
            child: Center(
              child: GestureDetector(
                onTap: () => _pageCtrl.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut),
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.35),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chevron_right, color: Colors.white, size: 20),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: EdgeInsets.only(
          left: 16, right: 12, top: 10,
          bottom: MediaQuery.of(context).viewInsets.bottom + 10),
      decoration: const BoxDecoration(
        color: AppColors.warmWhite,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _commentCtrl,
            style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.dark),
            decoration: const InputDecoration(
              hintText: 'Add a comment…',
              border: InputBorder.none, isDense: true,
              contentPadding: EdgeInsets.zero, filled: false,
            ),
            maxLines: null,
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _sendComment,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 36, height: 36,
            decoration: const BoxDecoration(
                color: AppColors.peach, shape: BoxShape.circle),
            child: _sendingComment
                ? const Padding(padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
          ),
        ),
      ]),
    );
  }

  Future<void> _confirmDeletePost() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: AppColors.errorRed))),
        ],
      ),
    );
    if (ok == true) {
      await postService.deletePost(widget.postId);
      if (mounted) Navigator.of(context).pop();
    }
  }
}

// ── Comment tile ──────────────────────────────────────────────────────────────

class _CommentTile extends StatefulWidget {
  final CommentModel comment;
  final bool isOwn;
  final void Function(String) onEdit;
  final VoidCallback onDelete;

  const _CommentTile({
    required this.comment, required this.isOwn,
    required this.onEdit, required this.onDelete,
  });

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile> {
  bool _editing = false;
  late final TextEditingController _editCtrl =
      TextEditingController(text: widget.comment.body);

  @override
  void dispose() { _editCtrl.dispose(); super.dispose(); }

  void _save() {
    final text = _editCtrl.text.trim();
    if (text.isNotEmpty) widget.onEdit(text);
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.comment;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        UserAvatar(url: c.authorAvatar ?? '', size: 30),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('@${c.authorHandle ?? 'user'}',
                style: GoogleFonts.dmSans(
                    fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.dark)),
            const SizedBox(width: 8),
            Text(timeago.format(c.createdAt),
                style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.muted)),
            if (widget.isOwn) ...[
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _editing = !_editing),
                child: const Icon(Icons.edit_outlined, size: 14, color: AppColors.muted),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _confirmDelete(context),
                child: const Icon(Icons.delete_outline, size: 14, color: AppColors.errorRed),
              ),
            ],
          ]),
          const SizedBox(height: 3),
          if (_editing)
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _editCtrl, autofocus: true,
                  style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.dark),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.peach),
                    ),
                    filled: false,
                  ),
                  onSubmitted: (_) => _save(),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _save,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                      color: AppColors.peach, shape: BoxShape.circle),
                  child: const Icon(Icons.check, color: Colors.white, size: 14),
                ),
              ),
            ])
          else
            Text(c.body, style: GoogleFonts.dmSans(
                fontSize: 13, color: AppColors.muted, height: 1.5)),
        ])),
      ]),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete comment?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: AppColors.errorRed))),
        ],
      ),
    );
    if (ok == true) widget.onDelete();
  }
}

// Dart async helper
class Completer<T> {
  late T _value;
  late Object _error;
  bool _isCompleted = false;
  bool _isError = false;

  Future<T> get future async {
    while (!_isCompleted && !_isError) {
      await Future.delayed(const Duration(milliseconds: 10));
    }
    if (_isError) throw _error;
    return _value;
  }

  void complete(T value) {
    if (_isCompleted || _isError) return;
    _value = value;
    _isCompleted = true;
  }

  void completeError(Object error) {
    if (_isCompleted || _isError) return;
    _error = error;
    _isError = true;
  }

  bool get isCompleted => _isCompleted || _isError;
}
