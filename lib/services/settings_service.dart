import 'package:shared_preferences/shared_preferences.dart';

/// Persisted app preferences backed by SharedPreferences.
/// Call [SettingsService.init()] once in main() before runApp.
class SettingsService {
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ── Keys ────────────────────────────────────────────────────────────────
  static const _kAgeRating    = 'age_rating';
  static const _kPushLikes    = 'push_likes';
  static const _kPushComments = 'push_comments';
  static const _kPushFollows  = 'push_follows';
  static const _kPushMessages = 'push_messages';

  // ── Age Rating ───────────────────────────────────────────────────────────
  static String get ageRating =>
      _prefs.getString(_kAgeRating) ?? 'All Ages';
  static set ageRating(String v) => _prefs.setString(_kAgeRating, v);

  // ── Push Notifications ──────────────────────────────────────────────────
  static bool get pushLikes =>
      _prefs.getBool(_kPushLikes) ?? true;
  static set pushLikes(bool v) => _prefs.setBool(_kPushLikes, v);

  static bool get pushComments =>
      _prefs.getBool(_kPushComments) ?? true;
  static set pushComments(bool v) => _prefs.setBool(_kPushComments, v);

  static bool get pushFollows =>
      _prefs.getBool(_kPushFollows) ?? true;
  static set pushFollows(bool v) => _prefs.setBool(_kPushFollows, v);

  static bool get pushMessages =>
      _prefs.getBool(_kPushMessages) ?? true;
  static set pushMessages(bool v) => _prefs.setBool(_kPushMessages, v);
}