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
      const _NavItem(
        index: 1,
        icon: Icons.people_alt_rounded,
        label: 'Growers',
      ),
      const _NavItem(
        index: 2,
        icon: Icons.mail_outline_rounded,
        label: 'Messages',
      ),
      const _NavItem(
        index: 3,
        icon: Icons.layers_rounded,
        label: 'System Sets',
      ),
      const _NavItem(
        index: 4,
        icon: Icons.support_agent_rounded,
        label: 'Support Tickets',
      ),
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark
        ? const Color(0xFF22352D)
        : AquaponicsColors.adminBorder;
    final brandTextColor = isDark
        ? Colors.white
        : AquaponicsColors.greenhouseText;

    return Column(
      children: [
        Container(
          height: 108,
          padding: EdgeInsets.symmetric(
            horizontal: collapsed ? 10 : 16,
            vertical: 14,
          ),
          alignment: collapsed ? Alignment.center : Alignment.centerLeft,
          decoration: BoxDecoration(
            gradient: isDark
                ? const LinearGradient(
                    colors: [Color(0xFF11231D), Color(0xFF173128)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : const LinearGradient(
                    colors: [Color(0xFFFDFEFC), Color(0xFFEAF2EE)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            border: Border(bottom: BorderSide(color: dividerColor)),
          ),
          child: collapsed
              ? Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AquaponicsColors.mossGreen,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: AquaponicsColors.greenhouseShadow,
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.water_drop_rounded,
                    color: Colors.white,
                  ),
                )
              : Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AquaponicsColors.mossGreen,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: AquaponicsColors.greenhouseShadow,
                            blurRadius: 18,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.water_drop_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Smart Aquaponics',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: brandTextColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
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
            icon: collapsed
                ? Icons.keyboard_double_arrow_right
                : Icons.keyboard_double_arrow_left,
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
    final defaultIconColor = isDark
        ? const Color(0xFFA4C0B2)
        : AquaponicsColors.greenhouseSubtext;
    final defaultTextColor = isDark
        ? const Color(0xFFE0ECE5)
        : AquaponicsColors.greenhouseText;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Tooltip(
        message: collapsed ? item.label : '',
        child: Material(
          color: selected
              ? (isDark ? const Color(0xFF1A3D36) : const Color(0xFFE9F4EE))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
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
              height: 48,
              child: Row(
                mainAxisAlignment: collapsed
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  if (selected && !collapsed)
                    Container(
                      width: 4,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white
                            : AquaponicsColors.mossGreen,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  if (!collapsed) const SizedBox(width: 12),
                  Icon(
                    item.icon,
                    size: 20,
                    color: selected
                        ? (isDark ? Colors.white : AquaponicsColors.mossGreen)
                        : defaultIconColor,
                  ),
                  if (!collapsed) ...[
                    const SizedBox(width: 12),
                    Text(
                      item.label,
                      style: TextStyle(
                        color: selected
                            ? (isDark
                                  ? Colors.white
                                  : AquaponicsColors.mossGreen)
                            : defaultTextColor,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w600,
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
              mainAxisAlignment: collapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                if (!collapsed) const SizedBox(width: 12),
                Icon(icon, size: 18, color: resolvedColor),
                if (!collapsed) ...[
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: TextStyle(
                      color: resolvedColor,
                      fontWeight: FontWeight.w600,
                    ),
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
