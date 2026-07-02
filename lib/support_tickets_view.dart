import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'aquaponics_colors.dart';

const _primaryBlue = AquaponicsColors.waterBlue;
const _urgentRed = Color(0xFFDC2626);
const _successGreen = AquaponicsColors.freshGreen;

const _categoryIcons = <String, IconData>{
  'sensor': Icons.sensors_rounded,
  'actuator': Icons.settings_input_component_rounded,
  'fish': Icons.set_meal_rounded,
  'plant': Icons.eco_rounded,
};

String _firebaseErrorMessage(Object error) {
  if (error is FirebaseException) {
    return error.message ?? error.code;
  }
  return error.toString();
}

class SupportTicketsView extends StatefulWidget {
  const SupportTicketsView({super.key});

  @override
  State<SupportTicketsView> createState() => _SupportTicketsViewState();
}

class _SupportTicketsViewState extends State<SupportTicketsView> {
  static const _all = 'All';

  final _activeSearchCtrl = TextEditingController();
  final _historySearchCtrl = TextEditingController();

  String _activePriorityFilter = _all;
  String _activeCategoryFilter = _all;
  String _historyPriorityFilter = _all;
  String _historyCategoryFilter = _all;

  String _safeString(dynamic value, {String fallback = '-'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  BoxDecoration _panelDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? const Color(0xCC173128) : AquaponicsColors.glassAccent,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: isDark
            ? const Color(0xFF28463E)
            : AquaponicsColors.adminBorder,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.08),
          blurRadius: 22,
          offset: Offset(0, 10),
        ),
      ],
    );
  }

  String _safeNamePart(dynamic value) => _safeString(value, fallback: '');

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  String _formatDateTime(dynamic value) {
    if (value is Timestamp) {
      final dt = value.toDate();
      return '${dt.year}-${_twoDigits(dt.month)}-${_twoDigits(dt.day)} ${_twoDigits(dt.hour)}:${_twoDigits(dt.minute)}';
    }
    return _safeString(value);
  }

  String _reportedByFromUser(Map<String, dynamic>? userData) {
    if (userData == null) return '';
    final first = _safeNamePart(userData['first_name']).isNotEmpty
        ? _safeNamePart(userData['first_name'])
        : _safeNamePart(userData['firstName']);
    final last = _safeNamePart(userData['last_name']).isNotEmpty
        ? _safeNamePart(userData['last_name'])
        : _safeNamePart(userData['lastName']);
    return '$first $last'.trim();
  }

  String _numericUserIdFromUser(Map<String, dynamic>? userData) {
    final raw = _safeString(userData?['user_id'], fallback: '');
    if (raw.isEmpty) return '';
    return raw;
  }

  String _displayUserId(Map<String, dynamic> ticketData, Map<String, dynamic>? userData) {
    final fromTicket = _safeString(ticketData['user_id'], fallback: '');
    final fromUser = _numericUserIdFromUser(userData);
    if (fromUser.isNotEmpty) return fromUser;
    return fromTicket;
  }

  String _ticketDisplayId(Map<String, dynamic> data) {
    final ticketNumber = data['ticketNumber'];
    if (ticketNumber != null) {
      final parsed = int.tryParse(ticketNumber.toString());
      if (parsed != null && parsed > 0) return parsed.toString();
    }
    final legacyId = _safeString(data['ticket_id'], fallback: '');
    if (legacyId.isEmpty) return '-';
    return legacyId;
  }

  int _nextTicketNumber(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> activeDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> historyDocs,
  ) {
    var maxNumericId = 0;
    for (final doc in [...activeDocs, ...historyDocs]) {
      final data = doc.data();
      final raw = data['ticketNumber']?.toString().trim() ??
          _safeString(data['ticket_id'], fallback: '');
      final parsed = int.tryParse(raw);
      if (parsed != null && parsed > maxNumericId) {
        maxNumericId = parsed;
      }
    }
    return maxNumericId + 1;
  }

  bool _matchesFilters({
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
    required Map<String, Map<String, dynamic>> usersByUserId,
    required String searchQuery,
    required String priorityFilter,
    required String categoryFilter,
  }) {
    final data = doc.data();
    final userId = _safeString(data['user_id'], fallback: '');
    final userData = usersByUserId[userId];
    final reportedByFromUser = _reportedByFromUser(userData);
    final reportedBy = reportedByFromUser.isEmpty
        ? _safeString(data['reported_by'], fallback: '')
        : reportedByFromUser;
    final ticketId = _ticketDisplayId(data);
    final priority = _safeString(data['priority'], fallback: '');
    final category = _safeString(data['category'], fallback: '');

    if (priorityFilter != _all && priority != priorityFilter) return false;
    if (categoryFilter != _all && category != categoryFilter) return false;

    if (searchQuery.isEmpty) return true;
    final query = searchQuery.toLowerCase();
    return ticketId.toLowerCase().contains(query) || reportedBy.toLowerCase().contains(query);
  }

  @override
  void dispose() {
    _activeSearchCtrl.dispose();
    _historySearchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;

    return DefaultTabController(
      length: 2,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: firestore.collection('support_tickets').snapshots(),
        builder: (context, activeSnapshot) {
          if (activeSnapshot.hasError) {
            return Center(
              child: Text(
                'Error loading tickets: ${activeSnapshot.error}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            );
          }
          if (activeSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: firestore.collection('ticket_history').snapshots(),
            builder: (context, historySnapshot) {
              if (historySnapshot.hasError) {
                return Center(
                  child: Text(
                    'Error loading ticket history: ${historySnapshot.error}',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                );
              }
              if (historySnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

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

                  final activeDocs = activeSnapshot.data?.docs ?? [];
                  final historyDocs = historySnapshot.data?.docs ?? [];
                  final userDocs = usersSnapshot.data?.docs ?? [];

                  final usersByUserId = <String, Map<String, dynamic>>{};
                  for (final doc in userDocs) {
                    final data = doc.data();
                    final numericUserId = _numericUserIdFromUser(data);
                    if (numericUserId.isNotEmpty) {
                      usersByUserId[numericUserId] = data;
                    }
                    // Legacy fallback for tickets that stored document id as user_id.
                    usersByUserId[doc.id] = data;
                  }

                  final nextTicketId = _nextTicketNumber(activeDocs, historyDocs).toString();

                  return Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        alignment: Alignment.centerLeft,
                        child: const TabBar(
                          isScrollable: true,
                          labelColor: _primaryBlue,
                          indicatorColor: _primaryBlue,
                          labelStyle: TextStyle(fontWeight: FontWeight.w600),
                          tabs: [
                            Tab(text: 'Active Tickets'),
                            Tab(text: 'Ticket History'),
                          ],
                        ),
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _buildActiveTab(
                              context: context,
                              activeDocs: activeDocs,
                              usersByUserId: usersByUserId,
                              nextTicketId: nextTicketId,
                            ),
                            _buildHistoryTab(
                              context: context,
                              historyDocs: historyDocs,
                              usersByUserId: usersByUserId,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
  Widget _buildActiveTab({
    required BuildContext context,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> activeDocs,
    required Map<String, Map<String, dynamic>> usersByUserId,
    required String nextTicketId,
  }) {
    return Align(
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: _panelDecoration(context),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _searchField(controller: _activeSearchCtrl, label: 'Search by grower or ticket #'),
                  _filterDropdown(
                    label: 'Priority',
                    value: _activePriorityFilter,
                    items: const [_all, 'Urgent', 'Normal'],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _activePriorityFilter = value);
                    },
                  ),
                  _filterDropdown(
                    label: 'Category',
                    value: _activeCategoryFilter,
                    items: const [_all, 'Sensor', 'Actuator', 'Fish', 'Plant'],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _activeCategoryFilter = value);
                    },
                  ),
                  FilledButton.icon(
                    onPressed: () => _showTicketDialog(context: context, nextTicketId: nextTicketId),
                    style: FilledButton.styleFrom(
                      backgroundColor: AquaponicsColors.mossGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Create Ticket'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _activeSearchCtrl,
              builder: (context, value, _) {
                final query = value.text.trim();
                final filteredTickets = activeDocs
                    .where(
                      (doc) => _matchesFilters(
                        doc: doc,
                        usersByUserId: usersByUserId,
                        searchQuery: query,
                        priorityFilter: _activePriorityFilter,
                        categoryFilter: _activeCategoryFilter,
                      ),
                    )
                    .toList();

                if (activeDocs.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No active support tickets found.',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  );
                }

                if (filteredTickets.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No active tickets match the current search/filter.',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  );
                }

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: filteredTickets
                      .map(
                        (doc) => _ticketCard(
                          context: context,
                          doc: doc,
                          usersByUserId: usersByUserId,
                          showActions: true,
                          onEdit: () => _showTicketDialog(context: context, document: doc, nextTicketId: nextTicketId),
                          onResolve: () => _confirmAndResolveTicket(context: context, doc: doc),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab({
    required BuildContext context,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> historyDocs,
    required Map<String, Map<String, dynamic>> usersByUserId,
  }) {
    final resolvedDocs = historyDocs
        .where((doc) => _safeString(doc.data()['status'], fallback: 'Resolved').toLowerCase() == 'resolved')
        .toList();

    return Align(
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: _panelDecoration(context),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _searchField(controller: _historySearchCtrl, label: 'Search by grower or ticket #'),
                  _filterDropdown(
                    label: 'Priority',
                    value: _historyPriorityFilter,
                    items: const [_all, 'Urgent', 'Normal'],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _historyPriorityFilter = value);
                    },
                  ),
                  _filterDropdown(
                    label: 'Category',
                    value: _historyCategoryFilter,
                    items: const [_all, 'Sensor', 'Actuator', 'Fish', 'Plant'],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _historyCategoryFilter = value);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _historySearchCtrl,
              builder: (context, value, _) {
                final query = value.text.trim();
                final filteredTickets = resolvedDocs
                    .where(
                      (doc) => _matchesFilters(
                        doc: doc,
                        usersByUserId: usersByUserId,
                        searchQuery: query,
                        priorityFilter: _historyPriorityFilter,
                        categoryFilter: _historyCategoryFilter,
                      ),
                    )
                    .toList();

                if (resolvedDocs.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No resolved tickets in history.',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  );
                }

                if (filteredTickets.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No history tickets match the current search/filter.',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  );
                }

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: filteredTickets
                      .map(
                        (doc) => _ticketCard(
                          context: context,
                          doc: doc,
                          usersByUserId: usersByUserId,
                          showActions: false,
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchField({required TextEditingController controller, required String label}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: 320,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.search_rounded, color: AquaponicsColors.mossGreen),
          suffixIcon: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => controller.clear(),
          ),
          filled: true,
          fillColor: isDark ? const Color(0xFF10211C) : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: isDark
                  ? const Color(0xFF28463E)
                  : AquaponicsColors.adminBorder,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AquaponicsColors.mossGreen, width: 1.4),
          ),
        ),
      ),
    );
  }

  Widget _ticketCard({
    required BuildContext context,
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
    required Map<String, Map<String, dynamic>> usersByUserId,
    required bool showActions,
    VoidCallback? onEdit,
    VoidCallback? onResolve,
  }) {
    final data = doc.data();
    final storedUserId = _safeString(data['user_id'], fallback: '');
    final userData = usersByUserId[storedUserId];
    final userId = _displayUserId(data, userData);
    final reportedByFromUser = _reportedByFromUser(userData);
    final reportedBy = reportedByFromUser.isEmpty
        ? _safeString(data['reported_by'])
        : reportedByFromUser;
    final priority = _safeString(data['priority']);
    final status = _safeString(
      data['status'],
      fallback: showActions ? 'Open' : 'Resolved',
    );
    final category = _safeString(data['category']).toLowerCase();
    final isUrgent = priority.toLowerCase() == 'urgent';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final leftBorderColor = showActions
        ? (isUrgent ? _urgentRed : _primaryBlue)
        : _successGreen;

    final priorityBg = isUrgent
        ? (isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2))
        : (isDark ? const Color(0xFF0C2A4A) : const Color(0xFFEFF6FF));
    final priorityTextColor = isUrgent ? _urgentRed : const Color(0xFF0369A1);

    final statusBg = showActions
        ? (isDark ? const Color(0xFF0C2A4A) : const Color(0xFFEFF6FF))
        : (isDark ? const Color(0xFF14532D) : const Color(0xFFDCFCE7));
    final statusTextColor =
        showActions ? const Color(0xFF0369A1) : _successGreen;

    final catIcon =
        _categoryIcons[category] ?? Icons.help_outline_rounded;

    return SizedBox(
      width: 420,
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: leftBorderColor),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(catIcon, size: 15, color: scheme.onSurfaceVariant),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _safeString(data['title']),
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
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
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: statusBg,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                status,
                                style: textTheme.labelSmall?.copyWith(
                                  color: statusTextColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _kv('Ticket ID', '#${_ticketDisplayId(data)}'),
                        _kv('Category', _safeString(data['category'])),
                        _kv('Reported At', _formatDateTime(data['reported_at'])),
                        _kv('Reported By', reportedBy),
                        _kv('User ID', userId),
                        if (!showActions)
                          _kv(
                            'Resolved At',
                            _formatDateTime(data['resolved_at']),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          _safeString(data['description']),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        if (showActions) ...[
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                onPressed: onEdit,
                                child: const Text('Edit'),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.icon(
                                onPressed: onResolve,
                                icon: const Icon(Icons.check_rounded, size: 15),
                                label: const Text('Resolve'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: _successGreen,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _filterDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: 150,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        items: items.map((item) => DropdownMenuItem<String>(value: item, child: Text(item))).toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: isDark ? const Color(0xFF10211C) : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: isDark
                  ? const Color(0xFF28463E)
                  : AquaponicsColors.adminBorder,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AquaponicsColors.mossGreen, width: 1.4),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  Widget _kv(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text('$key: $value', style: const TextStyle(fontSize: 13)),
    );
  }

  void _showTicketDialog({
    required BuildContext context,
    required String nextTicketId,
    DocumentSnapshot<Map<String, dynamic>>? document,
  }) {
    showDialog(
      context: context,
      builder: (_) => _TicketDialog(document: document, nextTicketId: nextTicketId),
    );
  }

  Future<void> _confirmAndResolveTicket({
    required BuildContext context,
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
  }) async {
    final shouldResolve = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Resolve Ticket'),
        content: const Text('Is the problem resolved?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('No')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: _primaryBlue, foregroundColor: Colors.white),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (shouldResolve != true) return;

    try {
      final firestore = FirebaseFirestore.instance;
      final sourceRef = firestore.collection('support_tickets').doc(doc.id);
      final historyRef = firestore.collection('ticket_history').doc(doc.id);
      final sourceSnapshot = await sourceRef.get();
      if (!sourceSnapshot.exists || sourceSnapshot.data() == null) return;

      final sourceData = sourceSnapshot.data()!;
      final batch = firestore.batch();
      batch.set(historyRef, {
        ...sourceData,
        'status': 'Resolved',
        'resolved_at': FieldValue.serverTimestamp(),
        'archived_at': FieldValue.serverTimestamp(),
        'archived_from': 'support_tickets',
        'original_doc_id': doc.id,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      batch.delete(sourceRef);
      await batch.commit();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ticket moved to history.')));
    } on Object catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Resolve failed: ${_firebaseErrorMessage(e)}')),
      );
    }
  }
}
class _TicketDialog extends StatefulWidget {
  const _TicketDialog({required this.nextTicketId, this.document});

  final DocumentSnapshot<Map<String, dynamic>>? document;
  final String nextTicketId;

  @override
  State<_TicketDialog> createState() => _TicketDialogState();
}

class _TicketDialogState extends State<_TicketDialog> {
  static const _categories = ['Sensor', 'Actuator', 'Fish', 'Plant'];
  static const _priorities = ['Urgent', 'Normal'];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _reportedByCtrl;
  late final TextEditingController _userSearchCtrl;

  String? _selectedCategory;
  String? _selectedPriority;
  String? _selectedUserId;
  bool _didHydrateInitialUser = false;

  bool get _isEditing => widget.document != null;

  @override
  void initState() {
    super.initState();
    final data = widget.document?.data() ?? <String, dynamic>{};
    _titleCtrl = TextEditingController(text: data['title']?.toString() ?? '');
    _descriptionCtrl = TextEditingController(text: data['description']?.toString() ?? '');
    _reportedByCtrl = TextEditingController(text: data['reported_by']?.toString() ?? '');
    _userSearchCtrl = TextEditingController(text: data['user_id']?.toString() ?? '');

    _selectedCategory = _readValidOption(data['category']?.toString(), _categories);
    _selectedPriority = _readValidOption(data['priority']?.toString(), _priorities);
    _selectedUserId = data['user_id']?.toString();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _reportedByCtrl.dispose();
    _userSearchCtrl.dispose();
    super.dispose();
  }

  String? _readValidOption(String? value, List<String> options) {
    if (value == null) return null;
    return options.contains(value) ? value : null;
  }

  String _safeString(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String _safeNamePart(dynamic value) => _safeString(value);

  String _resolvedUserId(Map<String, dynamic> userData) {
    final raw = _safeString(userData['user_id']);
    return raw;
  }

  String _fullName(Map<String, dynamic> userData) {
    final first = _safeNamePart(userData['first_name']).isNotEmpty
        ? _safeNamePart(userData['first_name'])
        : _safeNamePart(userData['firstName']);
    final last = _safeNamePart(userData['last_name']).isNotEmpty
        ? _safeNamePart(userData['last_name'])
        : _safeNamePart(userData['lastName']);
    return '$first $last'.trim();
  }

  void _hydrateInitialUser(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    if (_didHydrateInitialUser) return;
    _didHydrateInitialUser = true;

    final initial = _selectedUserId?.trim() ?? '';
    if (initial.isEmpty) return;

    for (final doc in docs) {
      final data = doc.data();
      final rawUserId = _safeString(data['user_id']);
      if (doc.id == initial || rawUserId == initial) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _applyUserSelection(doc);
        });
        return;
      }
    }
  }

  void _applyUserSelection(QueryDocumentSnapshot<Map<String, dynamic>> userDoc) {
    final data = userDoc.data();
    final name = _fullName(data);
    final userId = _resolvedUserId(data);
    if (userId.isEmpty) return;
    setState(() {
      _selectedUserId = userId;
      _reportedByCtrl.text = name;
      _userSearchCtrl.text = name.isEmpty ? userId : '$userId - $name';
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedUserId == null || _selectedUserId!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a valid user from search results')),
      );
      return;
    }

    final existingData = widget.document?.data() ?? const <String, dynamic>{};
    final currentTicketNumber = _isEditing
        ? ((existingData['ticketNumber'] ?? existingData['ticket_id'])?.toString().trim() ?? '')
        : widget.nextTicketId;
    final currentTicketId = _isEditing
        ? (existingData['ticket_id']?.toString().trim() ?? currentTicketNumber)
        : widget.nextTicketId;
    final payload = <String, dynamic>{
      'title': _titleCtrl.text.trim(),
      'category': _selectedCategory,
      'description': _descriptionCtrl.text.trim(),
      'priority': _selectedPriority,
      'status': 'Open',
      'ticket_id': currentTicketId.isEmpty ? widget.nextTicketId : currentTicketId,
      'ticketNumber': int.tryParse(
            currentTicketNumber.isEmpty ? widget.nextTicketId : currentTicketNumber,
          ) ??
          int.parse(widget.nextTicketId),
      'user_id': _selectedUserId,
      'reported_by': _reportedByCtrl.text.trim(),
      'updated_at': FieldValue.serverTimestamp(),
    };

    try {
      if (_isEditing) {
        await widget.document!.reference.update(payload);
      } else {
        await FirebaseFirestore.instance.collection('support_tickets').add({
          ...payload,
          'reported_at': FieldValue.serverTimestamp(),
          'created_at': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) Navigator.pop(context);
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: ${_firebaseErrorMessage(e)}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayTicketId = _isEditing
        ? ((widget.document?.data()?['ticketNumber'] ?? widget.document?.data()?['ticket_id'])?.toString() ?? widget.nextTicketId)
        : widget.nextTicketId;

    return Dialog(
      child: Container(
        width: 620,
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isEditing ? 'Edit Ticket' : 'Create Ticket',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFB0BEC5)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('Ticket ID: #$displayTicketId', style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 16),
                _textField(_titleCtrl, 'Title'),
                const SizedBox(height: 12),
                _dropdownField(
                  label: 'Category',
                  value: _selectedCategory,
                  items: _categories,
                  onChanged: (v) => setState(() => _selectedCategory = v),
                ),
                const SizedBox(height: 12),
                _textField(_descriptionCtrl, 'Description', maxLines: 4),
                const SizedBox(height: 12),
                _dropdownField(
                  label: 'Priority',
                  value: _selectedPriority,
                  items: _priorities,
                  onChanged: (v) => setState(() => _selectedPriority = v),
                ),
                const SizedBox(height: 12),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance.collection('user').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Text(
                        'User search failed: ${snapshot.error}',
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final userDocs = snapshot.data!.docs;
                    _hydrateInitialUser(userDocs);

                    final search = _userSearchCtrl.text.trim().toLowerCase();
                    final matches = search.isEmpty
                        ? <QueryDocumentSnapshot<Map<String, dynamic>>>[]
                        : userDocs
                            .where((doc) {
                              final data = doc.data();
                              final fullName = _fullName(data).toLowerCase();
                              final rawUserId = _safeString(data['user_id']).toLowerCase();
                              if (rawUserId.isEmpty) return false;
                              return fullName.contains(search) || rawUserId.contains(search);
                            })
                            .take(8)
                            .toList();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _userSearchCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Search User (user_id or name)',
                            prefixIcon: Icon(Icons.search, color: _primaryBlue),
                            border: OutlineInputBorder(),
                            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _primaryBlue)),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: _primaryBlue, width: 2),
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: (_) => (_selectedUserId == null || _selectedUserId!.isEmpty)
                              ? 'Select a user from search results'
                              : null,
                        ),
                        if (matches.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            constraints: const BoxConstraints(maxHeight: 200),
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFCFD8DC)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: matches.length,
                              separatorBuilder: (_, index) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final doc = matches[index];
                                final data = doc.data();
                                final name = _fullName(data);
                                final email = _safeString(data['email']);
                                final userId = _resolvedUserId(data);
                                return ListTile(
                                  dense: true,
                                  title: Text(name.isEmpty ? userId : name),
                                  subtitle: Text('$userId | $email'),
                                  onTap: () => _applyUserSelection(doc),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                _textField(_reportedByCtrl, 'Reported By', readOnly: true),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: _save,
                      style: FilledButton.styleFrom(backgroundColor: _primaryBlue, foregroundColor: Colors.white),
                      child: Text(_isEditing ? 'Save Changes' : 'Create'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFB0BEC5))),
      focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: _primaryBlue, width: 2)),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      readOnly: readOnly,
      decoration: _inputDecoration(label),
      validator: readOnly ? null : (v) => v == null || v.trim().isEmpty ? 'Required' : null,
    );
  }

  Widget _dropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      items: items.map((item) => DropdownMenuItem<String>(value: item, child: Text(item))).toList(),
      onChanged: onChanged,
      iconEnabledColor: _primaryBlue,
      decoration: _inputDecoration(label),
      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
    );
  }
}
