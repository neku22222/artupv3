class ProfileModel {
  final String id;
  final String handle;
  final String fullName;
  final String bio;
  String avatarUrl; // mutable for optimistic avatar update
  final String website;
  // mutable so we can optimistically update counts
  int followersCount;
  int followingCount;
  int postsCount;

  ProfileModel({
    required this.id,
    required this.handle,
    required this.fullName,
    required this.bio,
    required this.avatarUrl,
    required this.website,
    this.followersCount = 0,
    this.followingCount = 0,
    this.postsCount = 0,
  });

  factory ProfileModel.fromMap(Map<String, dynamic> m) => ProfileModel(
    id:             m['id'] as String,
    handle:         m['handle'] as String,
    fullName:       (m['full_name'] ?? '') as String,
    bio:            (m['bio'] ?? '') as String,
    avatarUrl:      (m['avatar_url'] ?? '') as String,
    website:        (m['website'] ?? '') as String,
    followersCount: (m['followers_count'] ?? 0) as int,
    followingCount: (m['following_count'] ?? 0) as int,
    postsCount:     (m['posts_count'] ?? 0) as int,
  );

  Map<String, dynamic> toMap() => {
    'handle': handle, 'full_name': fullName, 'bio': bio,
    'avatar_url': avatarUrl, 'website': website,
  };
}

class PostModel {
  final String id;
  final String authorId;
  final String title;
  final String description;
  // Primary image (first, used for thumbnails)
  final String imageUrl;
  // All images, up to 5
  final List<String> imageUrls;
  final String category;
  final List<String> tags;
  final String visibility;
  int likesCount; // mutable for optimistic updates
  final DateTime createdAt;
  final String? authorHandle;
  final String? authorName;
  final String? authorAvatar;
  bool isLiked;

  PostModel({
    required this.id,
    required this.authorId,
    required this.title,
    required this.description,
    required this.imageUrl,
    List<String>? imageUrls,
    required this.category,
    required this.tags,
    required this.visibility,
    required this.likesCount,
    required this.createdAt,
    this.authorHandle,
    this.authorName,
    this.authorAvatar,
    this.isLiked = false,
  }) : imageUrls = (imageUrls != null && imageUrls.isNotEmpty) ? imageUrls : [imageUrl];

  factory PostModel.fromMap(Map<String, dynamic> m) {
    final primary = m['image_url'] as String;
    final urls = m['image_urls'] != null
        ? List<String>.from(m['image_urls'] as List)
        : <String>[];
    if (urls.isEmpty) urls.add(primary);
    return PostModel(
      id:           m['id'] as String,
      authorId:     m['author_id'] as String,
      title:        m['title'] as String,
      description:  (m['description'] ?? '') as String,
      imageUrl:     primary,
      imageUrls:    urls,
      category:     (m['category'] ?? '2D Illustration') as String,
      tags:         List<String>.from(m['tags'] ?? []),
      visibility:   (m['visibility'] ?? 'public') as String,
      likesCount:   (m['likes_count'] ?? 0) as int,
      createdAt:    DateTime.parse(m['created_at'] as String),
      authorHandle: m['author_handle'] as String?,
      authorName:   m['author_name'] as String?,
      authorAvatar: m['author_avatar'] as String?,
    );
  }

  Map<String, dynamic> toInsertMap() => {
    'author_id': authorId, 'title': title, 'description': description,
    'image_url': imageUrl, 'image_urls': imageUrls,
    'category': category, 'tags': tags, 'visibility': visibility,
  };
}

class CommentModel {
  final String id;
  final String postId;
  final String authorId;
  String body; // mutable for inline edit
  final DateTime createdAt;
  final String? authorHandle;
  final String? authorAvatar;

  CommentModel({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.body,
    required this.createdAt,
    this.authorHandle,
    this.authorAvatar,
  });

  factory CommentModel.fromMap(Map<String, dynamic> m) => CommentModel(
    id:           m['id'] as String,
    postId:       m['post_id'] as String,
    authorId:     m['author_id'] as String,
    body:         m['body'] as String,
    createdAt:    DateTime.parse(m['created_at'] as String),
    authorHandle: m['profiles'] != null ? (m['profiles']['handle'] as String?) : null,
    authorAvatar: m['profiles'] != null ? (m['profiles']['avatar_url'] as String?) : null,
  );
}

class ConversationModel {
  final String id;
  final String participant1;
  final String participant2;
  final String lastMessage;
  final DateTime updatedAt;
  ProfileModel? otherProfile;

  ConversationModel({
    required this.id,
    required this.participant1,
    required this.participant2,
    required this.lastMessage,
    required this.updatedAt,
    this.otherProfile,
  });

  factory ConversationModel.fromMap(Map<String, dynamic> m) => ConversationModel(
    id:           m['id'] as String,
    participant1: m['participant1'] as String,
    participant2: m['participant2'] as String,
    lastMessage:  (m['last_message'] ?? '') as String,
    updatedAt:    DateTime.parse(m['updated_at'] as String),
  );
}

class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String body;
  final DateTime createdAt;

  const MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.createdAt,
  });

  factory MessageModel.fromMap(Map<String, dynamic> m) => MessageModel(
    id:             m['id'] as String,
    conversationId: m['conversation_id'] as String,
    senderId:       m['sender_id'] as String,
    body:           m['body'] as String,
    createdAt:      DateTime.parse(m['created_at'] as String),
  );
}
