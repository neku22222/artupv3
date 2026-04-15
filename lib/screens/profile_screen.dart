import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../models.dart';
import '../services/supabase_service.dart';
import '../widgets/common_widgets.dart';
import '../theme/app_theme.dart';
import 'post_detail_screen.dart';
import 'dm_screen.dart';
import 'followers_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;
  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  ProfileModel? _profile;
  List<PostModel> _posts = [];
  bool _loading = true;
  bool _isFollowing = false;
  bool _followLoading = false;
  bool get _isOwnProfile => authService.currentUserId == widget.userId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        profileService.getProfile(widget.userId),
        postService.getPostsByAuthor(widget.userId),
        if (!_isOwnProfile) profileService.isFollowing(widget.userId),
      ]);
      if (mounted) setState(() {
        _profile     = results[0] as ProfileModel?;
        _posts       = results[1] as List<PostModel>;
        _isFollowing = _isOwnProfile ? false : (results.length > 2 ? results[2] as bool : false);
        _loading     = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Fix #4: optimistic counter update ────────────────────────────────────
  Future<void> _toggleFollow() async {
    if (_followLoading || _profile == null) return;
    setState(() {
      _followLoading = true;
      if (_isFollowing) {
        _isFollowing = false;
        _profile!.followersCount = (_profile!.followersCount - 1).clamp(0, 999999);
      } else {
        _isFollowing = true;
        _profile!.followersCount += 1;
      }
    });
    try {
      if (!_isFollowing) {
        // we already flipped to false above, so if it's now false we just unfollowed
        await profileService.unfollow(widget.userId);
      } else {
        await profileService.follow(widget.userId);
      }
    } catch (_) {
      // revert on error
      setState(() {
        if (_isFollowing) {
          _isFollowing = false;
          _profile!.followersCount = (_profile!.followersCount - 1).clamp(0, 999999);
        } else {
          _isFollowing = true;
          _profile!.followersCount += 1;
        }
      });
    } finally {
      if (mounted) setState(() => _followLoading = false);
    }
  }

  Future<void> _openDM() async {
    if (_profile == null) return;
    final convo = await dmService.getOrCreateConversation(widget.userId);
    if (mounted) {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ChatScreen(conversation: convo, otherProfile: _profile!)));
    }
  }

  // ── Fix #7: change profile picture ───────────────────────────────────────
  Future<void> _changeAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null || !mounted) return;

    final file = File(picked.path);
    final uid  = authService.currentUserId!;

    // Optimistic UI: show local file immediately
    final localUrl = picked.path;
    setState(() => _profile!.avatarUrl = localUrl);

    try {
      final url = await storageService.uploadAvatar(file, uid);
      await profileService.updateProfile(userId: uid, avatarUrl: url);
      if (mounted) setState(() => _profile!.avatarUrl = url);
    } catch (_) {
      // revert
      if (mounted) _load();
    }
  }

  // ── Stat column — tappable for own profile (followers + following) or
  //    only following when viewing someone else ──────────────────────────────
  void _onStatTap(String type) {
    if (_profile == null) return;
    final uid = _profile!.id;
    final handle = _profile!.handle;

    if (type == 'followers' && _isOwnProfile) {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => FollowListScreen(
              userId: uid, type: FollowListType.followers, handle: handle)));
    } else if (type == 'following') {
      // both own + others can view following
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => FollowListScreen(
              userId: uid, type: FollowListType.following, handle: handle)));
    }
    // posts count — no action needed
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.peach))
          : _profile == null
              ? const EmptyState(emoji: '😕', title: 'User not found', subtitle: '')
              : CustomScrollView(slivers: [
                  _buildAppBar(),
                  SliverToBoxAdapter(child: _buildProfileInfo()),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    sliver: _posts.isEmpty
                        ? const SliverToBoxAdapter(
                            child: EmptyState(
                                emoji: '🎨',
                                title: 'No posts yet',
                                subtitle: 'This artist hasn\'t posted anything yet'))
                        : SliverGrid(
                            delegate: SliverChildBuilderDelegate(
                              (_, i) => PostCard(
                                post: _posts[i],
                                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) => PostDetailScreen(postId: _posts[i].id))),
                              ),
                              childCount: _posts.length,
                            ),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2, crossAxisSpacing: 8,
                              mainAxisSpacing: 8, childAspectRatio: 4 / 3,
                            ),
                          ),
                  ),
                ]),
    );
  }

  SliverAppBar _buildAppBar() => SliverAppBar(
        backgroundColor: AppColors.warmWhite,
        elevation: 0,
        pinned: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.dark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('@${_profile!.handle}',
            style: GoogleFonts.dmSans(
                fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.dark)),
      );

  Widget _buildProfileInfo() {
    final p = _profile!;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          // Avatar — tappable only on own profile
          Stack(
            children: [
              UserAvatar(url: p.avatarUrl, size: 72,
                  onTap: _isOwnProfile ? _changeAvatar : null),
              if (_isOwnProfile)
                Positioned(
                  bottom: 0, right: 0,
                  child: GestureDetector(
                    onTap: _changeAvatar,
                    child: Container(
                      width: 22, height: 22,
                      decoration: const BoxDecoration(
                          color: AppColors.peach, shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 12),
                    ),
                  ),
                ),
            ],
          ),
          const Spacer(),
          // Tappable stat columns
          _statCol('${p.postsCount}', 'Posts', null),
          const SizedBox(width: 20),
          _statCol(
            '${p.followersCount}',
            'Followers',
            _isOwnProfile ? () => _onStatTap('followers') : null,
          ),
          const SizedBox(width: 20),
          _statCol(
            '${p.followingCount}',
            'Following',
            () => _onStatTap('following'),
          ),
        ]),
        const SizedBox(height: 14),
        if (p.fullName.isNotEmpty)
          Text(p.fullName,
              style: GoogleFonts.dmSans(
                  fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.dark)),
        Text('@${p.handle}',
            style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.muted)),
        if (p.bio.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(p.bio,
              style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.dark, height: 1.5)),
        ],
        if (p.website.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(p.website,
              style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.peach)),
        ],
        const SizedBox(height: 14),

        // Action buttons
        if (_isOwnProfile)
          OutlinedButton(
            onPressed: () => _showEditProfile(context),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.border, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              minimumSize: const Size(double.infinity, 38),
            ),
            child: Text('Edit Profile',
                style: GoogleFonts.dmSans(
                    fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.dark)),
          )
        else
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: _followLoading ? null : _toggleFollow,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _isFollowing ? AppColors.cardBg : AppColors.peach,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: _isFollowing ? AppColors.border : AppColors.peach,
                        width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: _followLoading
                      ? const SizedBox(
                          height: 16, width: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.peach))
                      : Text(
                          _isFollowing ? 'Following' : 'Follow',
                          style: GoogleFonts.dmSans(
                              fontSize: 13, fontWeight: FontWeight.w600,
                              color: _isFollowing ? AppColors.dark : Colors.white),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _openDM,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border, width: 1.5),
                ),
                child: const Icon(Icons.chat_bubble_outline,
                    color: AppColors.dark, size: 18),
              ),
            ),
          ]),

        const SizedBox(height: 16),
        const Divider(color: AppColors.border),
      ]),
    );
  }

  Widget _statCol(String value, String label, VoidCallback? onTap) {
    final tappable = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Text(value,
            style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: tappable ? AppColors.peach : AppColors.dark)),
        Text(label,
            style: GoogleFonts.dmSans(
                fontSize: 11,
                color: tappable ? AppColors.peach : AppColors.muted,
                decoration: tappable ? TextDecoration.underline : null)),
      ]),
    );
  }

  void _showEditProfile(BuildContext context) {
    final nameCtrl    = TextEditingController(text: _profile!.fullName);
    final bioCtrl     = TextEditingController(text: _profile!.bio);
    final websiteCtrl = TextEditingController(text: _profile!.website);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Edit Profile',
                  style: GoogleFonts.dmSans(
                      fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.dark)),
              const SizedBox(height: 16),
              TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Full Name'),
                  style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.dark)),
              const SizedBox(height: 12),
              TextField(
                  controller: bioCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Bio'),
                  style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.dark)),
              const SizedBox(height: 12),
              TextField(
                  controller: websiteCtrl,
                  decoration: const InputDecoration(labelText: 'Website'),
                  style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.dark)),
              const SizedBox(height: 20),
              GradientButton(
                label: 'Save Changes',
                onPressed: () async {
                  await profileService.updateProfile(
                    userId: widget.userId,
                    fullName: nameCtrl.text.trim(),
                    bio: bioCtrl.text.trim(),
                    website: websiteCtrl.text.trim(),
                  );
                  if (mounted) {
                    Navigator.of(context).pop();
                    _load();
                  }
                },
              ),
            ]),
      ),
    );
  }
}
