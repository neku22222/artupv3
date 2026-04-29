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
  List<ProfileModel> _suggestedUsers = [];
  bool _loading = true;
  bool _loadingMore = false;
  int _offset = 0;
  static const int _pageSize = 20;
  bool _hasMore = true;

  // Track dismissed suggestions so they don't reappear
  final Set<String> _dismissedSuggestions = {};

  final ScrollController _scrollCtrl = ScrollController();

  // Every N post-grid-rows, we insert a suggestion strip.
  // With 2 columns, every 4 posts = 2 rows between suggestion cards.
  static const int _suggestionEveryNPosts = 6;

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
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _offset = 0;
      _hasMore = true;
    });
    try {
      final results = await Future.wait([
        postService.getFeed(limit: _pageSize, offset: 0),
        _fetchSuggestedUsers(),
      ]);
      if (mounted) {
        setState(() {
          _posts = results[0] as List<PostModel>;
          _suggestedUsers = results[1] as List<ProfileModel>;
          _offset = _posts.length;
          _hasMore = _posts.length == _pageSize;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<ProfileModel>> _fetchSuggestedUsers() async {
    try {
      // Search for profiles to suggest — you can swap this for a
      // dedicated "recommended" RPC if you add one later.
      // For now we pull recent profiles the current user doesn't follow.
      final profiles = await profileService.searchProfiles('');
      final myId = authService.currentUserId;
      return profiles.where((p) => p.id != myId).take(10).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final more =
      await postService.getFeed(limit: _pageSize, offset: _offset);
      if (mounted) {
        setState(() {
          _posts.addAll(more);
          _offset += more.length;
          _hasMore = more.length == _pageSize;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _onRefresh() => _loadInitial();

  Future<void> _likePost(PostModel post) async {
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
      setState(() {
        post.isLiked = wasLiked;
        post.likesCount += wasLiked ? 1 : -1;
      });
    }
  }

  void _dismissSuggestion(String userId) {
    setState(() => _dismissedSuggestions.add(userId));
  }

  // Build a flat list of "items" — either a pair of posts (for the 2-col grid)
  // or a suggestion strip inserted every N posts.
  List<_FeedItem> _buildFeedItems() {
    final items = <_FeedItem>[];
    final visible = _suggestedUsers
        .where((u) => !_dismissedSuggestions.contains(u.id))
        .toList();

    int postIndex = 0;
    int suggestionBatchIndex = 0;

    while (postIndex < _posts.length) {
      // Add a chunk of posts before the next suggestion
      final chunkEnd =
      (postIndex + _suggestionEveryNPosts).clamp(0, _posts.length);
      items.add(_FeedItem.postChunk(_posts.sublist(postIndex, chunkEnd)));
      postIndex = chunkEnd;

      // After each chunk, insert a suggestion strip if we still have suggestions
      if (visible.isNotEmpty && postIndex < _posts.length) {
        // Cycle through suggestion batches of 3
        final start = (suggestionBatchIndex * 3) % visible.length;
        final end = (start + 3).clamp(0, visible.length);
        final batch = visible.sublist(start, end);
        if (batch.isNotEmpty) {
          items.add(_FeedItem.suggestion(batch));
          suggestionBatchIndex++;
        }
      }
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.peach));
    }

    if (_posts.isEmpty) {
      return RefreshIndicator(
        color: AppColors.peach,
        onRefresh: _onRefresh,
        child: ListView(
          children: const [
            SizedBox(height: 80),
            EmptyState(
                emoji: '🎨',
                title: 'No artwork yet',
                subtitle: 'Follow artists or upload your first post!'),
          ],
        ),
      );
    }

    final feedItems = _buildFeedItems();

    return RefreshIndicator(
      color: AppColors.peach,
      onRefresh: _onRefresh,
      child: CustomScrollView(
        controller: _scrollCtrl,
        slivers: [
          for (final item in feedItems)
            if (item.type == _FeedItemType.postChunk)
              _PostGridSliver(
                posts: item.posts!,
                onPostTap: (post) => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => PostDetailScreen(postId: post.id))),
                onAuthorTap: (post) => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) =>
                            ProfileScreen(userId: post.authorId))),
                onLike: (post) async => _likePost(post),
              )
            else
              SliverToBoxAdapter(
                child: _SuggestedAccountsStrip(
                  profiles: item.suggestions!,
                  onDismiss: _dismissSuggestion,
                  onTap: (profile) => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) =>
                              ProfileScreen(userId: profile.id))),
                ),
              ),

          // Loading more indicator
          if (_loadingMore)
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(
                      color: AppColors.peach, strokeWidth: 2),
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

// ── Feed item model ───────────────────────────────────────────────────────────

enum _FeedItemType { postChunk, suggestion }

class _FeedItem {
  final _FeedItemType type;
  final List<PostModel>? posts;
  final List<ProfileModel>? suggestions;

  const _FeedItem._({required this.type, this.posts, this.suggestions});

  factory _FeedItem.postChunk(List<PostModel> posts) =>
      _FeedItem._(type: _FeedItemType.postChunk, posts: posts);

  factory _FeedItem.suggestion(List<ProfileModel> profiles) =>
      _FeedItem._(type: _FeedItemType.suggestion, suggestions: profiles);
}

// ── Post grid sliver ──────────────────────────────────────────────────────────

class _PostGridSliver extends StatelessWidget {
  final List<PostModel> posts;
  final void Function(PostModel) onPostTap;
  final void Function(PostModel) onAuthorTap;
  final Future<void> Function(PostModel) onLike;

  const _PostGridSliver({
    required this.posts,
    required this.onPostTap,
    required this.onAuthorTap,
    required this.onLike,
  });

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
              (_, i) => PostCard(
            post: posts[i],
            onTap: () => onPostTap(posts[i]),
            onAuthorTap: () => onAuthorTap(posts[i]),
            onLike: (p) async => onLike(p),
          ),
          childCount: posts.length,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 4 / 3,
        ),
      ),
    );
  }
}

// ── Suggested accounts horizontal strip ───────────────────────────────────────

class _SuggestedAccountsStrip extends StatefulWidget {
  final List<ProfileModel> profiles;
  final void Function(String userId) onDismiss;
  final void Function(ProfileModel) onTap;

  const _SuggestedAccountsStrip({
    required this.profiles,
    required this.onDismiss,
    required this.onTap,
  });

  @override
  State<_SuggestedAccountsStrip> createState() =>
      _SuggestedAccountsStripState();
}

class _SuggestedAccountsStripState extends State<_SuggestedAccountsStrip> {
  // Track followed state locally within the strip
  final Set<String> _followedIds = {};
  final Set<String> _loadingIds = {};

  Future<void> _toggleFollow(ProfileModel profile) async {
    if (_loadingIds.contains(profile.id)) return;
    setState(() => _loadingIds.add(profile.id));
    final wasFollowed = _followedIds.contains(profile.id);
    setState(() {
      if (wasFollowed) {
        _followedIds.remove(profile.id);
      } else {
        _followedIds.add(profile.id);
      }
    });
    try {
      if (wasFollowed) {
        await profileService.unfollow(profile.id);
      } else {
        await profileService.follow(profile.id);
      }
    } catch (_) {
      // Revert
      setState(() {
        if (wasFollowed) {
          _followedIds.add(profile.id);
        } else {
          _followedIds.remove(profile.id);
        }
      });
    } finally {
      if (mounted) setState(() => _loadingIds.remove(profile.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding:
            const EdgeInsets.only(left: 14, right: 8, top: 12, bottom: 8),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome_rounded,
                    color: AppColors.peach, size: 14),
                const SizedBox(width: 6),
                Text(
                  'SUGGESTED FOR YOU',
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),

          // Horizontal scroll of artist cards
          SizedBox(
            height: 168,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
              itemCount: widget.profiles.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final profile = widget.profiles[i];
                final isFollowed = _followedIds.contains(profile.id);
                final isLoading = _loadingIds.contains(profile.id);

                return _SuggestedUserCard(
                  profile: profile,
                  isFollowed: isFollowed,
                  isLoading: isLoading,
                  onTap: () => widget.onTap(profile),
                  onFollow: () => _toggleFollow(profile),
                  onDismiss: () => widget.onDismiss(profile.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Individual suggested user card ────────────────────────────────────────────

class _SuggestedUserCard extends StatelessWidget {
  final ProfileModel profile;
  final bool isFollowed;
  final bool isLoading;
  final VoidCallback onTap;
  final VoidCallback onFollow;
  final VoidCallback onDismiss;

  const _SuggestedUserCard({
    required this.profile,
    required this.isFollowed,
    required this.isLoading,
    required this.onTap,
    required this.onFollow,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 110,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.warmWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Dismiss button
            Align(
              alignment: Alignment.topRight,
              child: GestureDetector(
                onTap: onDismiss,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Icon(Icons.close_rounded,
                      size: 13, color: AppColors.muted.withOpacity(0.6)),
                ),
              ),
            ),

            // Avatar
            UserAvatar(url: profile.avatarUrl, size: 44),
            const SizedBox(height: 6),

            // Name
            Text(
              profile.fullName.isNotEmpty ? profile.fullName : '@${profile.handle}',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.dark,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),

            // Handle
            Text(
              '@${profile.handle}',
              style: GoogleFonts.dmSans(fontSize: 9, color: AppColors.muted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 7),

            // Follow button
            GestureDetector(
              onTap: onFollow,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 5),
                decoration: BoxDecoration(
                  color: isFollowed ? AppColors.cardBg : AppColors.peach,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isFollowed ? AppColors.border : AppColors.peach,
                    width: 1.2,
                  ),
                ),
                alignment: Alignment.center,
                child: isLoading
                    ? SizedBox(
                  height: 12,
                  width: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: isFollowed
                        ? AppColors.peach
                        : Colors.white,
                  ),
                )
                    : Text(
                  isFollowed ? 'Following' : 'Follow',
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color:
                    isFollowed ? AppColors.muted : Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}