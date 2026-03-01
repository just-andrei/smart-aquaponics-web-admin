import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

const _teal = Color(0xFF0097A7);

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

  final _searchCtrl = TextEditingController();
  String _priorityFilter = _all;
  String _categoryFilter = _all;
  String _statusFilter = _all;

  String _safeString(dynamic value, {String fallback = '-'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String _safeNamePart(dynamic value) => _safeString(value, fallback: '');

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  String _formatReportedAt(dynamic value) {
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

  int _nextTicketId(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    var maxNumericId = 0;
    for (final doc in docs) {
      final raw = _safeString(doc.data()['ticket_id'], fallback: '');
      final parsed = int.tryParse(raw);
      if (parsed != null && parsed > maxNumericId) {
        maxNumericId = parsed;
      }
    }
    if (maxNumericId > 0) {
      return maxNumericId + 1;
    }
    return 0 + docs.length + 1;
  }

  bool _matchesFilters({
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
    required Map<String, Map<String, dynamic>> usersByUserId,
    required String searchQuery,
  }) {
    final data = doc.data();
    final userId = _safeString(data['user_id'], fallback: '');
    final userData = usersByUserId[userId];
    final reportedByFromUser = _reportedByFromUser(userData);
    final reportedBy = reportedByFromUser.isEmpty
        ? _safeString(data['reported_by'], fallback: '')
        : reportedByFromUser;
    final ticketId = _safeString(data['ticket_id'], fallback: '');
    final priority = _safeString(data['priority'], fallback: '');
    final category = _safeString(data['category'], fallback: '');
    final status = _safeString(data['status'], fallback: '');

    if (_priorityFilter != _all && priority != _priorityFilter) return false;
    if (_categoryFilter != _all && category != _categoryFilter) return false;
    if (_statusFilter != _all && status != _statusFilter) return false;

    if (searchQuery.isEmpty) return true;
    final query = searchQuery.toLowerCase();
    return ticketId.toLowerCase().contains(query) ||
        reportedBy.toLowerCase().contains(query);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;
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

        final ticketDocs = ticketsSnapshot.data?.docs ?? [];
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

            final userDocs = usersSnapshot.data?.docs ?? [];
            final usersByUserId = <String, Map<String, dynamic>>{};
            for (final doc in userDocs) {
              final data = doc.data();
              final userId = _safeString(data['user_id'], fallback: doc.id);
              if (userId.isNotEmpty) {
                usersByUserId[userId] = data;
              }
            }

            return Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: 280,
                          child: TextField(
                            controller: _searchCtrl,
                            decoration: InputDecoration(
                              labelText: 'Search by Reported By or Ticket ID',
                              prefixIcon: const Icon(Icons.search, color: _teal),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () => _searchCtrl.clear(),
                              ),
                              border: const OutlineInputBorder(),
                              enabledBorder: const OutlineInputBorder(
                                borderSide: BorderSide(color: _teal),
                              ),
                              focusedBorder: const OutlineInputBorder(
                                borderSide: BorderSide(color: _teal, width: 2),
                              ),
                            ),
                          ),
                        ),
                        _filterDropdown(
                          label: 'Priority',
                          value: _priorityFilter,
                          items: const [_all, 'Urgent', 'Normal'],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _priorityFilter = value);
                          },
                        ),
                        _filterDropdown(
                          label: 'Category',
                          value: _categoryFilter,
                          items: const [_all, 'Sensor', 'Actuator', 'Fish', 'Plant'],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _categoryFilter = value);
                          },
                        ),
                        _filterDropdown(
                          label: 'Status',
                          value: _statusFilter,
                          items: const [_all, 'Open', 'Resolved'],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _statusFilter = value);
                          },
                        ),
                        FilledButton.icon(
                          onPressed: () => _showTicketDialog(
                            context: context,
                            usersById: usersByUserId,
                            nextTicketId: _nextTicketId(ticketDocs).toString(),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: _teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                          icon: const Icon(Icons.add),
                          label: const Text('Create Ticket'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _searchCtrl,
                      builder: (context, value, _) {
                        final query = value.text.trim();
                        final filteredTickets = ticketDocs
                            .where(
                              (doc) => _matchesFilters(
                                doc: doc,
                                usersByUserId: usersByUserId,
                                searchQuery: query,
                              ),
                            )
                            .toList();

                        if (ticketDocs.isEmpty) {
                          return const Card(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'No support tickets found.',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                        }

                        if (filteredTickets.isEmpty) {
                          return const Card(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'No tickets match the current search/filter.',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                        }

                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: filteredTickets.map((doc) {
                          final data = doc.data();
                          final userId = _safeString(data['user_id'], fallback: '');
                          final userData = usersByUserId[userId];
                          final reportedByFromUser = _reportedByFromUser(userData);
                          final reportedBy = reportedByFromUser.isEmpty
                              ? _safeString(data['reported_by'])
                              : reportedByFromUser;
                          final priority = _safeString(data['priority']);
                          final priorityBg = priority == 'Urgent'
                              ? _teal.withValues(alpha: 0.16)
                              : const Color(0xFFE0E0E0);
                          final priorityTextColor =
                              priority == 'Urgent' ? _teal : const Color(0xFF616161);

                            return SizedBox(
                            width: 420,
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _safeString(data['title']),
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: priorityBg,
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            priority,
                                            style: TextStyle(color: priorityTextColor),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _teal.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            _safeString(data['status']),
                                            style: const TextStyle(color: _teal),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    _kv('Ticket ID', _safeString(data['ticket_id'])),
                                    _kv('Document ID', doc.id),
                                    _kv('Category', _safeString(data['category'])),
                                    _kv('Reported At', _formatReportedAt(data['reported_at'])),
                                    _kv('Reported By', reportedBy),
                                    _kv('User ID', _safeString(data['user_id'])),
                                    const SizedBox(height: 8),
                                    Text(
                                      _safeString(data['description']),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        FilledButton(
                                          onPressed: () => _showTicketDialog(
                                            context: context,
                                            document: doc,
                                            usersById: usersByUserId,
                                            nextTicketId:
                                                _nextTicketId(ticketDocs).toString(),
                                          ),
                                          style: FilledButton.styleFrom(
                                            backgroundColor: _teal,
                                            foregroundColor: Colors.white,
                                          ),
                                          child: const Text('Update'),
                                        ),
                                        const SizedBox(width: 8),
                                        FilledButton(
                                          onPressed: () => _deleteTicket(
                                            context: context,
                                            docId: doc.id,
                                            title: _safeString(data['title']),
                                          ),
                                          style: FilledButton.styleFrom(
                                            backgroundColor:
                                                Theme.of(context).colorScheme.error,
                                          ),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _filterDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return SizedBox(
      width: 140,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        items: items
            .map(
              (item) => DropdownMenuItem<String>(
                value: item,
                child: Text(item),
              ),
            )
            .toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: _teal),
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: _teal, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        ),
      ),
    );
  }

  Widget _kv(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        '$key: $value',
        style: const TextStyle(fontSize: 13),
      ),
    );
  }

  void _showTicketDialog({
    required BuildContext context,
    required Map<String, Map<String, dynamic>> usersById,
    required String nextTicketId,
    DocumentSnapshot<Map<String, dynamic>>? document,
  }) {
    showDialog(
      context: context,
      builder: (_) => _TicketDialog(
        document: document,
        usersById: usersById,
        nextTicketId: nextTicketId,
      ),
    );
  }

  void _deleteTicket({
    required BuildContext context,
    required String docId,
    required String title,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Delete ticket "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await FirebaseFirestore.instance
                    .collection('support_tickets')
                    .doc(docId)
                    .delete();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ticket deleted')),
                );
              } on Object catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Delete failed: ${_firebaseErrorMessage(e)}'),
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _TicketDialog extends StatefulWidget {
  const _TicketDialog({
    required this.usersById,
    required this.nextTicketId,
    this.document,
  });

  final DocumentSnapshot<Map<String, dynamic>>? document;
  final Map<String, Map<String, dynamic>> usersById;
  final String nextTicketId;

  @override
  State<_TicketDialog> createState() => _TicketDialogState();
}

class _TicketDialogState extends State<_TicketDialog> {
  static const _categories = ['Sensor', 'Actuator', 'Fish', 'Plant'];
  static const _priorities = ['Urgent', 'Normal'];
  static const _statuses = ['Open', 'Resolved'];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _reportedByCtrl;

  String? _selectedCategory;
  String? _selectedPriority;
  String? _selectedStatus;
  String? _selectedUserId;

  bool get _isEditing => widget.document != null;

  @override
  void initState() {
    super.initState();
    final data = widget.document?.data() ?? <String, dynamic>{};
    _titleCtrl = TextEditingController(text: data['title']?.toString() ?? '');
    _descriptionCtrl =
        TextEditingController(text: data['description']?.toString() ?? '');
    _reportedByCtrl = TextEditingController();

    _selectedCategory = _readValidOption(
      data['category']?.toString(),
      _categories,
    );
    _selectedPriority = _readValidOption(
      data['priority']?.toString(),
      _priorities,
    );
    _selectedStatus = _readValidOption(
      data['status']?.toString(),
      _statuses,
    );

    final initialUserId = data['user_id']?.toString();
    if (initialUserId != null && widget.usersById.containsKey(initialUserId)) {
      _selectedUserId = initialUserId;
    }
    _syncReportedBy();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _reportedByCtrl.dispose();
    super.dispose();
  }

  String? _readValidOption(String? value, List<String> options) {
    if (value == null) return null;
    return options.contains(value) ? value : null;
  }

  String _safeNamePart(dynamic value) => value?.toString().trim() ?? '';

  void _syncReportedBy() {
    final userData = widget.usersById[_selectedUserId];
    final firstName = _safeNamePart(userData?['first_name']).isNotEmpty
        ? _safeNamePart(userData?['first_name'])
        : _safeNamePart(userData?['firstName']);
    final lastName = _safeNamePart(userData?['last_name']).isNotEmpty
        ? _safeNamePart(userData?['last_name'])
        : _safeNamePart(userData?['lastName']);
    _reportedByCtrl.text = '$firstName $lastName'.trim();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedUserId == null || !widget.usersById.containsKey(_selectedUserId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a valid user ID from the database')),
      );
      return;
    }

    final currentTicketId = _isEditing
        ? (widget.document!.data()?['ticket_id']?.toString().trim() ?? '')
        : widget.nextTicketId;
    final payload = <String, dynamic>{
      'title': _titleCtrl.text.trim(),
      'category': _selectedCategory,
      'description': _descriptionCtrl.text.trim(),
      'priority': _selectedPriority,
      'status': _selectedStatus,
      'ticket_id': currentTicketId.isEmpty ? widget.nextTicketId : currentTicketId,
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
    final userIds = widget.usersById.keys.toList()..sort();
    final displayTicketId = _isEditing
        ? (widget.document?.data()?['ticket_id']?.toString() ?? widget.nextTicketId)
        : widget.nextTicketId;

    return Dialog(
      child: Container(
        width: 560,
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isEditing ? 'Update Ticket' : 'Create Ticket',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFB0BEC5)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Ticket ID: $displayTicketId',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
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
                Row(
                  children: [
                    Expanded(
                      child: _dropdownField(
                        label: 'Priority',
                        value: _selectedPriority,
                        items: _priorities,
                        onChanged: (v) => setState(() => _selectedPriority = v),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _dropdownField(
                        label: 'Status',
                        value: _selectedStatus,
                        items: _statuses,
                        onChanged: (v) => setState(() => _selectedStatus = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _dropdownField(
                  label: 'User ID',
                  value: _selectedUserId,
                  items: userIds,
                  onChanged: (v) {
                    setState(() {
                      _selectedUserId = v;
                      _syncReportedBy();
                    });
                  },
                ),
                const SizedBox(height: 12),
                _textField(
                  _reportedByCtrl,
                  'Reported By',
                  readOnly: true,
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: _isEditing ? _teal : null,
                        foregroundColor: _isEditing ? Colors.white : null,
                      ),
                      child: Text(_isEditing ? 'Update' : 'Create'),
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
      enabledBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Color(0xFFB0BEC5)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: _teal, width: 2),
      ),
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
      validator: readOnly
          ? null
          : (v) => v == null || v.trim().isEmpty ? 'Required' : null,
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
      items: items
          .map(
            (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            ),
          )
          .toList(),
      onChanged: onChanged,
      iconEnabledColor: _teal,
      decoration: _inputDecoration(label),
      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
    );
  }
}
