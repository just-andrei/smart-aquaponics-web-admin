import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'admin_sidebar.dart';
import 'navigation_provider.dart';
import 'user_account_service.dart';
import 'user_system.dart';

const _teal = Color(0xFF0097A7);

class GrowerDetailsView extends StatefulWidget {
  final String userDocId;
  final String userId;
  final String currentUserRole;
  final NavigationProvider navigationProvider;
  final VoidCallback onToggleTheme;
  final VoidCallback onLogout;

  const GrowerDetailsView({
    super.key,
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


  Future<void> _showUpdateSystemDialog(UserSystem system) async {
    if (!_isAdmin) return;
    final nameController = TextEditingController(text: system.systemName);
    final hardwareController = TextEditingController(text: system.hardwareUid);
    final fishController = TextEditingController(text: system.activeFishId);
    final plantController = TextEditingController(text: system.activePlantId);
    final batchController = TextEditingController(
      text: system.currentBatchNumber == 0
          ? ''
          : system.currentBatchNumber.toString(),
    );
    final dateController = TextEditingController(
      text: _formatDate(system.ecosystemStartDate),
    );
    DateTime? selectedDate = system.ecosystemStartDate;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Update System'),
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
              const SizedBox(height: 12),
              TextField(
                controller: fishController,
                decoration: const InputDecoration(
                  labelText: 'Active Fish ID',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: plantController,
                decoration: const InputDecoration(
                  labelText: 'Active Plant ID',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: batchController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Batch #',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dateController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Start Date',
                  border: OutlineInputBorder(),
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked == null) return;
                  selectedDate = picked;
                  dateController.text = _formatDate(picked);
                },
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
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final data = <String, dynamic>{
      'system_name': nameController.text.trim(),
      'hardware_uid': hardwareController.text.trim(),
      'active_fish_id': fishController.text.trim(),
      'active_plant_id': plantController.text.trim(),
      'current_batch_number': int.tryParse(batchController.text.trim()) ?? 0,
      if (selectedDate != null) 'ecosystem_start_date': Timestamp.fromDate(selectedDate!),
      'updated_at': FieldValue.serverTimestamp(),
    };

    await UserAccountService.updateSystemData(
      widget.userDocId,
      system.id,
      data,
    );
  }

  Future<void> _confirmDeleteSystem(UserSystem system) async {
    if (!_isAdmin) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete System'),
        content: Text('Delete "${system.systemName}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await FirebaseFirestore.instance
        .collection('user')
        .doc(widget.userDocId)
        .collection('systems')
        .doc(system.id)
        .delete();
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
        .collection('user')
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
      SnackBar(content: Text('Provisioned "$systemName" (${doc.id}).')),
    );
  }

  void _handleBack() {
    widget.navigationProvider.setIndex(1);
    Navigator.of(context).pop();
  }

  Widget _buildDetailsBody(ColorScheme scheme) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('user')
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

        return StreamBuilder<List<UserSystem>>(
          stream: UserAccountService.watchUserSystems(widget.userDocId),
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
                      formatMetric: _formatMetric,
                      formatDate: _formatDate,
                      averages: system.sensorAverages,
                      userDocId: widget.userDocId,
                      plantNames: _plantNames,
                      fishNames: _fishNames,
                      isAdmin: _isAdmin,
                      onUpdate: () => _showUpdateSystemDialog(system),
                      onDelete: () => _confirmDeleteSystem(system),
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
                  color: scheme.background,
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
        color: scheme.background,
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
  final String email;
  final String phone;
  final String address;

  const _HeaderCard({
    required this.email,
    required this.phone,
    required this.address,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      elevation: 1.2,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Profile',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text('Email: $email', style: textTheme.bodyMedium),
              const SizedBox(height: 4),
              Text('Phone: $phone', style: textTheme.bodyMedium),
              const SizedBox(height: 4),
              Text('Address: $address', style: textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _SystemCard extends StatefulWidget {
  final UserSystem system;
  final String label;
  final String Function(dynamic value, {String fallback}) formatMetric;
  final String Function(dynamic value) formatDate;
  final Map<String, dynamic> averages;
  final String userDocId;
  final Map<String, String> plantNames;
  final Map<String, String> fishNames;
  final bool isAdmin;
  final VoidCallback onUpdate;
  final VoidCallback onDelete;

  const _SystemCard({
    required this.system,
    required this.label,
    required this.formatMetric,
    required this.formatDate,
    required this.averages,
    required this.userDocId,
    required this.plantNames,
    required this.fishNames,
    required this.isAdmin,
    required this.onUpdate,
    required this.onDelete,
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
              final actions = _SystemActionSection(
                onUpdate: widget.isAdmin ? widget.onUpdate : null,
                onDelete: widget.isAdmin ? widget.onDelete : null,
              );
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('user')
                    .doc(widget.userDocId)
                    .collection('systems')
                    .doc(system.id)
                    .collection('weekly_logs')
                    .orderBy('timestamp', descending: true)
                    .limit(1)
                    .snapshots(),
                builder: (context, snapshot) {
                  final latestDoc = snapshot.data?.docs.isNotEmpty == true
                      ? snapshot.data!.docs.first.data()
                      : null;
                  final lastLogTime =
                      latestDoc == null ? '-' : widget.formatDate(latestDoc['timestamp']);
                  final notes = latestDoc == null
                      ? 'No notes yet.'
                      : _formatNotes(latestDoc);
                  final healthStatus = latestDoc == null
                      ? ''
                      : _safeText(latestDoc['health_status']);

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
                            const SizedBox(height: 12),
                            actions,
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 4, child: details),
                            const SizedBox(width: 16),
                            Expanded(flex: 7, child: metrics),
                            const SizedBox(width: 16),
                            SizedBox(width: 170, child: actions),
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
                      _RecentStatusBanner(
                        healthStatus: healthStatus,
                        notes: notes,
                        lastLogTime: lastLogTime,
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  String _safeText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? '' : text;
  }

  String _formatNotes(Map<String, dynamic> data) {
    final notes = _safeText(data['notes']);
    if (notes.isNotEmpty) return notes;
    return 'No notes yet.';
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

class _SystemActionSection extends StatelessWidget {
  final VoidCallback? onUpdate;
  final VoidCallback? onDelete;

  const _SystemActionSection({
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton(
          onPressed: onUpdate,
          child: const Text('Update System'),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: onDelete,
          style: ElevatedButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          child: const Text('Delete System'),
        ),
      ],
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
                value: selectedRange,
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
