import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models.dart';
import '../services/supabase_service.dart';
import '../widgets/common_widgets.dart';
import '../theme/app_theme.dart';
import 'post_detail_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<PostModel> _posts = [];
  bool _loading = true;
  bool _loadingMore = false;
  int _offset = 0;
  static const _limit = 20;
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadFeed();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFeed({bool refresh = false}) async {
    if (refresh) setState(() { _posts = []; _offset = 0; _loading = true; });
    try {
      final posts = await postService.getFeed(limit: _limit, offset: refresh ? 0 : _offset);
      if (mounted) setState(() {
        _posts = refresh ? posts : [..._posts, ...posts];
        _offset = _posts.length;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _loadingMore = false; });
    }
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200
        && !_loadingMore && !_loading) {
      setState(() => _loadingMore = true);
      _loadFeed();
    }
  }

  Future<void> _handleLike(PostModel post) async {
    final wasLiked = post.isLiked;
    setState(() {
      post.isLiked = !wasLiked;
      post.likesCount += wasLiked ? -1 : 1;
    });
    try {
      if (wasLiked) {
        await postService.unlikePost(post.id);
      } else {
        await postService.likePost(post.id);
      }
    } catch (_) {
      // Revert on error
      setState(() {
        post.isLiked = wasLiked;
        post.likesCount += wasLiked ? 1 : -1;
      });
    }
  }

  void _openPost(PostModel post) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PostDetailScreen(postId: post.id)));
  }

  void _openProfile(String authorId) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ProfileScreen(userId: authorId)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.peach));

    if (_posts.isEmpty) {
      return const EmptyState(
        emoji: '🎨',
        title: 'No posts yet',
        subtitle: 'Be the first to share your artwork!',
      );
    }

    return RefreshIndicator(
      color: AppColors.peach,
      onRefresh: () => _loadFeed(refresh: true),
      child: CustomScrollView(
        controller: _scrollCtrl,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  if (i >= _posts.length) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.peach, strokeWidth: 2));
                  }
                  final post = _posts[i];
                  return PostCard(
                    post: post,
                    onTap: () => _openPost(post),
                    onAuthorTap: () => _openProfile(post.authorId),
                    onLike: _handleLike,
                  );
                },
                childCount: _loadingMore ? _posts.length + 1 : _posts.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, crossAxisSpacing: 8,
                mainAxisSpacing: 8, childAspectRatio: 4 / 3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
