import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'user_account_service.dart';
import 'user_system.dart';
const _teal = Color(0xFF0097A7);

class DashboardOverview extends StatefulWidget {
  const DashboardOverview({super.key});

  @override
  State<DashboardOverview> createState() => _DashboardOverviewState();
}

class _DashboardOverviewState extends State<DashboardOverview> {
  String? _selectedSystemId;

  String _safeString(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String _fullName(Map<String, dynamic> userData) {
    final first = _safeString(userData['first_name']).isNotEmpty
        ? _safeString(userData['first_name'])
        : _safeString(userData['firstName']);
    final last = _safeString(userData['last_name']).isNotEmpty
        ? _safeString(userData['last_name'])
        : _safeString(userData['lastName']);
    final name = '$first $last'.trim();
    return name.isEmpty ? _safeString(userData['email'], fallback: 'Unknown User') : name;
  }

  Map<String, dynamic> _asStringMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return <String, dynamic>{};
  }

  String _formatValue(dynamic value, {String suffix = ''}) {
    if (value == null) return '-';
    final text = value.toString().trim();
    if (text.isEmpty) return '-';
    return suffix.isEmpty ? text : '$text $suffix';
  }

  Map<String, dynamic> _pickSensorAverages(UserSystem system) {
    final averages = _asStringMap(system.sensorAverages);
    final daily = _asStringMap(averages['daily']);
    if (daily.isNotEmpty) return daily;
    if (averages.isEmpty) return <String, dynamic>{};
    final firstKey = averages.keys.first;
    return _asStringMap(averages[firstKey]);
  }

  DateTime _readTime(Map<String, dynamic> data) {
    final reportedAt = data['reported_at'];
    final createdAt = data['created_at'];
    final updatedAt = data['updated_at'];
    if (reportedAt is Timestamp) return reportedAt.toDate();
    if (createdAt is Timestamp) return createdAt.toDate();
    if (updatedAt is Timestamp) return updatedAt.toDate();
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;
    final currentUser = FirebaseAuth.instance.currentUser;
    final systemsStream = currentUser == null
        ? const Stream<List<UserSystem>>.empty()
        : UserAccountService.watchUserSystems(currentUser.uid);

    return StreamBuilder<List<UserSystem>>(
      stream: systemsStream,
      builder: (context, systemsSnapshot) {
        if (systemsSnapshot.hasError) {
          return Center(
            child: Text(
              'Error loading systems: ${systemsSnapshot.error}',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          );
        }

        final systems = systemsSnapshot.data ?? [];
        if (_selectedSystemId == null && systems.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _selectedSystemId = systems.first.id);
          });
        }
        final selectedSystem = systems.isEmpty
            ? null
            : systems.firstWhere(
                (system) => system.id == _selectedSystemId,
                orElse: () => systems.first,
              );
        final systemLabel = (UserSystem system) =>
            system.systemName.trim().isNotEmpty
                ? system.systemName
                : 'System ${system.id}';

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: firestore.collection('user').snapshots(),
          builder: (context, usersSnapshot) {
            if (usersSnapshot.hasError) {
              return Center(
                child: Text(
                  'Error loading users: ${usersSnapshot.error}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              );
            }
            if (usersSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: firestore.collection('support_tickets').snapshots(),
              builder: (context, ticketsSnapshot) {
                if (ticketsSnapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading tickets: ${ticketsSnapshot.error}',
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  );
                }
                if (ticketsSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: firestore.collection('master_sets').snapshots(),
                  builder: (context, setsSnapshot) {
                    if (setsSnapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error loading master sets: ${setsSnapshot.error}',
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                      );
                    }
                    if (setsSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final userDocs = usersSnapshot.data?.docs ?? [];
                    final ticketDocs = ticketsSnapshot.data?.docs ?? [];
                    final setDocs = setsSnapshot.data?.docs ?? [];

                    final usersByUserId = <String, Map<String, dynamic>>{};
                    for (final doc in userDocs) {
                      final data = doc.data();
                      final userId = _safeString(data['user_id'], fallback: doc.id);
                      if (userId.isNotEmpty) usersByUserId[userId] = data;
                    }

                    final totalUsers = userDocs.length;
                    final activeSystems = userDocs.where((doc) {
                      final status = _safeString(doc.data()['status']).toLowerCase();
                      return status == 'active';
                    }).length;
                    final openTickets = ticketDocs.where((doc) {
                      final status = _safeString(doc.data()['status']).toLowerCase();
                      return status == 'open';
                    }).length;
                    final totalMasterSets = setDocs.length;

                    final latestTickets = [...ticketDocs]
                      ..sort((a, b) => _readTime(b.data()).compareTo(_readTime(a.data())));
                    final latestThree = latestTickets.take(3).toList();

                    final isNarrow = MediaQuery.of(context).size.width < 1050;
                    final topCards = _buildSummaryGrid(
                      context: context,
                      totalUsers: totalUsers,
                      activeSystems: activeSystems,
                      openTickets: openTickets,
                      totalMasterSets: totalMasterSets,
                    );
                    final latestTicketsCard = _buildLatestTicketsCard(
                      context: context,
                      latestThree: latestThree,
                      usersByUserId: usersByUserId,
                    );

                    final systemAverages = selectedSystem == null
                        ? <String, dynamic>{}
                        : _pickSensorAverages(selectedSystem);
                    final harvestTotals = selectedSystem == null
                        ? <String, dynamic>{}
                        : _asStringMap(selectedSystem.harvestTotals);
                    final systemCards = selectedSystem == null
                        ? null
                        : _buildSystemOverview(
                            context: context,
                            system: selectedSystem,
                            sensorAverages: systemAverages,
                            harvestTotals: harvestTotals,
                            isNarrow: isNarrow,
                          );

                    final systemSelector = systems.length > 1
                        ? SizedBox(
                            width: 260,
                            child: DropdownButtonFormField<String>(
                              value: selectedSystem?.id,
                              decoration: const InputDecoration(
                                labelText: 'System',
                                border: OutlineInputBorder(),
                              ),
                              items: systems
                                  .map(
                                    (system) => DropdownMenuItem<String>(
                                      value: system.id,
                                      child: Text(systemLabel(system)),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _selectedSystemId = value);
                              },
                            ),
                          )
                        : null;

                    if (isNarrow) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (systemSelector != null) systemSelector,
                            if (systemSelector != null) const SizedBox(height: 12),
                            if (systemCards != null) systemCards,
                            if (systemCards != null) const SizedBox(height: 12),
                            topCards,
                            const SizedBox(height: 12),
                            latestTicketsCard,
                          ],
                        ),
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (systemSelector != null) systemSelector,
                          if (systemSelector != null) const SizedBox(height: 12),
                          if (systemCards != null) systemCards,
                          if (systemCards != null) const SizedBox(height: 12),
                          topCards,
                          const SizedBox(height: 12),
                          latestTicketsCard,
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSummaryGrid({
    required BuildContext context,
    required int totalUsers,
    required int activeSystems,
    required int openTickets,
    required int totalMasterSets,
  }) {
    final cards = [
      _MetricCardData(
        title: 'Total Users',
        value: totalUsers.toString(),
        subtitle: 'total number of users',
        icon: Icons.group,
      ),
      _MetricCardData(
        title: 'Active Systems',
        value: activeSystems.toString(),
        subtitle: "users with status 'Active'",
        icon: Icons.grid_view,
      ),
      _MetricCardData(
        title: 'Open Tickets',
        value: openTickets.toString(),
        subtitle: "tickets with status 'Open'",
        icon: Icons.support_agent,
      ),
      _MetricCardData(
        title: 'System Sets',
        value: totalMasterSets.toString(),
        subtitle: 'total number of available setups',
        icon: Icons.layers,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1300
            ? 4
            : width >= 900
                ? 2
                : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 128,
          ),
          itemBuilder: (context, index) => _metricCard(context, cards[index]),
        );
      },
    );
  }

  Widget _buildSystemOverview({
    required BuildContext context,
    required UserSystem system,
    required Map<String, dynamic> sensorAverages,
    required Map<String, dynamic> harvestTotals,
    required bool isNarrow,
  }) {
    final sensorRows = <String, String>{
      'Temp (\u00B0C)': _formatValue(sensorAverages['temp']),
      'pH': _formatValue(sensorAverages['ph']),
      'DO (mg/L)': _formatValue(sensorAverages['do']),
      'Ammonia (ppm)': _formatValue(sensorAverages['ammonia']),
      'Salinity (ppt)': _formatValue(sensorAverages['salinity']),
      'Turbidity (NTU)': _formatValue(sensorAverages['turbidity']),
    };
    final harvestRows = <String, String>{
      'System Status': system.isSystemActive ? 'Active' : 'Inactive',
      'Batch #': system.currentBatchNumber.toString(),
      'Fish Harvested': _formatValue(harvestTotals['total_fish_harvested']),
      'Avg Fish Size': _formatValue(harvestTotals['average_fish_size']),
      'Survival Rate': _formatValue(harvestTotals['survival_rate']),
      'Plant Batches': _formatValue(harvestTotals['total_plant_batches']),
      'Plants Harvested': _formatValue(harvestTotals['total_plants_harvested']),
      'Avg Yield/Batch': _formatValue(harvestTotals['average_yield_per_batch']),
    };

    final sensorCard = _buildSystemDataCard(
      context: context,
      title: 'Sensor Averages',
      rows: sensorRows,
    );
    final harvestCard = _buildSystemDataCard(
      context: context,
      title: 'Harvest Totals',
      rows: harvestRows,
    );

    if (isNarrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          sensorCard,
          const SizedBox(height: 12),
          harvestCard,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: sensorCard),
        const SizedBox(width: 12),
        Expanded(child: harvestCard),
      ],
    );
  }

  Widget _buildSystemDataCard({
    required BuildContext context,
    required String title,
    required Map<String, String> rows,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            ...rows.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        entry.key,
                        style: textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      entry.value,
                      style: textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricCard(BuildContext context, _MetricCardData card) {
    final textTheme = Theme.of(context).textTheme;
    final titleColor =
        textTheme.titleMedium?.color ?? Theme.of(context).colorScheme.onSurface;
    final subtitleColor = textTheme.bodySmall?.color ??
        Theme.of(context).colorScheme.onSurfaceVariant;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _teal, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: _teal.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(card.icon, color: _teal),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    card.title,
                    style: textTheme.labelLarge?.copyWith(color: titleColor),
                  ),
                  Text(
                    card.value,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  Text(
                    card.subtitle,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(color: subtitleColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLatestTicketsCard({
    required BuildContext context,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> latestThree,
    required Map<String, Map<String, dynamic>> usersByUserId,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _teal, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Latest Tickets',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: _teal,
                  ),
            ),
            const SizedBox(height: 8),
            if (latestThree.isEmpty)
              const Text('No recent tickets available.')
            else
              ...latestThree.map((doc) {
                final data = doc.data();
                final userId = _safeString(data['user_id'], fallback: '');
                final userData = usersByUserId[userId];
                final reportedBy = userData == null
                    ? _safeString(data['reported_by'], fallback: '-')
                    : _fullName(userData);
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.confirmation_number, color: _teal),
                  title: Text('Ticket ID: ${_safeString(data['ticket_id'], fallback: '-')}'),
                  subtitle: Text('Reported By: $reportedBy'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _teal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _safeString(data['priority'], fallback: '-'),
                      style: const TextStyle(
                        color: _teal,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _MetricCardData {
  const _MetricCardData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
}
