import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_theme_controller.dart';
import 'admin_sidebar.dart';
import 'navigation_provider.dart';
import 'dashboard_view.dart';
import 'user_management_view.dart';
import 'messages_view.dart';
import 'support_tickets_view.dart';
import 'master_sets_view.dart';
import 'compatibility_assistant_view.dart';
import 'user_account_service.dart';
import 'login.dart';
import 'aquaponics_colors.dart';

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
  late Future<UserSessionAccess> _accessFuture;
  bool _isSidebarCollapsed = false;

  void _toggleTheme() {
    toggleAppTheme(Theme.of(context).brightness);
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
            themeMode: appThemeMode.value,
            onThemeChanged: setAppThemeMode,
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message ?? 'Logout failed')));
    }
  }

  Future<void> _signOutAndGoToLogin() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      LoginPage.createRoute(
        themeMode: appThemeMode.value,
        onThemeChanged: setAppThemeMode,
      ),
    );
  }

  void _goToLogin() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      LoginPage.createRoute(
        themeMode: appThemeMode.value,
        onThemeChanged: setAppThemeMode,
      ),
    );
  }

  Future<UserSessionAccess> _resolveAccess() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const UserSessionAccess(
        uid: '',
        email: '',
        role: 'unknown',
        status: 'inactive',
        sourceCollection: '',
        profileData: null,
      );
    }
    return UserAccountService.resolveSessionAccessForUser(user);
  }

  // Map to switch views based on selection
  Widget _getView(int index, String role) {
    switch (index) {
      case 0:
        return const DashboardOverview();
      case 1:
        return UserManagementView(
          currentUserRole: role,
          navigationProvider: _navigationProvider,
          onLogout: _logoutAndGoToLogin,
          onToggleTheme: _toggleTheme,
        );
      case 2:
        return const MessagesView();
      case 3:
        return MasterSetsView(userRole: role);
      case 4:
        return const SupportTicketsView();
      case 5:
        return const CompatibilityAssistantView();
      default:
        return const DashboardOverview();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserSessionAccess>(
      future: _accessFuture,
      builder: (context, accessSnapshot) {
        if (accessSnapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (accessSnapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text(
                'Failed to load user access: ${accessSnapshot.error}',
              ),
            ),
          );
        }

        final access =
            accessSnapshot.data ??
            const UserSessionAccess(
              uid: '',
              email: '',
              role: 'unknown',
              status: 'inactive',
              sourceCollection: '',
              profileData: null,
            );
        final role = access.role;
        final status = access.status;

        if (!access.isAuthenticated) {
          return _AccessDeniedView(
            message:
                'Please sign in with an admin account to access the web dashboard.',
            actionLabel: 'Go to Login',
            onPressed: _goToLogin,
          );
        }

        if (!access.isAdmin) {
          return _AccessDeniedView(
            message:
                'This web app is for admin accounts only. Grower accounts should use the separate mobile app.',
            actionLabel: 'Sign Out',
            onPressed: _signOutAndGoToLogin,
          );
        }

        if (status != 'active') {
          return _AccessDeniedView(
            message: 'Your account is inactive. Contact an admin.',
            actionLabel: 'Sign Out',
            onPressed: _signOutAndGoToLogin,
          );
        }

        return ListenableBuilder(
          listenable: _navigationProvider,
          builder: (context, child) {
            return LayoutBuilder(
              builder: (context, constraints) {
                const tabCount = 6;
                final selectedIndex =
                    _navigationProvider.selectedIndex < tabCount
                    ? _navigationProvider.selectedIndex
                    : 0;
                final width = constraints.maxWidth;
                final isMobile = width < 600;
                final isTablet = width >= 600 && width < 1100;
                final isDesktop = width >= 1100;
                final showSidebar = isTablet || isDesktop;
                final collapsedSidebar = isTablet ? true : _isSidebarCollapsed;
                final isDark = Theme.of(context).brightness == Brightness.dark;
                final sidebarBackground = isDark
                    ? const Color(0xFF10211C)
                    : AquaponicsColors.offWhite;
                final sidebarDividerColor = isDark
                    ? const Color(0xFF22352D)
                    : AquaponicsColors.adminBorder;
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
                              setState(
                                () =>
                                    _isSidebarCollapsed = !_isSidebarCollapsed,
                              );
                            },
                          ),
                        ),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: isDark
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFF0D1815),
                                      Color(0xFF142520),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  )
                                : const LinearGradient(
                                    colors: [
                                      Color(0xFFF9FBF9),
                                      Color(0xFFF3F6F4),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                          ),
                          child: SafeArea(
                            child: Column(
                              children: [
                                if (isMobile)
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        8,
                                        8,
                                        8,
                                        0,
                                      ),
                                      child: IconButton(
                                        onPressed: () =>
                                            Scaffold.of(context).openDrawer(),
                                        icon: const Icon(Icons.menu_rounded),
                                        tooltip: 'Open menu',
                                      ),
                                    ),
                                  ),
                                Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      isMobile ? 8 : 12,
                                      0,
                                      isMobile ? 8 : 12,
                                      isMobile ? 8 : 12,
                                    ),
                                    child: _getView(selectedIndex, role),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _AccessDeniedView extends StatelessWidget {
  final String message;
  final String actionLabel;
  final VoidCallback onPressed;

  const _AccessDeniedView({
    required this.message,
    required this.actionLabel,
    required this.onPressed,
  });

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
                FilledButton(onPressed: onPressed, child: Text(actionLabel)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
