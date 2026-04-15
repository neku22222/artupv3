import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models.dart';
import '../services/supabase_service.dart';
import '../widgets/common_widgets.dart';
import '../theme/app_theme.dart';
import 'profile_screen.dart';

enum FollowListType { followers, following }

class FollowListScreen extends StatefulWidget {
  final String userId;
  final FollowListType type;
  final String handle;

  const FollowListScreen({
    super.key,
    required this.userId,
    required this.type,
    required this.handle,
  });

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  List<ProfileModel> _profiles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = widget.type == FollowListType.followers
          ? await profileService.getFollowers(widget.userId)
          : await profileService.getFollowing(widget.userId);
      if (mounted) setState(() { _profiles = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.type == FollowListType.followers
        ? 'Followers of @${widget.handle}'
        : '@${widget.handle} follows';

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.warmWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.dark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(title,
            style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.dark)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.peach))
          : _profiles.isEmpty
              ? EmptyState(
                  emoji: '👥',
                  title: widget.type == FollowListType.followers ? 'No followers yet' : 'Not following anyone yet',
                  subtitle: '',
                )
              : ListView.separated(
                  itemCount: _profiles.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 76, color: AppColors.border),
                  itemBuilder: (_, i) {
                    final p = _profiles[i];
                    return ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: UserAvatar(url: p.avatarUrl, size: 46),
                      title: Text(
                        p.fullName.isNotEmpty ? p.fullName : '@${p.handle}',
                        style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.dark),
                      ),
                      subtitle: Text('@${p.handle}',
                          style: GoogleFonts.dmSans(
                              fontSize: 12, color: AppColors.muted)),
                      trailing: Text('${p.postsCount} works',
                          style: GoogleFonts.dmSans(
                              fontSize: 11, color: AppColors.muted)),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => ProfileScreen(userId: p.id)),
                      ),
                    );
                  },
                ),
    );
  }
}
