import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models.dart';

SupabaseClient get _db => Supabase.instance.client;
const _uuid = Uuid();

// ── AUTH ──────────────────────────────────────────────────────────────────────

class AuthService {
  User? get currentUser => _db.auth.currentUser;
  String? get currentUserId => _db.auth.currentUser?.id;
  Stream<AuthState> get authStateChanges => _db.auth.onAuthStateChange;

  Future<AuthResponse> register({
    required String email,
    required String password,
    required String handle,
    required String fullName,
  }) async {
    return await _db.auth.signUp(
      email: email,
      password: password,
      data: {'handle': handle, 'full_name': fullName},
    );
  }

  Future<AuthResponse> login({required String email, required String password}) async {
    return await _db.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> logout() async => await _db.auth.signOut();
}

// ── STORAGE ───────────────────────────────────────────────────────────────────

class StorageService {
  Future<String> uploadPostImage(File file, String userId) async {
    final ext  = file.path.split('.').last;
    final path = '$userId/${_uuid.v4()}.$ext';
    await _db.storage.from('posts').upload(path, file,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false));
    return _db.storage.from('posts').getPublicUrl(path);
  }

  Future<String> uploadAvatar(File file, String userId) async {
    final ext  = file.path.split('.').last;
    final path = '$userId/avatar.$ext';
    await _db.storage.from('avatars').upload(path, file,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: true));
    return _db.storage.from('avatars').getPublicUrl(path);
  }
}

// ── PROFILE SERVICE ───────────────────────────────────────────────────────────

class ProfileService {
  Future<ProfileModel?> getProfile(String userId) async {
    try {
      final res = await _db.from('profile_stats').select().eq('id', userId).maybeSingle();
      return res != null ? ProfileModel.fromMap(res) : null;
    } catch (_) {
      return null;
    }
  }

  Future<ProfileModel?> getMyProfile() async {
    try {
      final uid = _db.auth.currentUser?.id;
      if (uid == null) return null;
      return getProfile(uid);
    } catch (_) {
      return null;
    }
  }

  Future<void> updateProfile({
    required String userId,
    String? fullName,
    String? bio,
    String? avatarUrl,
    String? website,
  }) async {
    final updates = <String, dynamic>{};
    if (fullName  != null) updates['full_name']  = fullName;
    if (bio       != null) updates['bio']        = bio;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (website   != null) updates['website']    = website;
    if (updates.isEmpty) return;
    await _db.from('profiles').update(updates).eq('id', userId);
  }

  Future<List<ProfileModel>> searchProfiles(String query) async {
    final res = await _db
        .from('profile_stats')
        .select()
        .or('handle.ilike.%$query%,full_name.ilike.%$query%')
        .limit(20);
    return (res as List).map((m) => ProfileModel.fromMap(m)).toList();
  }

  Future<bool> isFollowing(String targetId) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return false;
    final res = await _db
        .from('follows').select('id')
        .eq('follower_id', uid).eq('following_id', targetId).maybeSingle();
    return res != null;
  }

  Future<void> follow(String targetId) async {
    final uid = _db.auth.currentUser!.id;
    await _db.from('follows').insert({'follower_id': uid, 'following_id': targetId});
  }

  Future<void> unfollow(String targetId) async {
    final uid = _db.auth.currentUser!.id;
    await _db.from('follows').delete()
        .eq('follower_id', uid).eq('following_id', targetId);
  }

  /// Returns list of profiles who follow [userId]
  Future<List<ProfileModel>> getFollowers(String userId) async {
    final res = await _db
        .from('follows')
        .select('follower_id, profile_stats!follows_follower_id_fkey(*)')
        .eq('following_id', userId);
    return (res as List)
        .map((r) => ProfileModel.fromMap(r['profile_stats'] as Map<String, dynamic>))
        .toList();
  }

  /// Returns list of profiles that [userId] follows
  Future<List<ProfileModel>> getFollowing(String userId) async {
    final res = await _db
        .from('follows')
        .select('following_id, profile_stats!follows_following_id_fkey(*)')
        .eq('follower_id', userId);
    return (res as List)
        .map((r) => ProfileModel.fromMap(r['profile_stats'] as Map<String, dynamic>))
        .toList();
  }
}

// ── POST SERVICE ──────────────────────────────────────────────────────────────

class PostService {
  Future<List<PostModel>> getFeed({int limit = 20, int offset = 0}) async {
    final uid = _db.auth.currentUser?.id;
    final res = await _db
        .from('posts_with_author').select()
        .eq('visibility', 'public')
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    final posts = (res as List).map((m) => PostModel.fromMap(m)).toList();
    if (uid != null) await _attachLikedStatus(posts, uid);
    return posts;
  }

  Future<List<PostModel>> getPostsByAuthor(String authorId) async {
    final uid = _db.auth.currentUser?.id;
    final res = await _db
        .from('posts_with_author').select()
        .eq('author_id', authorId)
        .order('created_at', ascending: false);
    final posts = (res as List).map((m) => PostModel.fromMap(m)).toList();
    if (uid != null) await _attachLikedStatus(posts, uid);
    return posts;
  }

  Future<List<PostModel>> searchPosts(String query) async {
    final uid = _db.auth.currentUser?.id;
    final res = await _db
        .from('posts_with_author').select()
        .eq('visibility', 'public')
        .or('title.ilike.%$query%,category.ilike.%$query%,description.ilike.%$query%')
        .order('created_at', ascending: false).limit(30);
    final posts = (res as List).map((m) => PostModel.fromMap(m)).toList();
    if (uid != null) await _attachLikedStatus(posts, uid);
    return posts;
  }

  Future<List<PostModel>> searchByTag(String tag) async {
    final uid = _db.auth.currentUser?.id;
    final res = await _db
        .from('posts_with_author').select()
        .eq('visibility', 'public')
        .contains('tags', [tag])
        .order('likes_count', ascending: false)
        .limit(30);
    final posts = (res as List).map((m) => PostModel.fromMap(m)).toList();
    if (uid != null) await _attachLikedStatus(posts, uid);
    return posts;
  }

  /// Fetch the single most-liked post for a tag — used for tag card thumbnails
  Future<PostModel?> getTopPostForTag(String tag) async {
    final res = await _db
        .from('posts_with_author').select()
        .eq('visibility', 'public')
        .contains('tags', [tag])
        .order('likes_count', ascending: false)
        .limit(1)
        .maybeSingle();
    return res != null ? PostModel.fromMap(res) : null;
  }

  Future<PostModel?> getPost(String postId) async {
    final uid = _db.auth.currentUser?.id;
    final res = await _db
        .from('posts_with_author').select().eq('id', postId).maybeSingle();
    if (res == null) return null;
    final post = PostModel.fromMap(res);
    if (uid != null) await _attachLikedStatus([post], uid);
    return post;
  }

  Future<PostModel> createPost(PostModel post) async {
    final res = await _db.from('posts').insert(post.toInsertMap()).select().single();
    return PostModel.fromMap(res);
  }

  Future<void> deletePost(String postId) async {
    await _db.from('posts').delete().eq('id', postId);
  }

  Future<void> likePost(String postId) async {
    final uid = _db.auth.currentUser!.id;
    await _db.from('likes').insert({'post_id': postId, 'user_id': uid});
  }

  Future<void> unlikePost(String postId) async {
    final uid = _db.auth.currentUser!.id;
    await _db.from('likes').delete().eq('post_id', postId).eq('user_id', uid);
  }

  Future<void> _attachLikedStatus(List<PostModel> posts, String uid) async {
    if (posts.isEmpty) return;
    final ids   = posts.map((p) => p.id).toList();
    final liked = await _db.from('likes').select('post_id')
        .eq('user_id', uid).inFilter('post_id', ids);
    final likedIds = Set<String>.from((liked as List).map((l) => l['post_id']));
    for (final p in posts) {
      p.isLiked = likedIds.contains(p.id);
    }
  }
}

// ── COMMENT SERVICE ───────────────────────────────────────────────────────────

class CommentService {
  Future<List<CommentModel>> getComments(String postId) async {
    final res = await _db
        .from('comments')
        .select('*, profiles(handle, avatar_url)')
        .eq('post_id', postId)
        .order('created_at', ascending: true);
    return (res as List).map((m) => CommentModel.fromMap(m)).toList();
  }

  Future<CommentModel> addComment(String postId, String body) async {
    final uid = _db.auth.currentUser!.id;
    final res = await _db.from('comments').insert({
      'post_id': postId, 'author_id': uid, 'body': body,
    }).select('*, profiles(handle, avatar_url)').single();
    return CommentModel.fromMap(res);
  }

  Future<void> editComment(String commentId, String newBody) async {
    await _db.from('comments').update({'body': newBody}).eq('id', commentId);
  }

  Future<void> deleteComment(String commentId) async {
    await _db.from('comments').delete().eq('id', commentId);
  }
}

// ── DM SERVICE ────────────────────────────────────────────────────────────────

class DMService {
  Future<List<ConversationModel>> getConversations() async {
    final uid = _db.auth.currentUser!.id;
    final res = await _db
        .from('conversations').select()
        .or('participant1.eq.$uid,participant2.eq.$uid')
        .order('updated_at', ascending: false);
    final convos = (res as List).map((m) => ConversationModel.fromMap(m)).toList();
    final ps = profileService;
    for (final c in convos) {
      final otherId = c.participant1 == uid ? c.participant2 : c.participant1;
      c.otherProfile = await ps.getProfile(otherId);
    }
    return convos;
  }

  Future<ConversationModel> getOrCreateConversation(String otherUserId) async {
    final uid = _db.auth.currentUser!.id;
    final p1  = uid.compareTo(otherUserId) < 0 ? uid : otherUserId;
    final p2  = uid.compareTo(otherUserId) < 0 ? otherUserId : uid;
    final existing = await _db.from('conversations').select()
        .eq('participant1', p1).eq('participant2', p2).maybeSingle();
    if (existing != null) return ConversationModel.fromMap(existing);
    final created = await _db.from('conversations')
        .insert({'participant1': p1, 'participant2': p2}).select().single();
    return ConversationModel.fromMap(created);
  }

  Future<List<MessageModel>> getMessages(String conversationId, {int limit = 50}) async {
    final res = await _db.from('messages').select()
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: false).limit(limit);
    return (res as List).map((m) => MessageModel.fromMap(m)).toList().reversed.toList();
  }

  Future<void> sendMessage(String conversationId, String body) async {
    final uid = _db.auth.currentUser!.id;
    await _db.from('messages').insert(
        {'conversation_id': conversationId, 'sender_id': uid, 'body': body});
  }

  Stream<List<Map<String, dynamic>>> messagesStream(String conversationId) {
    return _db.from('messages').stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true)
        .map((data) => List<Map<String, dynamic>>.from(data));
  }
}

// ── Singletons ────────────────────────────────────────────────────────────────
final authService    = AuthService();
final storageService = StorageService();
final profileService = ProfileService();
final postService    = PostService();
final commentService = CommentService();
final dmService      = DMService();
