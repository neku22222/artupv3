import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models.dart';

// ── Network Image ─────────────────────────────────────────────────────────────
class AppNetworkImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;

  const AppNetworkImage({super.key, required this.url, this.width, this.height, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return Container(width: width, height: height, color: AppColors.border,
          child: const Icon(Icons.image_outlined, color: AppColors.muted));
    }
    return CachedNetworkImage(
      imageUrl: url, width: width, height: height, fit: fit,
      placeholder: (_, __) => Container(width: width, height: height, color: AppColors.border),
      errorWidget: (_, __, ___) => Container(width: width, height: height, color: AppColors.border,
          child: const Icon(Icons.broken_image_outlined, color: AppColors.muted)),
    );
  }
}

// ── Avatar ────────────────────────────────────────────────────────────────────
class UserAvatar extends StatelessWidget {
  final String url;
  final double size;
  final VoidCallback? onTap;

  const UserAvatar({super.key, required this.url, this.size = 40, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: url.isEmpty
            ? Container(width: size, height: size, color: AppColors.peachPale,
                child: Icon(Icons.person, color: AppColors.peach, size: size * 0.5))
            : AppNetworkImage(url: url, width: size, height: size),
      ),
    );
  }
}

// ── Post Card — fix #5: colored backdrop + avatar next to author ──────────────
class PostCard extends StatefulWidget {
  final PostModel post;
  final VoidCallback? onTap;
  final VoidCallback? onAuthorTap;
  final Future<void> Function(PostModel)? onLike;

  const PostCard({super.key, required this.post, this.onTap, this.onAuthorTap, this.onLike});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _loading = false;
  String _fmt(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    return GestureDetector(
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: Stack(fit: StackFit.expand, children: [
            // Artwork thumbnail
            AppNetworkImage(url: post.imageUrl),

            // Like badge — top right
            Positioned(
              top: 8, right: 8,
              child: GestureDetector(
                onTap: () async {
                  if (_loading || widget.onLike == null) return;
                  setState(() => _loading = true);
                  await widget.onLike!(post);
                  setState(() => _loading = false);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: post.isLiked
                        ? AppColors.peach.withOpacity(0.92)
                        : Colors.black.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(post.isLiked ? Icons.favorite : Icons.favorite_border,
                        color: Colors.white, size: 10),
                    const SizedBox(width: 3),
                    Text(_fmt(post.likesCount),
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),

            // Bottom overlay: strong gradient + colored backdrop chip
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xCC0A0604)],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(8, 24, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title with colored backdrop
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.peach.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        post.title,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 10,
                            fontWeight: FontWeight.w700, height: 1.2),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 5),
                    // Author row: avatar + handle with dark backdrop
                    if (post.authorHandle != null)
                      GestureDetector(
                        onTap: widget.onAuthorTap,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.45),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            // Author avatar
                            ClipOval(
                              child: post.authorAvatar != null && post.authorAvatar!.isNotEmpty
                                  ? AppNetworkImage(url: post.authorAvatar!, width: 14, height: 14)
                                  : Container(width: 14, height: 14, color: AppColors.peachPale,
                                      child: const Icon(Icons.person, color: AppColors.peach, size: 9)),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '@${post.authorHandle}',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 9, fontWeight: FontWeight.w500),
                            ),
                          ]),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Search Bar ────────────────────────────────────────────────────────────────
class AppSearchBar extends StatelessWidget {
  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmit;

  const AppSearchBar({super.key, required this.hint, this.controller, this.onChanged, this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        const Icon(Icons.search, color: AppColors.muted, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: controller, onChanged: onChanged,
            onSubmitted: onSubmit != null ? (_) => onSubmit!() : null,
            style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.dark),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.dmSans(fontSize: 14, color: AppColors.muted),
              border: InputBorder.none, isDense: true,
              contentPadding: EdgeInsets.zero, filled: false,
            ),
          ),
        ),
        if (controller != null && controller!.text.isNotEmpty)
          GestureDetector(
            onTap: () { controller!.clear(); onChanged?.call(''); },
            child: const Icon(Icons.close, color: AppColors.muted, size: 14),
          ),
      ]),
    );
  }
}

// ── Filter Chip ───────────────────────────────────────────────────────────────
class AppFilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const AppFilterChip({super.key, required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.peach : AppColors.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? AppColors.peach : AppColors.border, width: 1.5),
        ),
        child: Text(label,
            style: GoogleFonts.dmSans(
                fontSize: 12, fontWeight: FontWeight.w500,
                color: isActive ? Colors.white : AppColors.muted)),
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({super.key, required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(title, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.dark)),
        if (actionLabel != null)
          GestureDetector(onTap: onAction,
              child: Text(actionLabel!, style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.peach, fontWeight: FontWeight.w500))),
      ]),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────
class EmptyState extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;

  const EmptyState({super.key, required this.emoji, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(title, style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.dark),
              textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(subtitle, style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.muted),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

// ── Gradient Button ───────────────────────────────────────────────────────────
class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  const GradientButton({super.key, required this.label, this.onPressed, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.peach, AppColors.amber]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: AppColors.peach.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 6))],
        ),
        child: ElevatedButton(
          onPressed: loading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: loading
              ? const SizedBox(height: 20, width: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(label, style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
      ),
    );
  }
}
