import 'package:flutter/material.dart';
import 'aquaponics_colors.dart';
import 'navigation_provider.dart';
import 'dashboard_view.dart';
import 'user_management_view.dart';
import 'support_tickets_view.dart';
import 'master_sets_view.dart';


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

  final List<String> _titles = [
    'System Overview',
    'User Management',
    'Master Sets',
    'Support Tickets',
  ];

  // Map to switch views based on selection
  Widget _getView(int index) {
    switch (index) {
      case 0: return const DashboardOverview();
      case 1: return const UserManagementView();
      case 2: return const MasterSetsView();
      case 3: return const SupportTicketsView();
      default: return const DashboardOverview();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _navigationProvider,
      builder: (context, child) {
      return LayoutBuilder(builder: (context, constraints) {
      final selectedIndex = _navigationProvider.selectedIndex < _titles.length
          ? _navigationProvider.selectedIndex
          : 0;
      final width = constraints.maxWidth;
      final isMobile = width < 600;
      final isTablet = width >= 600 && width < 1100;
      final isDesktop = width >= 1100;

      return Scaffold(
        appBar: AppBar(
          elevation: 0,
          automaticallyImplyLeading: isMobile,
          title: Text(
            _titles[selectedIndex],
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () {},
            ),
            const CircleAvatar(
              backgroundColor: AquaponicsColors.primaryAccent,
              child: Icon(Icons.person, color: Colors.white),
            ),
            const SizedBox(width: 16),
          ],
        ),
        drawer: isMobile
            ? Drawer(
                child: _buildNavigationContent(),
              )
            : null,
        body: Row(
          children: [
            if (isTablet)
              NavigationRail(
                selectedIndex: selectedIndex,
                onDestinationSelected: (int index) {
                  _navigationProvider.setIndex(index);
                },
                labelType: NavigationRailLabelType.none,
                destinations: const [
                  NavigationRailDestination(icon: Icon(Icons.dashboard), label: Text('Overview')),
                  NavigationRailDestination(icon: Icon(Icons.people), label: Text('Users')),
                  NavigationRailDestination(icon: Icon(Icons.layers), label: Text('Sets')),
                  NavigationRailDestination(icon: Icon(Icons.support_agent), label: Text('Support')),
                ],
              ),
            if (isDesktop)
              Container(
                width: 250,
                color: Theme.of(context).cardColor,
                child: _buildNavigationContent(),
              ),
            Expanded(
              child: _getView(selectedIndex),
            ),
          ],
        ),
      );
    });
      }
    );
  }

  Widget _buildNavigationContent() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                DrawerHeader(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AquaponicsColors.primaryAccent,
                        AquaponicsColors.brandGradientHeader
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.water_drop, size: 48, color: Colors.white),
                        const SizedBox(height: 10),
                        const Text(
                          'Smart Aquaponics',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Admin Console',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.dashboard),
                  title: const Text('Dashboard'),
                  selected: _navigationProvider.selectedIndex == 0,
                  selectedColor: AquaponicsColors.primaryAccent,
                  onTap: () => _navigationProvider.setIndex(0),
                ),
                ListTile(
                  leading: const Icon(Icons.people),
                  title: const Text('User Management'),
                  selected: _navigationProvider.selectedIndex == 1,
                  selectedColor: AquaponicsColors.primaryAccent,
                  onTap: () => _navigationProvider.setIndex(1),
                ),
                ListTile(
                  leading: const Icon(Icons.layers),
                  title: const Text('System Sets'),
                  selected: _navigationProvider.selectedIndex == 2,
                  selectedColor: AquaponicsColors.primaryAccent,
                  onTap: () => _navigationProvider.setIndex(2),
                ),
                ListTile(
                  leading: const Icon(Icons.support_agent),
                  title: const Text('Support Tickets'),
                  selected: _navigationProvider.selectedIndex == 3,
                  selectedColor: AquaponicsColors.primaryAccent,
                  onTap: () => _navigationProvider.setIndex(3),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Icon(
                widget.themeMode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode,
                color: AquaponicsColors.textSecondary,
              ),
              const SizedBox(width: 12),
              const Text('Dark Mode'),
              const Spacer(),
              Switch(
                value: widget.themeMode == ThemeMode.dark,
                onChanged: (val) {
                  widget.onThemeChanged(val ? ThemeMode.dark : ThemeMode.light);
                },
              ),
            ],
          ),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout, color: AquaponicsColors.statusDanger),
          title: const Text('Logout', style: TextStyle(color: AquaponicsColors.statusDanger)),
          onTap: () {
            // Handle logout
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
