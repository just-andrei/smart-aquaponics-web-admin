import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'aquaponics_colors.dart';
import 'navigation_provider.dart';
import 'dashboard_view.dart';
import 'user_management_view.dart';
import 'employee_management_view.dart';
import 'support_tickets_view.dart';
import 'master_sets_view.dart';
import 'user_account_service.dart';


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

  @override
  void initState() {
    super.initState();
    _accessFuture = _resolveAccess();
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
    final isAdmin = UserAccountService.isAdminRole(role);
    switch (index) {
      case 0: return const DashboardOverview();
      case 1: return UserManagementView(currentUserRole: role);
      case 2:
        if (isAdmin) return const EmployeeManagementView();
        return MasterSetsView(userRole: role);
      case 3:
        if (isAdmin) return MasterSetsView(userRole: role);
        return const SupportTicketsView();
      case 4: return const SupportTicketsView();
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

        final isAdmin = UserAccountService.isAdminRole(role);
        final titles = <String>[
          'System Overview',
          'Grower Management',
          if (isAdmin) 'Employee Management',
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
                endDrawer: isMobile
                    ? Drawer(
                        child: _buildSidebar(
                          isAdmin,
                          collapsed: false,
                          showToggle: false,
                          isDrawer: true,
                          isDark: isDark,
                        ),
                      )
                    : null,
                body: Row(
                  children: [
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
                              right: 12,
                              child: Builder(
                                builder: (context) => Material(
                                  color: Theme.of(context).cardColor,
                                  elevation: 2,
                                  shape: const CircleBorder(),
                                  child: IconButton(
                                    icon: const Icon(Icons.menu),
                                    onPressed: () => Scaffold.of(context).openEndDrawer(),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (showSidebar)
                      Container(
                        width: collapsedSidebar ? 76 : 248,
                        decoration: BoxDecoration(
                          color: sidebarBackground,
                          border: Border(
                            left: BorderSide(color: sidebarDividerColor),
                          ),
                        ),
                        child: _buildSidebar(
                          isAdmin,
                          collapsed: collapsedSidebar,
                          showToggle: isDesktop,
                          isDark: isDark,
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

  Widget _buildSidebar(
    bool isAdmin, {
    required bool collapsed,
    required bool showToggle,
    required bool isDark,
    bool isDrawer = false,
  }) {
    final setsIndex = isAdmin ? 3 : 2;
    final supportIndex = isAdmin ? 4 : 3;
    final navItems = <_NavItem>[
      const _NavItem(index: 0, icon: Icons.home_rounded, label: 'Dashboard'),
      const _NavItem(index: 1, icon: Icons.people_alt_rounded, label: 'Growers'),
      if (isAdmin)
        const _NavItem(index: 2, icon: Icons.badge_rounded, label: 'Employees'),
      _NavItem(index: setsIndex, icon: Icons.layers_rounded, label: 'System Sets'),
      _NavItem(index: supportIndex, icon: Icons.support_agent_rounded, label: 'Support Tickets'),
    ];

    final dividerColor = isDark ? const Color(0xFF1A2130) : const Color(0xFFE3E7EE);
    final brandTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final accentColor = AquaponicsColors.primaryAccent;

    return Column(
      children: [
        Container(
          height: 74,
          padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 16),
          alignment: collapsed ? Alignment.center : Alignment.centerLeft,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: dividerColor),
            ),
          ),
          child: collapsed
              ? Icon(Icons.water_drop, color: accentColor, size: 24)
              : Row(
                  children: [
                    Icon(Icons.water_drop, color: accentColor, size: 24),
                    const SizedBox(width: 10),
                    Text(
                      'Smart Aquaponics',
                      style: TextStyle(
                        color: brandTextColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            children: navItems
                .map((item) => _buildNavItem(
                      item: item,
                      collapsed: collapsed,
                      isDrawer: isDrawer,
                      isDark: isDark,
                    ))
                .toList(),
          ),
        ),
        Divider(color: dividerColor, height: 1),
        _buildBottomAction(
          icon: widget.themeMode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode,
          label: 'Theme',
          collapsed: collapsed,
          isDark: isDark,
          onTap: () {
            widget.onThemeChanged(
              widget.themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
            );
          },
        ),
        _buildBottomAction(
          icon: Icons.logout,
          label: 'Logout',
          color: AquaponicsColors.statusDanger,
          collapsed: collapsed,
          isDark: isDark,
          onTap: () async {
            try {
              await FirebaseAuth.instance.signOut();
            } on FirebaseAuthException catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(e.message ?? 'Logout failed')),
              );
            }
          },
        ),
        if (showToggle)
          _buildBottomAction(
            icon: collapsed ? Icons.keyboard_double_arrow_right : Icons.keyboard_double_arrow_left,
            label: collapsed ? 'Expand' : 'Collapse',
            collapsed: collapsed,
            isDark: isDark,
            onTap: () {
              setState(() => _isSidebarCollapsed = !_isSidebarCollapsed);
            },
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildNavItem({
    required _NavItem item,
    required bool collapsed,
    required bool isDrawer,
    required bool isDark,
  }) {
    final selected = _navigationProvider.selectedIndex == item.index;
    final defaultIconColor = isDark ? const Color(0xFFA4ACB9) : const Color(0xFF4B5563);
    final defaultTextColor = isDark ? const Color(0xFFD0D5DF) : const Color(0xFF111827);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Tooltip(
        message: collapsed ? item.label : '',
        child: Material(
          color: selected ? const Color(0xFF1F64D8) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              _navigationProvider.setIndex(item.index);
              if (isDrawer) Navigator.of(context).pop();
            },
            child: SizedBox(
              height: 44,
              child: Row(
                mainAxisAlignment:
                    collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                children: [
                  const SizedBox(width: 12),
                  Icon(
                    item.icon,
                    size: 20,
                    color: selected ? Colors.white : defaultIconColor,
                  ),
                  if (!collapsed) ...[
                    const SizedBox(width: 12),
                    Text(
                      item.label,
                      style: TextStyle(
                        color: selected ? Colors.white : defaultTextColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool collapsed,
    required bool isDark,
    Color color = const Color(0xFFA4ACB9),
  }) {
    final resolvedColor = color == const Color(0xFFA4ACB9)
        ? (isDark ? const Color(0xFFA4ACB9) : const Color(0xFF4B5563))
        : color;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            height: 42,
            child: Row(
              mainAxisAlignment:
                  collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                const SizedBox(width: 12),
                Icon(icon, size: 18, color: resolvedColor),
                if (!collapsed) ...[
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: TextStyle(color: resolvedColor, fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final int index;
  final IconData icon;
  final String label;

  const _NavItem({
    required this.index,
    required this.icon,
    required this.label,
  });
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
