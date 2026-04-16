import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models.dart';
import '../services/supabase_service.dart';
import '../widgets/common_widgets.dart';
import '../theme/app_theme.dart';
import 'post_detail_screen.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';

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
  static const int _pageSize = 20;
  bool _hasMore = true;

  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Infinite scroll: load more when near bottom
    if (_scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent - 200 &&
        !_loadingMore && _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadInitial() async {
    setState(() { _loading = true; _offset = 0; _hasMore = true; });
    try {
      final posts = await postService.getFeed(limit: _pageSize, offset: 0);
      if (mounted) setState(() {
        _posts   = posts;
        _offset  = posts.length;
        _hasMore = posts.length == _pageSize;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final more = await postService.getFeed(limit: _pageSize, offset: _offset);
      if (mounted) setState(() {
        _posts.addAll(more);
        _offset += more.length;
        _hasMore = more.length == _pageSize;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  /// Pull-to-refresh
  Future<void> _onRefresh() => _loadInitial();

  /// Like/unlike with optimistic update
  Future<void> _likePost(PostModel post) async {
    final wasLiked = post.isLiked;
    setState(() {
      post.isLiked = !wasLiked;
      post.likesCount += wasLiked ? -1 : 1;
    });
    try {
      if (wasLiked) await postService.unlikePost(post.id);
      else await postService.likePost(post.id);
    } catch (_) {
      setState(() {
        post.isLiked = wasLiked;
        post.likesCount += wasLiked ? 1 : -1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _loading
        ? const Center(child: CircularProgressIndicator(color: AppColors.peach))
        : RefreshIndicator(
            color: AppColors.peach,
            onRefresh: _onRefresh,
            child: _posts.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 80),
                      EmptyState(
                          emoji: '🎨',
                          title: 'No artwork yet',
                          subtitle: 'Follow artists or upload your first post!'),
                    ],
                  )
                : GridView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 4 / 3,
                    ),
                    itemCount: _posts.length + (_loadingMore ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == _posts.length) {
                        return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(
                                  color: AppColors.peach, strokeWidth: 2),
                            ));
                      }
                      final post = _posts[i];
                      return PostCard(
                        post: post,
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => PostDetailScreen(postId: post.id))),
                        onAuthorTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => ProfileScreen(userId: post.authorId))),
                        onLike: _likePost,
                      );
                    },
                  ),
          );
  }
}
