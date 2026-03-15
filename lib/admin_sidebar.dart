import 'package:flutter/material.dart';

import 'aquaponics_colors.dart';
import 'navigation_provider.dart';

class AdminSidebar extends StatelessWidget {
  final NavigationProvider navigationProvider;
  final bool collapsed;
  final bool showToggle;
  final bool isDrawer;
  final VoidCallback onToggleTheme;
  final VoidCallback onLogout;
  final ValueChanged<int>? onNavigate;
  final VoidCallback? onToggleCollapse;

  const AdminSidebar({
    super.key,
    required this.navigationProvider,
    required this.collapsed,
    required this.showToggle,
    required this.isDrawer,
    required this.onToggleTheme,
    required this.onLogout,
    this.onNavigate,
    this.onToggleCollapse,
  });

  @override
  Widget build(BuildContext context) {
    final navItems = <_NavItem>[
      const _NavItem(index: 0, icon: Icons.home_rounded, label: 'Dashboard'),
      const _NavItem(index: 1, icon: Icons.people_alt_rounded, label: 'Growers'),
      const _NavItem(index: 2, icon: Icons.layers_rounded, label: 'System Sets'),
      const _NavItem(index: 3, icon: Icons.support_agent_rounded, label: 'Support Tickets'),
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark ? const Color(0xFF1A2130) : const Color(0xFFE3E7EE);
    final brandTextColor = isDark ? Colors.white : const Color(0xFF111827);

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
              ? Text(
                  'Aquaponics',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: brandTextColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                )
              : Text(
                  'Aquaponics',
                  style: TextStyle(
                    color: brandTextColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            children: navItems
                .map(
                  (item) => _buildNavItem(
                    context,
                    item: item,
                    collapsed: collapsed,
                    isDrawer: isDrawer,
                    isDark: isDark,
                  ),
                )
                .toList(),
          ),
        ),
        Divider(color: dividerColor, height: 1),
        _buildBottomAction(
          context,
          icon: isDark ? Icons.dark_mode : Icons.light_mode,
          label: 'Theme',
          collapsed: collapsed,
          isDark: isDark,
          onTap: onToggleTheme,
        ),
        _buildBottomAction(
          context,
          icon: Icons.logout,
          label: 'Logout',
          color: AquaponicsColors.statusDanger,
          collapsed: collapsed,
          isDark: isDark,
          onTap: onLogout,
        ),
        if (showToggle)
          _buildBottomAction(
            context,
            icon: collapsed ? Icons.keyboard_double_arrow_right : Icons.keyboard_double_arrow_left,
            label: collapsed ? 'Expand' : 'Collapse',
            collapsed: collapsed,
            isDark: isDark,
            onTap: onToggleCollapse ?? () {},
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required _NavItem item,
    required bool collapsed,
    required bool isDrawer,
    required bool isDark,
  }) {
    final selected = navigationProvider.selectedIndex == item.index;
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
              if (onNavigate != null) {
                if (isDrawer) Navigator.of(context).pop();
                onNavigate!(item.index);
                return;
              }
              navigationProvider.setIndex(item.index);
              if (isDrawer) Navigator.of(context).pop();
            },
            child: SizedBox(
              height: 44,
              child: Row(
                mainAxisAlignment:
                    collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                children: [
                  if (!collapsed) const SizedBox(width: 12),
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

  Widget _buildBottomAction(
    BuildContext context, {
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
                if (!collapsed) const SizedBox(width: 12),
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
