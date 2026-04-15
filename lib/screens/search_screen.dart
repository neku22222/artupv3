import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models.dart';
import '../services/supabase_service.dart';
import '../widgets/common_widgets.dart';
import '../theme/app_theme.dart';
import 'post_detail_screen.dart';
import 'profile_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  final _ctrl = TextEditingController();
  List<PostModel> _posts = [];
  List<ProfileModel> _profiles = [];
  bool _loading = false;
  bool _searched = false;

  final List<String> _categories = [
    'All', '2D', '3D', 'Photography', 'Sketch', 'Digital', 'Oil Paint'
  ];
  int _activeFilter = 0;

  // ── Fix #6: each tag card holds its top-post image URL ──────────────────
  static const List<String> _tags = [
    '#Renaissance', '#Landscape', '#WaterColour',
    '#Architecture', '#Sketch', '#Portrait',
  ];
  final Map<String, String> _tagImages = {};
  bool _tagImagesLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadTagImages();
  }

  Future<void> _loadTagImages() async {
    final Map<String, String> loaded = {};
    await Future.wait(_tags.map((tag) async {
      try {
        final post = await postService.getTopPostForTag(tag);
        if (post != null) loaded[tag] = post.imageUrl;
      } catch (_) {}
    }));
    if (mounted) setState(() { _tagImages.addAll(loaded); _tagImagesLoaded = true; });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      setState(() { _posts = []; _profiles = []; _searched = false; });
      return;
    }
    setState(() { _loading = true; _searched = true; });
    try {
      final results = await Future.wait([
        postService.searchPosts(query),
        profileService.searchProfiles(query),
      ]);
      if (mounted) setState(() {
        _posts    = results[0] as List<PostModel>;
        _profiles = results[1] as List<ProfileModel>;
        _loading  = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _searchByTag(String tag) async {
    setState(() { _loading = true; _searched = true; _ctrl.text = tag; });
    try {
      final posts = await postService.searchByTag(tag);
      if (mounted) setState(() { _posts = posts; _profiles = []; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: AppSearchBar(
          hint: 'Search artists, styles, tags…',
          controller: _ctrl,
          onChanged: (v) {
            setState(() {});
            if (v.isEmpty) _search('');
          },
          onSubmit: () => _search(_ctrl.text.trim()),
        ),
      ),

      if (!_searched) ...[
        // Category chips
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => AppFilterChip(
              label: _categories[i],
              isActive: _activeFilter == i,
              onTap: () {
                setState(() => _activeFilter = i);
                if (i == 0) _search('');
                else _searchByTag('#${_categories[i]}');
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text('TRENDING TAGS',
              style: GoogleFonts.dmSans(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  color: AppColors.muted, letterSpacing: 1)),
        ),
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            childAspectRatio: 1,
            children: _tags.map((tag) {
              final imgUrl = _tagImages[tag] ?? '';
              return _TagCard(
                tag: tag,
                imageUrl: imgUrl,
                onTap: () => _searchByTag(tag),
              );
            }).toList(),
          ),
        ),
      ] else ...[
        Container(
          color: AppColors.warmWhite,
          child: TabBar(
            controller: _tabs,
            labelColor: AppColors.peach,
            unselectedLabelColor: AppColors.muted,
            indicatorColor: AppColors.peach,
            labelStyle: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600),
            tabs: [
              Tab(text: 'Artworks (${_posts.length})'),
              Tab(text: 'Artists (${_profiles.length})'),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.peach))
              : TabBarView(controller: _tabs, children: [
                  _PostResults(posts: _posts),
                  _ProfileResults(profiles: _profiles),
                ]),
        ),
      ],
    ]);
  }
}

// ── Fix #6: tag card shows real top-post image ────────────────────────────────
class _TagCard extends StatelessWidget {
  final String tag;
  final String imageUrl;
  final VoidCallback onTap;

  static const List<Color> _fallbackColors = [
    Color(0xFF7B4F3A), Color(0xFF3A6B4F), Color(0xFF3A4F7B),
    Color(0xFF5A5A5A), Color(0xFF6B3A7B), Color(0xFF7B6B3A),
  ];

  const _TagCard({required this.tag, required this.imageUrl, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fallback = _fallbackColors[tag.length % _fallbackColors.length];

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(fit: StackFit.expand, children: [
          // Real image if available, fallback color otherwise
          if (imageUrl.isNotEmpty)
            AppNetworkImage(url: imageUrl, fit: BoxFit.cover)
          else
            Container(color: fallback),

          // Dark scrim so tag text is always readable
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.6)],
              ),
            ),
          ),

          // Tag label
          Positioned(
            bottom: 10, left: 10, right: 10,
            child: Text(tag,
                style: GoogleFonts.dmSans(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ),
        ]),
      ),
    );
  }
}

class _PostResults extends StatelessWidget {
  final List<PostModel> posts;
  const _PostResults({required this.posts});

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return const EmptyState(
          emoji: '🔍',
          title: 'No artworks found',
          subtitle: 'Try a different search term or tag');
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, crossAxisSpacing: 8,
        mainAxisSpacing: 8, childAspectRatio: 4 / 3,
      ),
      itemCount: posts.length,
      itemBuilder: (_, i) => PostCard(
        post: posts[i],
        onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => PostDetailScreen(postId: posts[i].id))),
        onAuthorTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ProfileScreen(userId: posts[i].authorId))),
      ),
    );
  }
}

class _ProfileResults extends StatelessWidget {
  final List<ProfileModel> profiles;
  const _ProfileResults({required this.profiles});

  @override
  Widget build(BuildContext context) {
    if (profiles.isEmpty) {
      return const EmptyState(
          emoji: '👤',
          title: 'No artists found',
          subtitle: 'Try searching by handle or name');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: profiles.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: AppColors.border),
      itemBuilder: (_, i) {
        final p = profiles[i];
        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
          leading: UserAvatar(url: p.avatarUrl, size: 44),
          title: Text(
              p.fullName.isNotEmpty ? p.fullName : p.handle,
              style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.dark)),
          subtitle: Text('@${p.handle}',
              style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted)),
          trailing: Text('${p.postsCount} works',
              style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted)),
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ProfileScreen(userId: p.id))),
        );
      },
    );
  }
}
