import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'admin_sidebar.dart';
import 'grower_growth_status_history_section.dart';
import 'grower_harvest_records_section.dart';
import 'grower_monitoring_history_section.dart';
import 'navigation_provider.dart';
import 'user_account_service.dart';
import 'user_system.dart';


class GrowerDetailsView extends StatefulWidget {
  final String userCollection;
  final String userDocId;
  final String userId;
  final String currentUserRole;
  final NavigationProvider navigationProvider;
  final VoidCallback onToggleTheme;
  final VoidCallback onLogout;

  const GrowerDetailsView({
    super.key,
    required this.userCollection,
    required this.userDocId,
    required this.userId,
    required this.currentUserRole,
    required this.navigationProvider,
    required this.onToggleTheme,
    required this.onLogout,
  });

  @override
  State<GrowerDetailsView> createState() => _GrowerDetailsViewState();
}

class _GrowerDetailsViewState extends State<GrowerDetailsView> {
  bool _isSidebarCollapsed = false;
  final Map<String, String> _plantNames = {};
  final Map<String, String> _fishNames = {};

  String _safeString(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String _systemLabel(UserSystem system) {
    final name = system.systemName.trim();
    return name.isEmpty ? 'System ${system.id}' : name;
  }

  bool get _isAdmin => UserAccountService.isAdminRole(widget.currentUserRole);

  @override
  void initState() {
    super.initState();
    widget.navigationProvider.setIndex(1);
    _preloadLibraryNames();
  }

  Future<void> _preloadLibraryNames() async {
    try {
      final plantsSnap = await FirebaseFirestore.instance.collection('plants').get();
      final aquacultureSnap =
          await FirebaseFirestore.instance.collection('aquaculture').get();

      final plantNames = <String, String>{};
      for (final doc in plantsSnap.docs) {
        final data = doc.data();
        final id = _safeString(data['plant_id'], fallback: '');
        final name = _safeString(data['name'], fallback: '');
        if (id.isNotEmpty && name.isNotEmpty) {
          plantNames[id] = name;
        }
      }

      final fishNames = <String, String>{};
      for (final doc in aquacultureSnap.docs) {
        final data = doc.data();
        final id = _safeString(data['fish_id'], fallback: '');
        final name = _safeString(data['name'], fallback: '');
        if (id.isNotEmpty && name.isNotEmpty) {
          fishNames[id] = name;
        }
      }

      if (!mounted) return;
      setState(() {
        _plantNames
          ..clear()
          ..addAll(plantNames);
        _fishNames
          ..clear()
          ..addAll(fishNames);
      });
    } catch (_) {}
  }

  String _generateProvisionCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatMetric(dynamic value, {String fallback = '-'}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }
  String _formatDate(dynamic value) {
    DateTime? date;
    if (value is DateTime) {
      date = value;
    } else if (value is Timestamp) {
      date = value.toDate();
    } else if (value is String) {
      date = DateTime.tryParse(value);
    }
    if (date == null) return '-';
    return DateFormat('MM/dd/yyyy').format(date);
  }


  Future<void> _showProvisionDialog() async {
    if (!_isAdmin) return;
    final nameController = TextEditingController();
    final hardwareController = TextEditingController();
    final scheme = Theme.of(context).colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Provision New Unit'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'System Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: hardwareController,
                decoration: const InputDecoration(
                  labelText: 'Hardware UID',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: scheme.primary),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final systemName = nameController.text.trim();
    final hardwareUid = hardwareController.text.trim();
    if (systemName.isEmpty || hardwareUid.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('System name and hardware UID are required.')),
      );
      return;
    }

    final provisionCode = _generateProvisionCode();
    final doc = FirebaseFirestore.instance
        .collection(widget.userCollection)
        .doc(widget.userDocId)
        .collection('systems')
        .doc();

    await doc.set({
      'system_name': systemName,
      'hardware_uid': hardwareUid,
      'provision_code': provisionCode,
      'is_system_active': false,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Provisioned "$systemName". Provision code: $provisionCode',
        ),
        duration: const Duration(seconds: 10),
        action: SnackBarAction(
          label: 'Close',
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );
  }

  void _handleBack() {
    widget.navigationProvider.setIndex(1);
    Navigator.of(context).pop();
  }

  Widget _buildDetailsBody(ColorScheme scheme) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(widget.userCollection)
          .doc(widget.userDocId)
          .snapshots(),
      builder: (context, userSnapshot) {
        if (userSnapshot.hasError) {
          return Center(
            child: Text(
              'Error loading user profile: ${userSnapshot.error}',
              style: TextStyle(color: scheme.error),
            ),
          );
        }
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = userSnapshot.data?.data() ?? <String, dynamic>{};
        final email = _safeString(data['email'], fallback: widget.userId);
        final phone = _safeString(data['phone_num'], fallback: '-');
        final address = _safeString(data['address'], fallback: '-');
        final directName = _safeString(data['name']);
        final firstName = _safeString(data['first_name']);
        final lastName = _safeString(data['last_name']);
        final fullName = directName.isNotEmpty
            ? directName
            : '$firstName $lastName'.trim();

        return StreamBuilder<List<UserSystem>>(
          stream: UserAccountService.watchUserSystems(
            widget.userDocId,
            userCollection: widget.userCollection,
          ),
          builder: (context, systemsSnapshot) {
            if (systemsSnapshot.hasError) {
              return Center(
                child: Text(
                  'Error loading systems: ${systemsSnapshot.error}',
                  style: TextStyle(color: scheme.error),
                ),
              );
            }
            if (systemsSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final systems = systemsSnapshot.data ?? [];
            final totalFish = systems.fold<int>(
              0,
              (acc, system) =>
                  acc + _toInt(system.harvestTotals['total_fish_harvested']),
            );
            final totalPlants = systems.fold<int>(
              0,
              (acc, system) =>
                  acc + _toInt(system.harvestTotals['total_plants_harvested']),
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HeaderCard(
                  name: fullName,
                  email: email,
                  phone: phone,
                  address: address,
                ),
                const SizedBox(height: 16),
                _SummaryCard(
                  totalFish: totalFish,
                  totalPlants: totalPlants,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Systems',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    if (_isAdmin)
                      FilledButton.icon(
                        onPressed: _showProvisionDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Provision New Unit'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (systems.isEmpty)
                  Text(
                    'No systems provisioned for this user.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  )
                else
                  ...systems.map(
                    (system) => _SystemCard(
                      system: system,
                      label: _systemLabel(system),
                      growerUid: widget.userDocId,
                      growerName: fullName.isEmpty ? email : fullName,
                      growerEmail: email,
                      formatMetric: _formatMetric,
                      formatDate: _formatDate,
                      averages: system.sensorAverages,
                      userCollection: widget.userCollection,
                      userDocId: widget.userDocId,
                      plantNames: _plantNames,
                      fishNames: _fishNames,
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = width < 600;
        final isTablet = width >= 600 && width < 1100;
        final isDesktop = width >= 1100;
        final showSidebar = isTablet || isDesktop;
        final collapsedSidebar = isTablet ? true : _isSidebarCollapsed;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final sidebarBackground = isDark ? const Color(0xFF0C1018) : const Color(0xFFF7F9FC);
        final sidebarDividerColor = isDark ? const Color(0xFF1A2130) : const Color(0xFFE3E7EE);
        void handleNavigate(int index) {
          widget.navigationProvider.setIndex(index);
          Navigator.of(context).pop();
        }

        return Scaffold(
          drawer: isMobile
              ? Drawer(
                  child: AdminSidebar(
                    navigationProvider: widget.navigationProvider,
                    collapsed: false,
                    showToggle: false,
                    isDrawer: true,
                    onToggleTheme: widget.onToggleTheme,
                    onLogout: widget.onLogout,
                    onNavigate: handleNavigate,
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
                    navigationProvider: widget.navigationProvider,
                    collapsed: collapsedSidebar,
                    showToggle: isDesktop,
                    isDrawer: false,
                    onToggleTheme: widget.onToggleTheme,
                    onLogout: widget.onLogout,
                    onNavigate: handleNavigate,
                    onToggleCollapse: () {
                      setState(() => _isSidebarCollapsed = !_isSidebarCollapsed);
                    },
                  ),
                ),
              Expanded(
                child: Container(
                  color: scheme.surface,
                  child: Column(
                    children: [
                      _DetailsHeader(
                        onBack: _handleBack,
                        showMenu: isMobile,
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: _buildDetailsBody(scheme),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DetailsHeader extends StatelessWidget {
  final VoidCallback onBack;
  final bool showMenu;

  const _DetailsHeader({
    required this.onBack,
    required this.showMenu,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          bottom: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          if (showMenu)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: onBack,
          ),
          const SizedBox(width: 8),
          Text(
            'Grower Details',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String name;
  final String email;
  final String phone;
  final String address;

  const _HeaderCard({
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
  });

  Color _avatarColor(String seed) {
    const colors = [
      Color(0xFF1F64D8),
      Color(0xFF0EA5A0),
      Color(0xFF7C3AED),
      Color(0xFFD97706),
      Color(0xFF16A34A),
      Color(0xFFDC2626),
    ];
    final hash = seed.codeUnits.fold(0, (prev, c) => prev + c);
    return colors[hash % colors.length];
  }

  String _initials(String n) {
    final parts = n.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      elevation: 0,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: _avatarColor(name.isEmpty ? email : name),
              child: Text(
                _initials(name.isEmpty ? email : name),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (name.isNotEmpty)
                    Text(
                      name,
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                  const SizedBox(height: 8),
                  _ProfileRow(icon: Icons.email_outlined, label: email),
                  const SizedBox(height: 4),
                  _ProfileRow(
                    icon: Icons.phone_outlined,
                    label: phone == '-' ? 'Not provided' : phone,
                  ),
                  const SizedBox(height: 4),
                  _ProfileRow(
                    icon: Icons.location_on_outlined,
                    label: address == '-' ? 'Not provided' : address,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: scheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _SystemCard extends StatefulWidget {
  final UserSystem system;
  final String label;
  final String growerUid;
  final String growerName;
  final String growerEmail;
  final String Function(dynamic value, {String fallback}) formatMetric;
  final String Function(dynamic value) formatDate;
  final Map<String, dynamic> averages;
  final String userCollection;
  final String userDocId;
  final Map<String, String> plantNames;
  final Map<String, String> fishNames;

  const _SystemCard({
    required this.system,
    required this.label,
    required this.growerUid,
    required this.growerName,
    required this.growerEmail,
    required this.formatMetric,
    required this.formatDate,
    required this.averages,
    required this.userCollection,
    required this.userDocId,
    required this.plantNames,
    required this.fishNames,
  });

  @override
  State<_SystemCard> createState() => _SystemCardState();
}

class _SystemCardState extends State<_SystemCard> {
  String _selectedRange = 'daily';

  String _resolveName(String id, Map<String, String> library) {
    final key = id.trim();
    if (key.isEmpty || key == '-') return 'Not Set';
    return library[key] ?? 'Unknown ($key)';
  }

  String _displayName(String id, Map<String, String> library) {
    final key = id.trim();
    if (key.isEmpty || key == '-') return '';
    return library[key] ?? key;
  }

  Map<String, dynamic> _averagesForRange() {
    final source = widget.averages;
    if (source.isEmpty) return <String, dynamic>{};
    final range = source[_selectedRange];
    if (range is Map) {
      return range.map((key, val) => MapEntry(key.toString(), val));
    }
    return source;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final system = widget.system;
    final statusLabel = system.isSystemActive ? 'Claimed' : 'Unclaimed';
    final statusColor = system.isSystemActive
        ? scheme.primaryContainer
        : scheme.surfaceContainerHighest;
    final statusTextColor = system.isSystemActive
        ? scheme.onPrimaryContainer
        : scheme.onSurfaceVariant;

    return Card(
      elevation: 1.2,
      margin: const EdgeInsets.only(bottom: 12),
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.primary, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 820;
              final details = _SystemDetailsSection(
                label: widget.label,
                statusLabel: statusLabel,
                statusColor: statusColor,
                statusTextColor: statusTextColor,
              );
              final metrics = _SystemMetricsSection(
                system: system,
                formatMetric: widget.formatMetric,
                formatDate: widget.formatDate,
                fishNames: widget.fishNames,
                plantNames: widget.plantNames,
                resolveName: _resolveName,
              );
              final core = isCompact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        details,
                        const SizedBox(height: 12),
                        metrics,
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 4, child: details),
                        const SizedBox(width: 16),
                        Expanded(flex: 7, child: metrics),
                      ],
                    );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  core,
                  const SizedBox(height: 12),
                  _SensorAveragesSection(
                    selectedRange: _selectedRange,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _selectedRange = value);
                    },
                    averages: _averagesForRange(),
                  ),
                  const SizedBox(height: 12),
                  GrowerSystemMonitoringSection(
                    userCollection: widget.userCollection,
                    userDocId: widget.userDocId,
                    growerUid: widget.growerUid,
                    growerName: widget.growerName,
                    growerEmail: widget.growerEmail,
                    systemId: system.id,
                    systemLabel: widget.label,
                    fallbackHardwareUid: system.hardwareUid,
                    fallbackIsSystemActive: system.isSystemActive,
                  ),
                  const SizedBox(height: 12),
                  GrowerHarvestRecordsSection(
                    userCollection: widget.userCollection,
                    userDocId: widget.userDocId,
                    growerUid: widget.growerUid,
                    growerName: widget.growerName,
                    growerEmail: widget.growerEmail,
                    systemId: system.id,
                    systemName: widget.label,
                    hardwareUid: system.hardwareUid,
                  ),
                  const SizedBox(height: 12),
                  GrowerGrowthStatusHistorySection(
                    userCollection: widget.userCollection,
                    userDocId: widget.userDocId,
                    growerUid: widget.growerUid,
                    growerName: widget.growerName,
                    growerEmail: widget.growerEmail,
                    systemId: system.id,
                    systemName: widget.label,
                    hardwareUid: system.hardwareUid,
                    defaultPlantName: _displayName(
                      system.activePlantId,
                      widget.plantNames,
                    ),
                    defaultSpeciesName: _displayName(
                      system.activeFishId,
                      widget.fishNames,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SystemDetailsSection extends StatelessWidget {
  final String label;
  final String statusLabel;
  final Color statusColor;
  final Color statusTextColor;

  const _SystemDetailsSection({
    required this.label,
    required this.statusLabel,
    required this.statusColor,
    required this.statusTextColor,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'Status: $statusLabel',
            style: textTheme.labelSmall?.copyWith(
              color: statusTextColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _SystemMetricsSection extends StatelessWidget {
  final UserSystem system;
  final String Function(dynamic value, {String fallback}) formatMetric;
  final String Function(dynamic value) formatDate;
  final Map<String, String> plantNames;
  final Map<String, String> fishNames;
  final String Function(String id, Map<String, String> library) resolveName;

  const _SystemMetricsSection({
    required this.system,
    required this.formatMetric,
    required this.formatDate,
    required this.plantNames,
    required this.fishNames,
    required this.resolveName,
  });

  static const double _growthChipMaxWidth = 200;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _MetricsColumn(
        title: 'Config',
        chips: [
          _ParameterItem(
            label: 'Batch #',
            value: system.currentBatchNumber == 0
                ? '-'
                : system.currentBatchNumber.toString(),
          ),
          _ParameterItem(
            label: 'Start Date',
            value: formatDate(system.ecosystemStartDate),
          ),
          _ParameterItem(
            label: 'UID',
            value: system.hardwareUid.isNotEmpty
                ? system.hardwareUid
                : 'Pending',
          ),
          if (!system.isSystemActive && system.provisionCode.isNotEmpty)
            _ParameterItem(label: 'Code', value: system.provisionCode),
        ],
      ),
      _MetricsColumn(
        title: 'Growth',
        chips: [
          _ParameterItem(
            label: 'Fish',
            value: resolveName(system.activeFishId, fishNames),
            maxWidth: _growthChipMaxWidth,
            overflow: TextOverflow.ellipsis,
          ),
          _ParameterItem(
            label: 'Plant',
            value: resolveName(system.activePlantId, plantNames),
            maxWidth: _growthChipMaxWidth,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      _MetricsColumn(
        title: 'Yields',
        chips: [
          _ParameterItem(
            label: 'Fish Yield',
            value: formatMetric(
              system.harvestTotals['total_fish_harvested'],
            ),
          ),
          _ParameterItem(
            label: 'Plant Yield',
            value: formatMetric(
              system.harvestTotals['total_plants_harvested'],
            ),
          ),
        ],
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 820;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: metrics
              .map(
                (column) => SizedBox(
                  width: isNarrow
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 32) / 3,
                  child: column,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _SensorAveragesSection extends StatelessWidget {
  final String selectedRange;
  final ValueChanged<String?> onChanged;
  final Map<String, dynamic> averages;

  const _SensorAveragesSection({
    required this.selectedRange,
    required this.onChanged,
    required this.averages,
  });

  String _formatValue(dynamic value) {
    if (value == null) return '-';
    final text = value.toString().trim();
    return text.isEmpty ? '-' : text;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Sensor Averages',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            SizedBox(
              width: 150,
              child: DropdownButtonFormField<String>(
                initialValue: selectedRange,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: scheme.outlineVariant),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'daily', child: Text('Daily')),
                  DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                  DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                ],
                onChanged: onChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _ParameterItem(label: 'Temp', value: _formatValue(averages['temp'])),
            _ParameterItem(label: 'pH', value: _formatValue(averages['ph'])),
            _ParameterItem(label: 'DO', value: _formatValue(averages['do'])),
            _ParameterItem(
              label: 'Salinity',
              value: _formatValue(averages['salinity']),
            ),
            _ParameterItem(
              label: 'Turbidity',
              value: _formatValue(averages['turbidity']),
            ),
            _ParameterItem(
              label: 'Ammonia',
              value: _formatValue(averages['ammonia']),
            ),
          ],
        ),
      ],
    );
  }
}

// ignore: unused_element
class _RecentStatusBanner extends StatelessWidget {
  final String healthStatus;
  final String notes;
  final String lastLogTime;

  const _RecentStatusBanner({
    required this.healthStatus,
    required this.notes,
    required this.lastLogTime,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = healthStatus.trim().toLowerCase();
    final color = status.contains('healthy') || status.contains('good')
        ? scheme.tertiaryContainer
        : status.contains('critical') || status.contains('unhealthy')
            ? scheme.errorContainer
            : scheme.secondaryContainer;
    final textColor = status.contains('healthy') || status.contains('good')
        ? scheme.onTertiaryContainer
        : status.contains('critical') || status.contains('unhealthy')
            ? scheme.onErrorContainer
            : scheme.onSecondaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              healthStatus.isEmpty ? 'Unknown' : healthStatus,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recent Status • $lastLogTime',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  notes,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricsColumn extends StatelessWidget {
  final String title;
  final List<Widget> chips;

  const _MetricsColumn({
    required this.title,
    required this.chips,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: chips,
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int totalFish;
  final int totalPlants;

  const _SummaryCard({
    required this.totalFish,
    required this.totalPlants,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      elevation: 1.2,
      color: scheme.surface,
      shadowColor: scheme.shadow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.primary, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lifetime Performance',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.set_meal, color: scheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          totalFish.toString(),
                          style: textTheme.titleLarge?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Fish Harvested',
                          style: textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.local_florist, color: scheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          totalPlants.toString(),
                          style: textTheme.titleLarge?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Plants Harvested',
                          style: textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParameterItem extends StatelessWidget {
  const _ParameterItem({
    required this.label,
    required this.value,
    this.maxWidth,
    this.overflow,
  });

  final String label;
  final String value;
  final double? maxWidth;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: BoxConstraints(
        minWidth: 140,
        maxWidth: maxWidth ?? double.infinity,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Text(
        '$label: $value',
        maxLines: overflow == null ? null : 1,
        overflow: overflow,
        softWrap: overflow == null,
        style: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
