import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models.dart';
import '../services/supabase_service.dart';
import '../widgets/common_widgets.dart';
import '../theme/app_theme.dart';
import 'post_detail_screen.dart';
import 'profile_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationModel> _notifs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final notifs = await notificationService.getNotifications();
    if (mounted) setState(() { _notifs = notifs; _loading = false; });
    await notificationService.markAllRead();
  }

  /// Called after the user accepts/declines a link request so the tile refreshes
  void _onLinkRequestActioned(String notifId) {
    setState(() => _notifs.removeWhere((n) => n.id == notifId));
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
        title: Text('Notifications',
            style: GoogleFonts.dmSans(
                fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.dark)),
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: AppColors.border)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.peach))
          : RefreshIndicator(
        color: AppColors.peach,
        onRefresh: _load,
        child: _notifs.isEmpty
            ? ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 100),
            EmptyState(
                emoji: '🔔',
                title: 'No notifications yet',
                subtitle: 'When people like, follow or comment you\'ll see it here'),
          ],
        )
            : ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: _notifs.length,
          separatorBuilder: (_, __) =>
          const Divider(height: 1, color: AppColors.border, indent: 72),
          itemBuilder: (_, i) {
            final notif = _notifs[i];
            if (notif.type == 'link_request') {
              return _LinkRequestTile(
                notif: notif,
                onActioned: () => _onLinkRequestActioned(notif.id),
              );
            }
            return _NotifTile(notif: notif);
          },
        ),
      ),
    );
  }
}

// ── Standard notification tile ────────────────────────────────────────────────

class _NotifTile extends StatelessWidget {
  final NotificationModel notif;
  const _NotifTile({required this.notif});

  IconData get _icon {
    switch (notif.type) {
      case 'like':    return Icons.favorite;
      case 'follow':  return Icons.person_add;
      case 'comment': return Icons.chat_bubble;
      default:        return Icons.notifications;
    }
  }

  Color get _iconColor {
    switch (notif.type) {
      case 'like':    return AppColors.errorRed;
      case 'follow':  return AppColors.peach;
      case 'comment': return const Color(0xFF3A7BD5);
      default:        return AppColors.muted;
    }
  }

  String get _body {
    final handle = notif.actorHandle != null ? '@${notif.actorHandle}' : 'Someone';
    switch (notif.type) {
      case 'like':
        return '$handle liked your post';
      case 'follow':
        return '$handle followed you';
      case 'comment':
        final snippet = notif.commentBody != null && notif.commentBody!.isNotEmpty
            ? ': "${notif.commentBody!.length > 40 ? '${notif.commentBody!.substring(0, 40)}…' : notif.commentBody}"'
            : '';
        return '$handle commented$snippet';
      default:
        return '$handle interacted with your content';
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        if (notif.postId != null) {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => PostDetailScreen(postId: notif.postId!)));
        } else if (notif.type == 'follow') {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ProfileScreen(userId: notif.actorId)));
        }
      },
      child: Container(
        color: notif.isRead ? Colors.transparent : AppColors.peachPale.withOpacity(0.4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ProfileScreen(userId: notif.actorId))),
                child: UserAvatar(url: notif.actorAvatar ?? '', size: 44),
              ),
              Positioned(
                bottom: -2, right: -2,
                child: Container(
                  width: 18, height: 18,
                  decoration: BoxDecoration(
                      color: _iconColor, shape: BoxShape.circle,
                      border: Border.all(color: AppColors.cream, width: 1.5)),
                  child: Icon(_icon, color: Colors.white, size: 10),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_body,
                  style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: notif.isRead ? FontWeight.w400 : FontWeight.w600,
                      color: AppColors.dark)),
              const SizedBox(height: 2),
              Text(timeago.format(notif.createdAt),
                  style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted)),
            ]),
          ),
          if (notif.postImageUrl != null && notif.postImageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AppNetworkImage(
                  url: notif.postImageUrl!, width: 44, height: 44),
            ),
        ]),
      ),
    );
  }
}

// ── Link-request tile with Accept / Decline buttons ───────────────────────────

class _LinkRequestTile extends StatefulWidget {
  final NotificationModel notif;
  final VoidCallback onActioned;

  const _LinkRequestTile({required this.notif, required this.onActioned});

  @override
  State<_LinkRequestTile> createState() => _LinkRequestTileState();
}

class _LinkRequestTileState extends State<_LinkRequestTile> {
  bool _loading = false;

  Future<void> _accept() async {
    setState(() => _loading = true);
    try {
      final myId     = authService.currentUserId!;
      final actorId  = widget.notif.actorId;

      // Create a bidirectional link: actor → me AND me → actor
      final client = Supabase.instance.client;

      // Upsert both directions so duplicate inserts don't throw
      await client.from('linked_accounts').upsert(
        {'owner_id': actorId, 'linked_id': myId},
        onConflict: 'owner_id,linked_id',
      );
      await client.from('linked_accounts').upsert(
        {'owner_id': myId, 'linked_id': actorId},
        onConflict: 'owner_id,linked_id',
      );

      // Delete the pending notification
      await client.from('notifications').delete().eq('id', widget.notif.id);

      // Send an accepted notification back to the requester
      await client.from('notifications').insert({
        'recipient_id': actorId,
        'actor_id':     myId,
        'type':         'link_accepted',
        'is_read':      false,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Linked with @${widget.notif.actorHandle ?? 'user'} ✅'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        widget.onActioned();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to accept: ${e.toString()}'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  Future<void> _decline() async {
    setState(() => _loading = true);
    try {
      await Supabase.instance.client
          .from('notifications')
          .delete()
          .eq('id', widget.notif.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Request from @${widget.notif.actorHandle ?? 'user'} declined'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        widget.onActioned();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final handle = widget.notif.actorHandle != null
        ? '@${widget.notif.actorHandle}'
        : 'Someone';

    return Container(
      color: AppColors.peachPale.withOpacity(0.4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Avatar with chain-link badge
        Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ProfileScreen(userId: widget.notif.actorId))),
              child: UserAvatar(url: widget.notif.actorAvatar ?? '', size: 44),
            ),
            Positioned(
              bottom: -2, right: -2,
              child: Container(
                width: 18, height: 18,
                decoration: BoxDecoration(
                    color: AppColors.peach, shape: BoxShape.circle,
                    border: Border.all(color: AppColors.cream, width: 1.5)),
                child: const Icon(Icons.link, color: Colors.white, size: 10),
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              '$handle wants to link their account to yours',
              style: GoogleFonts.dmSans(
                  fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.dark),
            ),
            const SizedBox(height: 2),
            Text(
              'This will appear publicly on both profiles.',
              style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted),
            ),
            const SizedBox(height: 2),
            Text(timeago.format(widget.notif.createdAt),
                style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted)),
            const SizedBox(height: 10),
            if (_loading)
              const SizedBox(
                height: 24,
                child: Center(child: CircularProgressIndicator(
                    color: AppColors.peach, strokeWidth: 2)),
              )
            else
              Row(children: [
                // Accept button
                Expanded(
                  child: GestureDetector(
                    onTap: _accept,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.peach,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text('Accept',
                          style: GoogleFonts.dmSans(
                              fontSize: 12, fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Decline button
                Expanded(
                  child: GestureDetector(
                    onTap: _decline,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Text('Decline',
                          style: GoogleFonts.dmSans(
                              fontSize: 12, fontWeight: FontWeight.w700,
                              color: AppColors.muted)),
                    ),
                  ),
                ),
              ]),
          ]),
        ),
      ]),
    );
  }
}