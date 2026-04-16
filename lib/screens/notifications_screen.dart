import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models.dart';
import '../services/supabase_service.dart';
import '../widgets/common_widgets.dart';
import '../theme/app_theme.dart';
import 'post_detail_screen.dart';
import 'profile_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Notifications screen
// Reads from the 'notifications' table (requires SQL migration below).
// Falls back gracefully if the table doesn't exist yet.
// ─────────────────────────────────────────────────────────────────────────────

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
    // Mark all read
    await notificationService.markAllRead();
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
          : _notifs.isEmpty
              ? const EmptyState(
                  emoji: '🔔',
                  title: 'No notifications yet',
                  subtitle: 'When people like, follow or comment you\'ll see it here')
              : RefreshIndicator(
                  color: AppColors.peach,
                  onRefresh: _load,
                  child: ListView.separated(
                    itemCount: _notifs.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AppColors.border, indent: 72),
                    itemBuilder: (_, i) => _NotifTile(notif: _notifs[i]),
                  ),
                ),
    );
  }
}

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
          // Actor avatar
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
          // Post thumbnail if applicable
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

// ─────────────────────────────────────────────────────────────────────────────
// SQL MIGRATION (run in Supabase SQL Editor):
// ─────────────────────────────────────────────────────────────────────────────
/*
CREATE TABLE IF NOT EXISTS public.notifications (
  id             uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
  recipient_id   uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  actor_id       uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  actor_handle   text,
  actor_avatar   text,
  type           text NOT NULL CHECK (type IN ('like', 'comment', 'follow')),
  post_id        uuid REFERENCES public.posts(id) ON DELETE CASCADE,
  post_image_url text,
  comment_body   text,
  is_read        boolean NOT NULL DEFAULT false,
  created_at     timestamptz DEFAULT now()
);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own notifications"
  ON public.notifications FOR SELECT USING (auth.uid() = recipient_id);

CREATE POLICY "Authenticated users can insert notifications"
  ON public.notifications FOR INSERT WITH CHECK (auth.uid() = actor_id);

CREATE POLICY "Users can mark own notifications read"
  ON public.notifications FOR UPDATE USING (auth.uid() = recipient_id);

-- Trigger: create like notification
CREATE OR REPLACE FUNCTION public.handle_like_notification()
RETURNS trigger AS $$
DECLARE
  v_post_author uuid;
  v_post_image  text;
  v_handle      text;
  v_avatar      text;
BEGIN
  SELECT author_id, image_url INTO v_post_author, v_post_image
    FROM public.posts WHERE id = NEW.post_id;
  SELECT handle, avatar_url INTO v_handle, v_avatar
    FROM public.profiles WHERE id = NEW.user_id;
  IF v_post_author IS DISTINCT FROM NEW.user_id THEN
    INSERT INTO public.notifications
      (recipient_id, actor_id, actor_handle, actor_avatar, type, post_id, post_image_url)
    VALUES
      (v_post_author, NEW.user_id, v_handle, v_avatar, 'like', NEW.post_id, v_post_image);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_like_notification
  AFTER INSERT ON public.likes
  FOR EACH ROW EXECUTE PROCEDURE public.handle_like_notification();

-- Trigger: create follow notification
CREATE OR REPLACE FUNCTION public.handle_follow_notification()
RETURNS trigger AS $$
DECLARE
  v_handle text;
  v_avatar text;
BEGIN
  SELECT handle, avatar_url INTO v_handle, v_avatar
    FROM public.profiles WHERE id = NEW.follower_id;
  INSERT INTO public.notifications
    (recipient_id, actor_id, actor_handle, actor_avatar, type)
  VALUES
    (NEW.following_id, NEW.follower_id, v_handle, v_avatar, 'follow');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_follow_notification
  AFTER INSERT ON public.follows
  FOR EACH ROW EXECUTE PROCEDURE public.handle_follow_notification();

-- Trigger: create comment notification
CREATE OR REPLACE FUNCTION public.handle_comment_notification()
RETURNS trigger AS $$
DECLARE
  v_post_author uuid;
  v_post_image  text;
  v_handle      text;
  v_avatar      text;
BEGIN
  SELECT author_id, image_url INTO v_post_author, v_post_image
    FROM public.posts WHERE id = NEW.post_id;
  SELECT handle, avatar_url INTO v_handle, v_avatar
    FROM public.profiles WHERE id = NEW.author_id;
  IF v_post_author IS DISTINCT FROM NEW.author_id THEN
    INSERT INTO public.notifications
      (recipient_id, actor_id, actor_handle, actor_avatar, type, post_id, post_image_url, comment_body)
    VALUES
      (v_post_author, NEW.author_id, v_handle, v_avatar, 'comment', NEW.post_id, v_post_image, NEW.body);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_comment_notification
  AFTER INSERT ON public.comments
  FOR EACH ROW EXECUTE PROCEDURE public.handle_comment_notification();
*/
