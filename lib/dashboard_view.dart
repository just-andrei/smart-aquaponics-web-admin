import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

const _teal = Color(0xFF0097A7);

class DashboardOverview extends StatefulWidget {
  const DashboardOverview({super.key});

  @override
  State<DashboardOverview> createState() => _DashboardOverviewState();
}

class _DashboardOverviewState extends State<DashboardOverview> {
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

                if (isNarrow) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
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

  Widget _metricCard(BuildContext context, _MetricCardData card) {
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
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: const Color(0xFF455A64),
                        ),
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
                    style: Theme.of(context).textTheme.bodySmall,
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
