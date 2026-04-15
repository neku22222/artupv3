import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/upload_screen.dart';
import 'screens/dm_screen.dart';
import 'screens/settings_screen.dart';

// ── IMPORTANT: Replace with your actual Supabase credentials ──────────────────
const _supabaseUrl    = 'https://ylboyktduhpflhunkast.supabase.co';
const _supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlsYm95a3RkdWhwZmxodW5rYXN0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU4NzcwMjgsImV4cCI6MjA5MTQ1MzAyOH0.3H4KynybNMFJC9WC51xWE-PfaV1gz-thOcT5hbQR71k';
// ─────────────────────────────────────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseAnonKey);

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  runApp(const ArtUpApp());
}

class ArtUpApp extends StatelessWidget {
  const ArtUpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ArtUp',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      home: const _AuthGate(),
    );
  }
}

// Listens to auth state changes and routes accordingly
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.cream,
            body: Center(child: CircularProgressIndicator(color: AppColors.peach)),
          );
        }
        final session = snapshot.data?.session
            ?? Supabase.instance.client.auth.currentSession;
        if (session != null) return const MainShell();
        return const LoginScreen();
      },
    );
  }
}

// ── Main app shell with bottom navigation ─────────────────────────────────────

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    SearchScreen(),
    SizedBox.shrink(), // Upload is modal
    DMScreen(),
    SettingsScreen(),
  ];

  void _onTabTapped(int index) {
    if (index == 2) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const UploadScreen(),
        fullscreenDialog: true,
      )).then((_) {
        // Refresh home feed after upload
        if (_currentIndex == 0) setState(() {});
      });
      return;
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: _buildAppBar(),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final titles = ['ArtUp', 'Discover', '', 'Messages', 'Settings'];
    final isLogo = [true, false, false, true, true];

    return AppBar(
      backgroundColor: AppColors.warmWhite,
      elevation: 0,
      centerTitle: true,
      title: isLogo[_currentIndex]
          ? Text('ArtUp',
              style: GoogleFonts.playfairDisplay(
                  fontSize: 22, fontWeight: FontWeight.w700,
                  fontStyle: FontStyle.italic, color: AppColors.peach))
          : Text(titles[_currentIndex],
              style: GoogleFonts.dmSans(
                  fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.dark)),
      actions: [
        if (_currentIndex == 0)
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: AppColors.peach),
            onPressed: () {},
          ),
        if (_currentIndex == 3)
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.peach),
            onPressed: () {},
          ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppColors.border),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.warmWhite,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home', index: 0, current: _currentIndex, onTap: _onTabTapped),
              _NavItem(icon: Icons.search_outlined, activeIcon: Icons.search, label: 'Search', index: 1, current: _currentIndex, onTap: _onTabTapped),
              _UploadBtn(onTap: () => _onTabTapped(2)),
              _NavItem(icon: Icons.chat_bubble_outline, activeIcon: Icons.chat_bubble, label: 'DM', index: 3, current: _currentIndex, onTap: _onTabTapped),
              _NavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile', index: 4, current: _currentIndex, onTap: _onTabTapped),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final int index, current;
  final ValueChanged<int> onTap;

  const _NavItem({required this.icon, required this.activeIcon, required this.label,
      required this.index, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = current == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(index),
      child: SizedBox(
        width: 56,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(active ? activeIcon : icon, color: active ? AppColors.peach : AppColors.muted, size: 24),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.dmSans(
              fontSize: 9, fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              color: active ? AppColors.peach : AppColors.muted)),
        ]),
      ),
    );
  }
}

class _UploadBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _UploadBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.peach, AppColors.amber]),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: AppColors.peach.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 24),
      ),
    );
  }
}
