import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import 'combined_screen.dart';
import 'routines_screen.dart';
import '../widgets/ai_chat_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0; // Combined (Calendar + Today) is default

  List<Widget> get _screens => [
    const CombinedScreen(),
    const RoutinesScreen(),
    _buildProfileScreen(),
  ];

  Widget _buildProfileScreen() {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '마이페이지',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              
              // User info card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppTheme.accentLight,
                      child: Text(
                        (provider.user?.email?.substring(0, 1) ?? 'U').toUpperCase(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            provider.user?.displayName ?? '사용자',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            provider.user?.email ?? '',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Logout button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => provider.signOut(),
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('로그아웃'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    side: const BorderSide(color: AppTheme.divider),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          // 상단 SafeArea 공간 확보
          Container(
            height: topPadding > 0 ? topPadding : 16,
            color: AppTheme.background,
          ),
          // 메인 콘텐츠
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        color: AppTheme.background,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppTheme.divider, width: 0.5),
                ),
              ),
              child: BottomNavigationBar(
                currentIndex: _currentIndex,
                onTap: (index) => setState(() => _currentIndex = index),
                backgroundColor: AppTheme.background,
                elevation: 0,
                selectedItemColor: AppTheme.textPrimary,
                unselectedItemColor: AppTheme.textTertiary,
                selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
                type: BottomNavigationBarType.fixed,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.calendar_today_outlined, size: 22),
                    activeIcon: Icon(Icons.calendar_today, size: 22),
                    label: '오늘',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.repeat_outlined, size: 22),
                    activeIcon: Icon(Icons.repeat, size: 22),
                    label: '루틴',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.person_outline, size: 22),
                    activeIcon: Icon(Icons.person, size: 22),
                    label: '마이페이지',
                  ),
                ],
              ),
            ),
            // 하단 SafeArea 공간 확보
            Container(
              height: bottomPadding > 0 ? bottomPadding : 8,
              color: AppTheme.background,
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding > 0 ? 0 : 8),
        child: FloatingActionButton(
          onPressed: () => _showAIChat(context),
          backgroundColor: AppTheme.background,
          elevation: 2,
          child: const Icon(
            Icons.auto_awesome_outlined,
            size: 22,
            color: AppTheme.accent,
          ),
        ),
      ),
    );
  }

  void _showAIChat(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AIChatDialog(),
    );
  }
}
