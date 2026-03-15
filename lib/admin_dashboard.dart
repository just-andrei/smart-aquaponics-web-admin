import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin_sidebar.dart';
import 'navigation_provider.dart';
import 'dashboard_view.dart';
import 'user_management_view.dart';
import 'support_tickets_view.dart';
import 'master_sets_view.dart';
import 'user_account_service.dart';
import 'login.dart';


class AdminDashboard extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  const AdminDashboard({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
  });

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final NavigationProvider _navigationProvider = NavigationProvider();
  late Future<_SessionAccess> _accessFuture;
  bool _isSidebarCollapsed = false;

  void _toggleTheme() {
    final currentThemeMode = Theme.of(context).brightness == Brightness.dark
        ? ThemeMode.dark
        : ThemeMode.light;
    widget.onThemeChanged(
      currentThemeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
    );
  }

  @override
  void initState() {
    super.initState();
    _accessFuture = _resolveAccess();
  }

  Future<bool> _confirmLogout() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Future<void> _logoutAndGoToLogin() async {
    final confirmed = await _confirmLogout();
    if (!confirmed || !mounted) return;

    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (context, animation, secondaryAnimation) => LoginPage(
            themeMode: widget.themeMode,
            onThemeChanged: widget.onThemeChanged,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOut,
              ),
              child: child,
            );
          },
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Logout failed')),
      );
    }
  }

  Future<_SessionAccess> _resolveAccess() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const _SessionAccess(role: 'unknown', status: 'inactive');
    }

    final profileRecord = await UserAccountService.getProfileByUid(user.uid);
    final profile = profileRecord?.data;
    final fallbackRole = profileRecord == null
        ? ''
        : (profileRecord.collection == 'user' ? 'grower' : profileRecord.collection);

    final role = UserAccountService.normalizeRole(
      (profile?['role'] ?? fallbackRole).toString(),
    );
    final status = (profile?['status'] ?? 'active').toString().toLowerCase();
    return _SessionAccess(
      role: role,
      status: status,
    );
  }

  // Map to switch views based on selection
  Widget _getView(int index, String role) {
    switch (index) {
      case 0: return const DashboardOverview();
      case 1: return UserManagementView(
        currentUserRole: role,
        navigationProvider: _navigationProvider,
        onLogout: _logoutAndGoToLogin,
        onToggleTheme: _toggleTheme,
      );
      case 2: return MasterSetsView(userRole: role);
      case 3: return const SupportTicketsView();
      default: return const DashboardOverview();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_SessionAccess>(
      future: _accessFuture,
      builder: (context, accessSnapshot) {
        if (accessSnapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (accessSnapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Failed to load user access: ${accessSnapshot.error}')),
          );
        }

        final access = accessSnapshot.data ?? const _SessionAccess(role: 'unknown', status: 'inactive');
        final role = access.role;
        final status = access.status;

        if (UserAccountService.isGrowerRole(role)) {
          return _AccessDeniedView(
            message: 'Grower accounts cannot access the web admin dashboard.',
          );
        }

        if (status == 'inactive') {
          return _AccessDeniedView(
            message: 'Your account is inactive. Contact an admin.',
          );
        }

        final titles = <String>[
          'System Overview',
          'Grower Management',
          'System Sets',
          'Support Tickets',
        ];

        return ListenableBuilder(
          listenable: _navigationProvider,
          builder: (context, child) {
            return LayoutBuilder(builder: (context, constraints) {
              final selectedIndex = _navigationProvider.selectedIndex < titles.length
                  ? _navigationProvider.selectedIndex
                  : 0;
              final width = constraints.maxWidth;
              final isMobile = width < 600;
              final isTablet = width >= 600 && width < 1100;
              final isDesktop = width >= 1100;
              final showSidebar = isTablet || isDesktop;
              final collapsedSidebar = isTablet ? true : _isSidebarCollapsed;
              final isDark = Theme.of(context).brightness == Brightness.dark;
              final sidebarBackground = isDark ? const Color(0xFF0C1018) : const Color(0xFFF7F9FC);
              const contentTopPadding = 24.0;
              final sidebarDividerColor = isDark ? const Color(0xFF1A2130) : const Color(0xFFE3E7EE);

              return Scaffold(
                drawer: isMobile
                    ? Drawer(
                        child: AdminSidebar(
                          navigationProvider: _navigationProvider,
                          collapsed: false,
                          showToggle: false,
                          isDrawer: true,
                          onToggleTheme: _toggleTheme,
                          onLogout: _logoutAndGoToLogin,
                        ),
                      )
                    : null,
                body: Row(
                  children: [
                    if (showSidebar)
                      Container(
                        width: collapsedSidebar ? 76 : 248,
                        decoration: BoxDecoration(
                          color: sidebarBackground,
                          border: Border(
                            right: BorderSide(color: sidebarDividerColor),
                          ),
                        ),
                        child: AdminSidebar(
                          navigationProvider: _navigationProvider,
                          collapsed: collapsedSidebar,
                          showToggle: isDesktop,
                          isDrawer: false,
                          onToggleTheme: _toggleTheme,
                          onLogout: _logoutAndGoToLogin,
                          onToggleCollapse: () {
                            setState(() => _isSidebarCollapsed = !_isSidebarCollapsed);
                          },
                        ),
                      ),
                    Expanded(
                      child: Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: contentTopPadding),
                            child: _getView(selectedIndex, role),
                          ),
                          if (isMobile)
                            Positioned(
                              top: 12,
                              left: 12,
                              child: Builder(
                                builder: (context) => Material(
                                  color: Theme.of(context).cardColor,
                                  elevation: 2,
                                  shape: const CircleBorder(),
                                  child: IconButton(
                                    icon: const Icon(Icons.menu),
                                    onPressed: () => Scaffold.of(context).openDrawer(),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            });
          },
        );
      },
    );
  }

}

class _SessionAccess {
  final String role;
  final String status;

  const _SessionAccess({
    required this.role,
    required this.status,
  });
}

class _AccessDeniedView extends StatelessWidget {
  final String message;

  const _AccessDeniedView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 56),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => FirebaseAuth.instance.signOut(),
                  child: const Text('Logout'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
