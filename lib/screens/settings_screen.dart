import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models.dart';
import '../services/supabase_service.dart';
import '../widgets/common_widgets.dart';
import '../theme/app_theme.dart';
import 'profile_screen.dart';

// ── Preferences stored locally (would use SharedPreferences in production) ───
class AppPrefs {
  static String language       = 'English';
  static String ageRating      = 'All Ages';   // 'All Ages' | '13+' | '17+' | '18+'
  static bool   pushLikes      = true;
  static bool   pushComments   = true;
  static bool   pushFollows    = true;
  static bool   pushMessages   = true;
  static bool   darkMode       = false;
  static String gridColumns    = '2';          // '2' | '3'
  static bool   showLikeCounts = true;
}

// ─────────────────────────────────────────────────────────────────────────────

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  ProfileModel? _profile;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final p = await profileService.getMyProfile();
      if (mounted) setState(() { _profile = p; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _profile = null; _loading = false; });
    }
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Log out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Log out', style: TextStyle(color: AppColors.errorRed))),
        ],
      ),
    );
    if (ok == true) await authService.logout();
  }

  Future<void> _push(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.peach));

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Profile card ──────────────────────────────────────────────────
        GestureDetector(
          onTap: _profile != null
              ? () => _push(ProfileScreen(userId: _profile!.id))
              : null,
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardBg, borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(children: [
              UserAvatar(url: _profile?.avatarUrl ?? '', size: 56),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_profile?.fullName.isNotEmpty == true ? _profile!.fullName : 'Your Name',
                    style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.dark)),
                Text('@${_profile?.handle ?? ''}',
                    style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted)),
                const SizedBox(height: 8),
                Row(children: [
                  _stat('${_profile?.postsCount ?? 0}', 'Works'),
                  const SizedBox(width: 14),
                  _stat('${_profile?.followersCount ?? 0}', 'Followers'),
                  const SizedBox(width: 14),
                  _stat('${_profile?.followingCount ?? 0}', 'Following'),
                ]),
              ])),
              const Icon(Icons.chevron_right, color: AppColors.muted, size: 18),
            ]),
          ),
        ),

        // ── Account ───────────────────────────────────────────────────────
        _sectionLabel('Account'),
        _group([
          _tile('👤', const Color(0xFFFDE8D8), 'Your Profile',
              onTap: () => _profile != null ? _push(ProfileScreen(userId: _profile!.id)) : null),
          _tile('🔒', const Color(0xFFDFF0E4), 'Security & Password',
              onTap: () => _push(const _SecurityPage())),
          _tile('🔗', const Color(0xFFE0EEFF), 'Linked Accounts',
              onTap: () => _push(_LinkedAccountsPage(userId: _profile?.id ?? ''))),
        ]),

        // ── Preferences ───────────────────────────────────────────────────
        _sectionLabel('Preferences'),
        _group([
          _tile('🔔', const Color(0xFFFFF0D8), 'Notifications',
              onTap: () => _push(const _NotificationsPage())),
          _tile('🖥️', const Color(0xFFEDE0FF), 'Display Settings',
              onTap: () => _push(const _DisplayPage())),
          _tile('🌐', const Color(0xFFE0EEFF), 'Language',
              value: AppPrefs.language,
              onTap: () async {
                await _push(const _LanguagePage());
                setState(() {});
              }),
        ]),

        // ── Support ───────────────────────────────────────────────────────
        _sectionLabel('Support'),
        _group([
          _tile('❓', const Color(0xFFF0F0F0), 'Help & Support',
              onTap: () => _push(const _HelpPage())),
          _tile('⭐', const Color(0xFFFFF8E0), 'Credits',
              onTap: () => _push(const _CreditsPage())),
          _tile('🚪', const Color(0xFFFFEEEE), 'Log Out',
              labelColor: AppColors.errorRed, showArrow: false, onTap: _logout),
        ]),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('ArtUp v1.0.0',
              style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted)),
        ),
      ]),
    );
  }

  Widget _stat(String v, String l) => Column(children: [
    Text(v, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.dark)),
    Text(l, style: GoogleFonts.dmSans(fontSize: 9, color: AppColors.muted)),
  ]);

  Widget _sectionLabel(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
    child: Text(t.toUpperCase(),
        style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: 1)),
  );

  Widget _group(List<Widget> children) => Container(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
    decoration: BoxDecoration(color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
    child: Column(children: children.asMap().entries.map((e) {
      final i = e.key;
      return Column(children: [
        e.value,
        if (i < children.length - 1)
          const Divider(height: 1, thickness: 1, color: AppColors.border, indent: 14, endIndent: 14),
      ]);
    }).toList()),
  );

  Widget _tile(String icon, Color iconBg, String label, {
    Color? labelColor, String? value, bool showArrow = true, VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(children: [
          Container(width: 32, height: 32,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
              alignment: Alignment.center,
              child: Text(icon, style: const TextStyle(fontSize: 16))),
          const SizedBox(width: 12),
          Expanded(child: Text(label,
              style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500,
                  color: labelColor ?? AppColors.dark))),
          if (value != null) Text(value, style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted)),
          if (showArrow) ...[
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: AppColors.muted, size: 18),
          ],
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECURITY PAGE
// ─────────────────────────────────────────────────────────────────────────────

class _SecurityPage extends StatefulWidget {
  const _SecurityPage();
  @override
  State<_SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<_SecurityPage> {
  final _currentCtrl = TextEditingController();
  final _newCtrl     = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew     = true;
  bool _obscureConfirm = true;
  bool _saving = false;
  String? _error;
  String? _success;

  // Age rating
  String _selectedRating = AppPrefs.ageRating;
  final _ratings = ['All Ages', '13+', '17+', '18+'];
  final _ratingDesc = {
    'All Ages': 'Show all content — no restrictions',
    '13+':      'Hide content rated 17+ and 18+',
    '17+':      'Hide content rated 18+ only',
    '18+':      'Show everything including mature content',
  };

  @override
  void dispose() {
    _currentCtrl.dispose(); _newCtrl.dispose(); _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    setState(() { _error = null; _success = null; });
    if (_newCtrl.text != _confirmCtrl.text) {
      setState(() => _error = 'New passwords do not match'); return;
    }
    if (_newCtrl.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters'); return;
    }
    setState(() => _saving = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _newCtrl.text.trim()));
      _currentCtrl.clear(); _newCtrl.clear(); _confirmCtrl.clear();
      setState(() => _success = 'Password updated successfully');
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: _appBar(context, 'Security & Password'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Change Password ────────────────────────────────────────────
          _card(children: [
            _cardTitle('Change Password'),
            const SizedBox(height: 16),
            _passField('Current password', _currentCtrl, _obscureCurrent,
                () => setState(() => _obscureCurrent = !_obscureCurrent)),
            const SizedBox(height: 12),
            _passField('New password', _newCtrl, _obscureNew,
                () => setState(() => _obscureNew = !_obscureNew)),
            const SizedBox(height: 12),
            _passField('Confirm new password', _confirmCtrl, _obscureConfirm,
                () => setState(() => _obscureConfirm = !_obscureConfirm)),
            if (_error != null) ...[
              const SizedBox(height: 10),
              _errorBox(_error!),
            ],
            if (_success != null) ...[
              const SizedBox(height: 10),
              _successBox(_success!),
            ],
            const SizedBox(height: 16),
            GradientButton(label: 'Update Password', onPressed: _changePassword, loading: _saving),
          ]),

          const SizedBox(height: 20),

          // ── Age Rating ────────────────────────────────────────────────
          _card(children: [
            _cardTitle('Content Age Rating'),
            const SizedBox(height: 4),
            Text('Control what content is shown in your feed.',
                style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted)),
            const SizedBox(height: 14),
            ..._ratings.map((r) {
              final selected = _selectedRating == r;
              return GestureDetector(
                onTap: () => setState(() {
                  _selectedRating = r;
                  AppPrefs.ageRating = r;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.peachPale : AppColors.cream,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: selected ? AppColors.peach : AppColors.border, width: 1.5),
                  ),
                  child: Row(children: [
                    Container(
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected ? AppColors.peach : Colors.transparent,
                        border: Border.all(
                            color: selected ? AppColors.peach : AppColors.muted, width: 2),
                      ),
                      child: selected
                          ? const Icon(Icons.check, color: Colors.white, size: 12)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r, style: GoogleFonts.dmSans(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: selected ? AppColors.peach : AppColors.dark)),
                      Text(_ratingDesc[r]!,
                          style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted)),
                    ])),
                  ]),
                ),
              );
            }),
          ]),
        ]),
      ),
    );
  }

  Widget _passField(String hint, TextEditingController ctrl, bool obscure, VoidCallback toggle) =>
      TextField(
        controller: ctrl, obscureText: obscure,
        style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.dark),
        decoration: InputDecoration(
          hintText: hint,
          suffixIcon: IconButton(
            icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: AppColors.muted, size: 18),
            onPressed: toggle,
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// LINKED ACCOUNTS PAGE
// ─────────────────────────────────────────────────────────────────────────────

class _LinkedAccountsPage extends StatefulWidget {
  final String userId;
  const _LinkedAccountsPage({required this.userId});
  @override
  State<_LinkedAccountsPage> createState() => _LinkedAccountsPageState();
}

class _LinkedAccountsPageState extends State<_LinkedAccountsPage> {
  List<ProfileModel> _linked = [];
  bool _loading = true;
  final _handleCtrl = TextEditingController();
  bool _adding = false;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _handleCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      // Fetch linked accounts from Supabase
      final res = await Supabase.instance.client
          .from('linked_accounts')
          .select('linked_id, profile_stats!linked_accounts_linked_id_fkey(*)')
          .eq('owner_id', widget.userId);
      final profiles = (res as List)
          .map((r) => ProfileModel.fromMap(r['profile_stats'] as Map<String, dynamic>))
          .toList();
      if (mounted) setState(() { _linked = profiles; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addAccount() async {
    final handle = _handleCtrl.text.trim().replaceAll('@', '');
    if (handle.isEmpty) return;
    setState(() => _adding = true);
    try {
      final results = await profileService.searchProfiles(handle);
      final match = results.where((p) => p.handle == handle).toList();
      if (match.isEmpty) {
        _snack('No account found with handle @$handle');
        setState(() => _adding = false);
        return;
      }
      final target = match.first;
      if (target.id == widget.userId) {
        _snack('You cannot link your own account');
        setState(() => _adding = false);
        return;
      }
      await Supabase.instance.client.from('linked_accounts')
          .insert({'owner_id': widget.userId, 'linked_id': target.id});
      _handleCtrl.clear();
      await _load();
    } catch (e) {
      _snack('Failed to link account');
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _remove(String linkedId) async {
    await Supabase.instance.client.from('linked_accounts')
        .delete().eq('owner_id', widget.userId).eq('linked_id', linkedId);
    setState(() => _linked.removeWhere((p) => p.id == linkedId));
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: _appBar(context, 'Linked Accounts'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _card(children: [
            _cardTitle('About Linked Accounts'),
            const SizedBox(height: 6),
            Text(
              'Link your other ArtUp accounts here — for example, an NSFW account separate from your main portfolio. '
              'Linked accounts are publicly visible on your profile so followers can find your other work.',
              style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.muted, height: 1.6),
            ),
          ]),
          const SizedBox(height: 16),

          _card(children: [
            _cardTitle('Add Account'),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _handleCtrl,
                  style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.dark),
                  decoration: const InputDecoration(
                    hintText: 'Enter handle to link…',
                    prefixText: '@',
                  ),
                  onSubmitted: (_) => _addAccount(),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _adding ? null : _addAccount,
                child: Container(
                  padding: const EdgeInsets.all(11),
                  decoration: const BoxDecoration(color: AppColors.peach, shape: BoxShape.circle),
                  child: _adding
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.add, color: Colors.white, size: 20),
                ),
              ),
            ]),
          ]),

          const SizedBox(height: 16),

          if (_loading)
            const Center(child: CircularProgressIndicator(color: AppColors.peach))
          else if (_linked.isEmpty)
            const EmptyState(emoji: '🔗', title: 'No linked accounts',
                subtitle: 'Link your other ArtUp accounts above')
          else
            _card(children: [
              _cardTitle('Linked (${_linked.length})'),
              const SizedBox(height: 8),
              ..._linked.map((p) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  UserAvatar(url: p.avatarUrl, size: 40),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.fullName.isNotEmpty ? p.fullName : '@${p.handle}',
                        style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.dark)),
                    Text('@${p.handle}',
                        style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted)),
                  ])),
                  GestureDetector(
                    onTap: () => _remove(p.id),
                    child: const Icon(Icons.link_off, color: AppColors.errorRed, size: 20),
                  ),
                ]),
              )),
            ]),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFICATIONS PAGE
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationsPage extends StatefulWidget {
  const _NotificationsPage();
  @override
  State<_NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<_NotificationsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: _appBar(context, 'Notifications'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          _card(children: [
            _cardTitle('Push Notifications'),
            const SizedBox(height: 4),
            Text('Choose what activity alerts you receive.',
                style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted)),
            const SizedBox(height: 14),
            _toggle('❤️  Likes on your posts',
                'When someone likes your artwork',
                AppPrefs.pushLikes,
                (v) => setState(() => AppPrefs.pushLikes = v)),
            _divider(),
            _toggle('💬  Comments',
                'When someone comments on your post',
                AppPrefs.pushComments,
                (v) => setState(() => AppPrefs.pushComments = v)),
            _divider(),
            _toggle('👤  New followers',
                'When someone follows your account',
                AppPrefs.pushFollows,
                (v) => setState(() => AppPrefs.pushFollows = v)),
            _divider(),
            _toggle('✉️  Direct messages',
                'When you receive a new message',
                AppPrefs.pushMessages,
                (v) => setState(() => AppPrefs.pushMessages = v)),
          ]),
          const SizedBox(height: 16),
          _card(children: [
            _cardTitle('Email Notifications'),
            const SizedBox(height: 4),
            Text('Manage email alerts via your Supabase account settings.',
                style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted, height: 1.5)),
          ]),
        ]),
      ),
    );
  }

  Widget _toggle(String title, String subtitle, bool value, ValueChanged<bool> onChanged) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.dark)),
            Text(subtitle, style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted)),
          ])),
          Switch(value: value, onChanged: onChanged,
              activeColor: AppColors.peach),
        ]),
      );

  Widget _divider() => const Divider(height: 1, color: AppColors.border);
}

// ─────────────────────────────────────────────────────────────────────────────
// DISPLAY SETTINGS PAGE
// ─────────────────────────────────────────────────────────────────────────────

class _DisplayPage extends StatefulWidget {
  const _DisplayPage();
  @override
  State<_DisplayPage> createState() => _DisplayPageState();
}

class _DisplayPageState extends State<_DisplayPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: _appBar(context, 'Display Settings'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          _card(children: [
            _cardTitle('Theme'),
            const SizedBox(height: 12),
            Row(children: [
              _themeBtn('☀️  Light', false),
              const SizedBox(width: 10),
              _themeBtn('🌙  Dark', true),
            ]),
            const SizedBox(height: 6),
            Text('Dark mode support coming in a future update.',
                style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted)),
          ]),
          const SizedBox(height: 16),
          _card(children: [
            _cardTitle('Feed Grid'),
            const SizedBox(height: 4),
            Text('Number of columns in the artwork feed.',
                style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted)),
            const SizedBox(height: 12),
            Row(children: [
              _gridBtn('2', Icons.grid_view),
              const SizedBox(width: 10),
              _gridBtn('3', Icons.apps),
            ]),
          ]),
          const SizedBox(height: 16),
          _card(children: [
            _cardTitle('Post Display'),
            const SizedBox(height: 4),
            _switchRow('Show like counts', AppPrefs.showLikeCounts,
                (v) => setState(() => AppPrefs.showLikeCounts = v)),
          ]),
        ]),
      ),
    );
  }

  Widget _themeBtn(String label, bool isDark) {
    final active = AppPrefs.darkMode == isDark;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => AppPrefs.darkMode = isDark),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? AppColors.peachPale : AppColors.cream,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? AppColors.peach : AppColors.border, width: 1.5),
          ),
          child: Text(label, textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500,
                  color: active ? AppColors.peach : AppColors.muted)),
        ),
      ),
    );
  }

  Widget _gridBtn(String cols, IconData icon) {
    final active = AppPrefs.gridColumns == cols;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => AppPrefs.gridColumns = cols),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? AppColors.peachPale : AppColors.cream,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? AppColors.peach : AppColors.border, width: 1.5),
          ),
          child: Column(children: [
            Icon(icon, color: active ? AppColors.peach : AppColors.muted, size: 22),
            const SizedBox(height: 4),
            Text('$cols columns', style: GoogleFonts.dmSans(fontSize: 12,
                color: active ? AppColors.peach : AppColors.muted)),
          ]),
        ),
      ),
    );
  }

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged) =>
      Row(children: [
        Expanded(child: Text(label,
            style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.dark))),
        Switch(value: value, onChanged: onChanged, activeColor: AppColors.peach),
      ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// LANGUAGE PAGE
// ─────────────────────────────────────────────────────────────────────────────

class _LanguagePage extends StatefulWidget {
  const _LanguagePage();
  @override
  State<_LanguagePage> createState() => _LanguagePageState();
}

class _LanguagePageState extends State<_LanguagePage> {
  final _languages = const [
    ('English',          'English',          '🇬🇧'),
    ('Chinese',          '中文（简体）',      '🇨🇳'),
    ('Chinese (Taiwan)', '中文（繁體）',      '🇹🇼'),
    ('Malay',            'Bahasa Melayu',     '🇲🇾'),
    ('Japanese',         '日本語',            '🇯🇵'),
    ('Korean',           '한국어',            '🇰🇷'),
    ('French',           'Français',          '🇫🇷'),
    ('Spanish',          'Español',           '🇪🇸'),
  ];

  String _selected = AppPrefs.language;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: _appBar(context, 'Language'),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _languages.length,
        separatorBuilder: (_, __) => const SizedBox(height: 0),
        itemBuilder: (_, i) {
          final (key, native, flag) = _languages[i];
          final active = _selected == key;
          return GestureDetector(
            onTap: () {
              setState(() { _selected = key; AppPrefs.language = key; });
              Future.delayed(const Duration(milliseconds: 300),
                  () => Navigator.of(context).pop());
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: active ? AppColors.peachPale : AppColors.cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: active ? AppColors.peach : AppColors.border, width: 1.5),
              ),
              child: Row(children: [
                Text(flag, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(key, style: GoogleFonts.dmSans(
                      fontSize: 14, fontWeight: FontWeight.w600,
                      color: active ? AppColors.peach : AppColors.dark)),
                  if (native != key)
                    Text(native, style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted)),
                ])),
                if (active) const Icon(Icons.check_circle, color: AppColors.peach, size: 20),
              ]),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELP & SUPPORT PAGE
// ─────────────────────────────────────────────────────────────────────────────

class _HelpPage extends StatelessWidget {
  const _HelpPage();

  static const _faqs = [
    (
      'How do I post artwork?',
      'Tap the + button in the bottom navigation bar. You can upload up to 5 images per post. '
      'Add a title, description, tags, and choose your visibility before posting.'
    ),
    (
      'What content is allowed?',
      'ArtUp welcomes all original art: 2D, 3D, photography, sketches, and more. '
      'Content must be your own original work or work you have rights to share. '
      'Mature content must be tagged with the appropriate age rating.'
    ),
    (
      'How does the age rating filter work?',
      'Go to Settings → Security → Content Age Rating. Set your preferred rating and '
      'ArtUp will hide posts rated above your threshold from your feed and search results.'
    ),
    (
      'How do I link accounts?',
      'Go to Settings → Linked Accounts. Search for another ArtUp handle and tap the + button. '
      'Linked accounts appear publicly on your profile so followers can find your other work.'
    ),
    (
      'Can I delete my posts?',
      'Yes. Open the post, tap the trash icon in the top-right corner, and confirm the deletion. '
      'This action is permanent and cannot be undone.'
    ),
    (
      'How do I report inappropriate content?',
      'Long-press on any post and select "Report". Our moderation team will review the content within 48 hours. '
      'For urgent issues, contact us at support@artup.app.'
    ),
    (
      'How do I change my profile picture?',
      'Go to your Profile tab. Tap the camera icon on your avatar, or tap the avatar itself to open the image picker.'
    ),
    (
      'I forgot my password. What do I do?',
      'On the login screen, tap "Forgot password?" and enter your email. '
      'You will receive a reset link from Supabase Auth.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: _appBar(context, 'Help & Support'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Contact banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.peach, AppColors.amber]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(children: [
              const Text('📧', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Contact Support', style: GoogleFonts.dmSans(
                    fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                Text('support@artup.app', style: GoogleFonts.dmSans(
                    fontSize: 12, color: Colors.white.withOpacity(0.85))),
                Text('We reply within 24–48 hours', style: GoogleFonts.dmSans(
                    fontSize: 11, color: Colors.white.withOpacity(0.7))),
              ])),
            ]),
          ),
          const SizedBox(height: 24),

          Text('Frequently Asked Questions', style: GoogleFonts.dmSans(
              fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.dark)),
          const SizedBox(height: 12),

          ..._faqs.map((faq) => _FaqTile(question: faq.$1, answer: faq.$2)),

          const SizedBox(height: 20),
          _card(children: [
            _cardTitle('App Information'),
            const SizedBox(height: 8),
            _infoRow('Version',   '1.0.0'),
            _divider(),
            _infoRow('Platform',  'Android (Flutter)'),
            _divider(),
            _infoRow('Backend',   'Supabase'),
            _divider(),
            _infoRow('Support',   'support@artup.app'),
          ]),
        ]),
      ),
    );
  }

  Widget _infoRow(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(children: [
      Text(k, style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.muted)),
      const Spacer(),
      Text(v, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.dark)),
    ]),
  );

  Widget _divider() => const Divider(height: 1, color: AppColors.border);
}

class _FaqTile extends StatefulWidget {
  final String question;
  final String answer;
  const _FaqTile({required this.question, required this.answer});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBg, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _expanded ? AppColors.peachLight : AppColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(widget.question,
              style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.dark)),
          trailing: Icon(_expanded ? Icons.remove : Icons.add,
              color: AppColors.peach, size: 18),
          onExpansionChanged: (v) => setState(() => _expanded = v),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(widget.answer,
                  style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.muted, height: 1.6)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CREDITS PAGE
// ─────────────────────────────────────────────────────────────────────────────

class _CreditsPage extends StatelessWidget {
  const _CreditsPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: _appBar(context, 'Credits'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          const SizedBox(height: 16),
          // App logo
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppColors.peach, AppColors.amber],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text('A',
                  style: GoogleFonts.playfairDisplay(
                      fontSize: 40, fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 12),
          Text('ArtUp', style: GoogleFonts.playfairDisplay(
              fontSize: 28, fontWeight: FontWeight.w700,
              fontStyle: FontStyle.italic, color: AppColors.peach)),
          Text('Version 1.0.0', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.muted)),
          const SizedBox(height: 32),

          // Made by
          _card(children: [
            _cardTitle('Made by'),
            const SizedBox(height: 14),
            _creditPerson('👨‍💻', 'Khoo Yan Jun',    'Lead Developer & Designer'),
            const Divider(height: 24, color: AppColors.border),
            _creditPerson('👨‍💻', 'Chow Kai Feng',  'Developer & Co-Designer'),
          ]),
          const SizedBox(height: 16),

          // Special thanks
          _card(children: [
            _cardTitle('Special Thanks'),
            const SizedBox(height: 14),
            _thankItem('⚡', 'Supabase',
                'Backend, database, authentication & storage'),
            const Divider(height: 20, color: AppColors.border),
            _thankItem('🐦', 'Flutter & Dart',
                'Cross-platform UI framework by Google'),
            const Divider(height: 20, color: AppColors.border),
            _thankItem('🤖', 'Android Studio',
                'Development environment & device testing'),
          ]),
          const SizedBox(height: 16),

          const SizedBox(height: 32),
          Text('© 2025 ArtUp. All rights reserved.',
              style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('Made with ❤️ for artists everywhere.',
              style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  Widget _creditPerson(String emoji, String name, String role) => Row(children: [
    Text(emoji, style: const TextStyle(fontSize: 32)),
    const SizedBox(width: 14),
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(name, style: GoogleFonts.dmSans(
          fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.dark)),
      Text(role, style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted)),
    ]),
  ]);

  Widget _thankItem(String emoji, String name, String desc) => Row(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(emoji, style: const TextStyle(fontSize: 26)),
    const SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(name, style: GoogleFonts.dmSans(
          fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.dark)),
      Text(desc, style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted, height: 1.4)),
    ])),
  ]);

  Widget _libRow(String name) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      const Icon(Icons.code, size: 14, color: AppColors.muted),
      const SizedBox(width: 8),
      Text(name, style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.dark)),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED HELPERS
// ─────────────────────────────────────────────────────────────────────────────

AppBar _appBar(BuildContext context, String title) => AppBar(
  backgroundColor: AppColors.warmWhite,
  elevation: 0,
  leading: IconButton(
    icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.dark),
    onPressed: () => Navigator.of(context).pop(),
  ),
  title: Text(title,
      style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.dark)),
  bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(height: 1, color: AppColors.border)),
);

Widget _card({required List<Widget> children}) => Container(
  width: double.infinity,
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: AppColors.cardBg, borderRadius: BorderRadius.circular(16),
    border: Border.all(color: AppColors.border),
  ),
  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
);

Widget _cardTitle(String t) => Text(t,
    style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.dark));

Widget _errorBox(String msg) => Container(
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: AppColors.errorRed.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
  child: Row(children: [
    const Icon(Icons.error_outline, color: AppColors.errorRed, size: 16),
    const SizedBox(width: 8),
    Expanded(child: Text(msg,
        style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.errorRed))),
  ]),
);

Widget _successBox(String msg) => Container(
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: const Color(0xFFDFF0E4), borderRadius: BorderRadius.circular(10)),
  child: Row(children: [
    const Icon(Icons.check_circle_outline, color: Color(0xFF2E7D52), size: 16),
    const SizedBox(width: 8),
    Expanded(child: Text(msg,
        style: GoogleFonts.dmSans(fontSize: 12, color: Color(0xFF2E7D52)))),
  ]),
);
