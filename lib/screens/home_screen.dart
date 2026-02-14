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

  final List<Widget> _screens = const [
    CombinedScreen(),
    RoutinesScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;
    final bottomPadding = mediaQuery.padding.bottom;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          // Top safe area
          Container(
            height: topPadding,
            color: AppTheme.background,
          ),
          
          // App Bar
          _buildAppBar(context),
          
          // Main content
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
          ),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: const BoxDecoration(
              color: AppTheme.background,
              border: Border(
                top: BorderSide(color: AppTheme.divider, width: 0.5),
              ),
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
              backgroundColor: Colors.transparent,
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
              ],
            ),
          ),
          // Bottom safe area
          Container(
            height: bottomPadding,
            color: AppTheme.background,
          ),
        ],
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

  Widget _buildAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppTheme.background,
        border: Border(
          bottom: BorderSide(color: AppTheme.divider, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          const Text(
            'todai',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w300,
              color: AppTheme.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          Consumer<AppProvider>(
            builder: (context, provider, _) {
              return PopupMenuButton<String>(
                icon: const Icon(
                  Icons.person_outline,
                  size: 24,
                  color: AppTheme.textSecondary,
                ),
                offset: const Offset(0, 45),
                onSelected: (value) async {
                  if (value == 'signout') {
                    await provider.signOut();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    enabled: false,
                    child: Text(
                      provider.user?.email ?? 'User',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'signout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, size: 18, color: AppTheme.textSecondary),
                        SizedBox(width: 8),
                        Text('로그아웃'),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
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
