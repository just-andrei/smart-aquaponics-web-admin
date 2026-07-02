import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'aquaponics_colors.dart';

class DashboardOverview extends StatelessWidget {
  const DashboardOverview({super.key});

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
    return name.isEmpty
        ? _safeString(userData['email'], fallback: 'Unknown User')
        : name;
  }

  DateTime _readTime(Map<String, dynamic> data) {
    final v = data['reported_at'] ?? data['created_at'] ?? data['updated_at'];
    if (v is Timestamp) return v.toDate();
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _relativeDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return '1d ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }

  String _ticketDisplayId(Map<String, dynamic> data) {
    final ticketNumber = data['ticketNumber'];
    if (ticketNumber != null) {
      final parsed = int.tryParse(ticketNumber.toString());
      if (parsed != null && parsed > 0) return parsed.toString();
    }
    final legacyId = _safeString(data['ticket_id'], fallback: '-');
    return legacyId;
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

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
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
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
                  final uid = _safeString(data['user_id'], fallback: doc.id);
                  if (uid.isNotEmpty) usersByUserId[uid] = data;
                }

                final totalUsers = userDocs.length;
                final activeUsers = userDocs.where((doc) {
                  return _safeString(doc.data()['status']).toLowerCase() ==
                      'active';
                }).length;

                final openTickets = ticketDocs.where((doc) {
                  return _safeString(doc.data()['status']).toLowerCase() ==
                      'open';
                }).length;
                final urgentTickets = ticketDocs.where((doc) {
                  return _safeString(doc.data()['priority']).toLowerCase() ==
                      'urgent';
                }).length;

                final latestTickets = [...ticketDocs]
                  ..sort(
                    (a, b) =>
                        _readTime(b.data()).compareTo(_readTime(a.data())),
                  );
                final latestThree = latestTickets.take(3).toList();

                final recentUsers = [...userDocs]
                  ..sort((a, b) {
                    final aId =
                        int.tryParse(_safeString(a.data()['user_id'])) ?? 0;
                    final bId =
                        int.tryParse(_safeString(b.data()['user_id'])) ?? 0;
                    return bId.compareTo(aId);
                  });
                final recentThree = recentUsers.take(3).toList();

                final isNarrow = MediaQuery.of(context).size.width < 1050;

                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    isNarrow ? 12.0 : 16.0,
                    8.0,
                    isNarrow ? 12.0 : 16.0,
                    16.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildNarrativeCard(
                        context: context,
                        totalUsers: totalUsers,
                        activeUsers: activeUsers,
                        openTickets: openTickets,
                        urgentTickets: urgentTickets,
                        totalMasterSets: setDocs.length,
                      ),
                      const SizedBox(height: 16),
                      _buildMetricsRow(
                        context: context,
                        totalUsers: totalUsers,
                        activeUsers: activeUsers,
                        openTickets: openTickets,
                        urgentTickets: urgentTickets,
                        totalMasterSets: setDocs.length,
                      ),
                      const SizedBox(height: 16),
                      if (isNarrow) ...[
                        _buildGrowerDistributionCard(
                          context: context,
                          active: activeUsers,
                          total: totalUsers,
                        ),
                        const SizedBox(height: 16),
                        _buildLatestTicketsCard(
                          context: context,
                          latestThree: latestThree,
                          usersByUserId: usersByUserId,
                        ),
                        const SizedBox(height: 16),
                        _buildRecentGrowersCard(
                          context: context,
                          recentThree: recentThree,
                        ),
                      ] else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: _buildLatestTicketsCard(
                                context: context,
                                latestThree: latestThree,
                                usersByUserId: usersByUserId,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: Column(
                                children: [
                                  _buildGrowerDistributionCard(
                                    context: context,
                                    active: activeUsers,
                                    total: totalUsers,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildRecentGrowersCard(
                                    context: context,
                                    recentThree: recentThree,
                                  ),
                                ],
                              ),
                            ),
                          ],
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

  Widget _buildNarrativeCard({
    required BuildContext context,
    required int totalUsers,
    required int activeUsers,
    required int openTickets,
    required int urgentTickets,
    required int totalMasterSets,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.26)
        : const Color(0xFF163A5A).withValues(alpha: 0.12);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.18);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: isDark
            ? const LinearGradient(
                colors: [Color(0xFF102033), Color(0xFF16314B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFF0F9D8A), Color(0xFF2F6FED)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: isDark ? 18 : 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Wrap(
        runSpacing: 18,
        spacing: 18,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 520,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Operations snapshot',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  urgentTickets > 0
                      ? 'There are $urgentTickets urgent support issue${urgentTickets == 1 ? '' : 's'} needing admin attention.'
                      : 'Your grower network is stable, and the admin platform is ready for day-to-day operations.',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '$activeUsers of $totalUsers growers are active, $openTickets support ticket${openTickets == 1 ? '' : 's'} are open, and $totalMasterSets system set${totalMasterSets == 1 ? '' : 's'} are available for deployment.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _statusPill('Growers', '$activeUsers active', Colors.white),
              _statusPill('Support', '$openTickets open', Colors.white),
              _statusPill('Templates', '$totalMasterSets sets', Colors.white),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsRow({
    required BuildContext context,
    required int totalUsers,
    required int activeUsers,
    required int openTickets,
    required int urgentTickets,
    required int totalMasterSets,
  }) {
    const primaryBlue = AquaponicsColors.adminInfo;
    const successGreen = Color(0xFF16A34A);
    const teal = AquaponicsColors.adminHighlight;
    final ticketAccent = urgentTickets > 0
        ? const Color(0xFFDC2626)
        : openTickets > 0
        ? const Color(0xFFD97706)
        : successGreen;

    final cards = [
      _MetricCardData(
        title: 'Total Growers',
        value: totalUsers.toString(),
        subtitle: '$activeUsers active',
        icon: Icons.people_alt_rounded,
        accentColor: primaryBlue,
      ),
      _MetricCardData(
        title: 'Active Growers',
        value: activeUsers.toString(),
        subtitle: 'of $totalUsers registered',
        icon: Icons.check_circle_outline_rounded,
        accentColor: successGreen,
      ),
      _MetricCardData(
        title: 'Open Tickets',
        value: openTickets.toString(),
        subtitle: urgentTickets > 0
            ? '$urgentTickets urgent'
            : 'no urgent tickets',
        icon: Icons.support_agent_rounded,
        accentColor: ticketAccent,
      ),
      _MetricCardData(
        title: 'System Sets',
        value: totalMasterSets.toString(),
        subtitle: 'configured setups',
        icon: Icons.layers_rounded,
        accentColor: teal,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 1200
            ? 4
            : constraints.maxWidth >= 700
            ? 2
            : 1;
        final cardHeight = constraints.maxWidth >= 1200
            ? 176.0
            : constraints.maxWidth >= 700
            ? 168.0
            : 156.0;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: cardHeight,
          ),
          itemBuilder: (ctx, i) => _metricCard(ctx, cards[i]),
        );
      },
    );
  }

  Widget _metricCard(BuildContext context, _MetricCardData card) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 154;
        final iconPadding = compact ? 8.0 : 10.0;
        final verticalPadding = compact ? 12.0 : 16.0;
        final titleStyle = textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          fontSize: compact ? 12.5 : null,
        );
        final valueStyle = textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: scheme.onSurface,
          height: 1.05,
          fontSize: compact ? 26 : null,
        );
        final subtitleStyle = textTheme.labelLarge?.copyWith(
          color: card.accentColor,
          fontWeight: FontWeight.w600,
          fontSize: compact ? 11 : 12,
        );

        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF101A26) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF1D2A39)
                  : AquaponicsColors.adminBorder,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 14 : 16,
              vertical: verticalPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(iconPadding),
                      decoration: BoxDecoration(
                        color: card.accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        card.icon,
                        color: card.accentColor,
                        size: compact ? 20 : 22,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: card.accentColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 10 : 14),
                Text(card.title, style: titleStyle, maxLines: 2),
                SizedBox(height: compact ? 4 : 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(card.value, style: valueStyle, maxLines: 1),
                    SizedBox(width: compact ? 8 : 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          card.subtitle,
                          style: subtitleStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statusPill(String label, String value, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: RichText(
        text: TextSpan(
          style: TextStyle(color: textColor, height: 1.2),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrowerDistributionCard({
    required BuildContext context,
    required int active,
    required int total,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final inactive = total - active;
    const successColor = Color(0xFF16A34A);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Grower Status Distribution',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            if (total > 0) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 8,
                  child: Row(
                    children: [
                      if (active > 0)
                        Flexible(
                          flex: active,
                          child: Container(color: successColor),
                        ),
                      if (inactive > 0)
                        Flexible(
                          flex: inactive,
                          child: Container(color: scheme.outlineVariant),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _LegendDot(color: successColor, label: 'Active  $active'),
                  const SizedBox(width: 20),
                  _LegendDot(
                    color: scheme.outlineVariant,
                    label: 'Inactive  $inactive',
                  ),
                ],
              ),
            ] else
              Text(
                'No growers registered yet.',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }

  static const _categoryIcons = <String, IconData>{
    'sensor': Icons.sensors_rounded,
    'actuator': Icons.settings_input_component_rounded,
    'fish': Icons.set_meal_rounded,
    'plant': Icons.eco_rounded,
  };

  Widget _buildLatestTicketsCard({
    required BuildContext context,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> latestThree,
    required Map<String, Map<String, dynamic>> usersByUserId,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Text(
              'Latest Support Tickets',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          if (latestThree.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'No active tickets.',
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ...latestThree.map((doc) {
              final data = doc.data();
              final uid = _safeString(data['user_id'], fallback: '');
              final userData = usersByUserId[uid];
              final reportedBy = userData == null
                  ? _safeString(data['reported_by'], fallback: '-')
                  : _fullName(userData);
              final priority = _safeString(
                data['priority'],
                fallback: 'Normal',
              );
              final category = _safeString(
                data['category'],
                fallback: '',
              ).toLowerCase();
              final ticketId = _ticketDisplayId(data);
              final isUrgent = priority.toLowerCase() == 'urgent';

              final priorityBg = isUrgent
                  ? (isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2))
                  : (isDark
                        ? const Color(0xFF0C2A4A)
                        : const Color(0xFFEFF6FF));
              final priorityTextColor = isUrgent
                  ? const Color(0xFFDC2626)
                  : const Color(0xFF0369A1);
              final rowAccent = isUrgent
                  ? const Color(0xFFDC2626)
                  : const Color(0xFF0369A1);

              final catIcon =
                  _categoryIcons[category] ?? Icons.help_outline_rounded;

              return Container(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: rowAccent, width: 3),
                    bottom: BorderSide(
                      color: scheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 20, 12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(
                          '#$ticketId',
                          style: textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(catIcon, size: 15, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          reportedBy,
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: priorityBg,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          priority,
                          style: textTheme.labelSmall?.copyWith(
                            color: priorityTextColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _relativeDate(_readTime(data)),
                        style: textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildRecentGrowersCard({
    required BuildContext context,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> recentThree,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Text(
              'Recently Registered',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          if (recentThree.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No growers registered.',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ...recentThree.map((doc) {
              final data = doc.data();
              final name = _fullName(data);
              final status = _safeString(data['status'], fallback: 'active');
              final isActive = status.toLowerCase() == 'active';

              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 20, 10),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: _avatarColor(doc.id),
                      child: Text(
                        _initials(name),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        name,
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? (isDark
                                  ? const Color(0xFF14532D)
                                  : const Color(0xFFDCFCE7))
                            : scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        isActive ? 'Active' : 'Inactive',
                        style: textTheme.labelSmall?.copyWith(
                          color: isActive
                              ? const Color(0xFF16A34A)
                              : scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _MetricCardData {
  const _MetricCardData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
}



