import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'aquaponics_colors.dart';

class MessagesView extends StatefulWidget {
  const MessagesView({super.key});

  @override
  State<MessagesView> createState() => _MessagesViewState();
}

class _MessagesViewState extends State<MessagesView> {
  static const List<String> _statusOptions = ['All', 'new', 'reviewed', 'resolved'];

  String _contactStatusFilter = 'All';
  String _inquiryStatusFilter = 'All';

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            alignment: Alignment.centerLeft,
            child: const TabBar(
              isScrollable: true,
              labelColor: AquaponicsColors.waterBlue,
              indicatorColor: AquaponicsColors.waterBlue,
              labelStyle: TextStyle(fontWeight: FontWeight.w700),
              tabs: [
                Tab(text: 'Contact Messages'),
                Tab(text: 'Inquiry Messages'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _SubmissionTab(
                  title: 'Contact Messages',
                  collectionName: 'contact_submissions',
                  emptyLabel: 'No contact messages found.',
                  statusFilter: _contactStatusFilter,
                  onStatusFilterChanged: (value) {
                    if (value == null) return;
                    setState(() => _contactStatusFilter = value);
                  },
                  statusOptions: _statusOptions,
                  fieldsBuilder: _buildContactFields,
                ),
                _SubmissionTab(
                  title: 'Inquiry Messages',
                  collectionName: 'inquiry_submissions',
                  emptyLabel: 'No inquiry messages found.',
                  statusFilter: _inquiryStatusFilter,
                  onStatusFilterChanged: (value) {
                    if (value == null) return;
                    setState(() => _inquiryStatusFilter = value);
                  },
                  statusOptions: _statusOptions,
                  fieldsBuilder: _buildInquiryFields,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<_SubmissionField> _buildContactFields(Map<String, dynamic> data) {
    return [
      _SubmissionField(label: 'Name', value: _safeString(data['name'])),
      _SubmissionField(label: 'Email', value: _safeString(data['email'])),
      _SubmissionField(
        label: 'Subject',
        value: _safeString(data['subject'], fallback: 'Not provided'),
      ),
      _SubmissionField(label: 'Message', value: _safeString(data['message'])),
      _SubmissionField(
        label: 'Created',
        value: _formatDateTime(data['createdAt']),
      ),
      _SubmissionField(
        label: 'Source',
        value: _safeString(data['source'], fallback: 'Unknown'),
      ),
    ];
  }

  List<_SubmissionField> _buildInquiryFields(Map<String, dynamic> data) {
    return [
      _SubmissionField(label: 'Name', value: _safeString(data['name'])),
      _SubmissionField(label: 'Email', value: _safeString(data['email'])),
      _SubmissionField(
        label: 'Contact Number',
        value: _safeString(data['contactNumber'], fallback: 'Not provided'),
      ),
      _SubmissionField(
        label: 'Inquiry Type',
        value: _safeString(data['inquiryType'], fallback: 'Not provided'),
      ),
      _SubmissionField(label: 'Message', value: _safeString(data['message'])),
      _SubmissionField(
        label: 'Created',
        value: _formatDateTime(data['createdAt']),
      ),
      _SubmissionField(
        label: 'Source',
        value: _safeString(data['source'], fallback: 'Unknown'),
      ),
    ];
  }
}

class _SubmissionTab extends StatelessWidget {
  const _SubmissionTab({
    required this.title,
    required this.collectionName,
    required this.emptyLabel,
    required this.statusFilter,
    required this.onStatusFilterChanged,
    required this.statusOptions,
    required this.fieldsBuilder,
  });

  final String title;
  final String collectionName;
  final String emptyLabel;
  final String statusFilter;
  final ValueChanged<String?> onStatusFilterChanged;
  final List<String> statusOptions;
  final List<_SubmissionField> Function(Map<String, dynamic> data) fieldsBuilder;

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection(collectionName)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _SubmissionStateView(
            icon: Icons.error_outline_rounded,
            title: 'Unable to load $title',
            message: 'Firestore returned an error: ${snapshot.error}',
            isError: true,
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = (snapshot.data?.docs ?? const [])
            .toList()
          ..sort((a, b) {
            final aTime = _readDateTime(a.data()['createdAt']);
            final bTime = _readDateTime(b.data()['createdAt']);
            final aValue =
                aTime ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bValue =
                bTime ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bValue.compareTo(aValue);
          });

        final filteredDocs = docs.where((doc) {
          if (statusFilter == 'All') return true;
          final data = doc.data();
          final normalized = _normalizedStatus(data['status']);
          return normalized == statusFilter;
        }).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FilterCard(
                title: title,
                statusFilter: statusFilter,
                onStatusFilterChanged: onStatusFilterChanged,
                statusOptions: statusOptions,
              ),
              const SizedBox(height: 14),
              if (docs.isEmpty)
                _SubmissionStateView(
                  icon: Icons.mail_outline_rounded,
                  title: emptyLabel,
                  message:
                      'New public submissions will appear here after users submit the form.',
                )
              else if (filteredDocs.isEmpty)
                const _SubmissionStateView(
                  icon: Icons.filter_alt_off_rounded,
                  title: 'No submissions match the selected status',
                  message: 'Change the status filter to view more records.',
                )
              else
                ...filteredDocs.map(
                  (doc) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _SubmissionCard(
                      document: doc,
                      fields: fieldsBuilder(doc.data()),
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

class _FilterCard extends StatelessWidget {
  const _FilterCard({
    required this.title,
    required this.statusFilter,
    required this.onStatusFilterChanged,
    required this.statusOptions,
  });

  final String title;
  final String statusFilter;
  final ValueChanged<String?> onStatusFilterChanged;
  final List<String> statusOptions;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
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
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 420,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Review public form submissions and update status for admin follow-up.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String>(
              initialValue: statusFilter,
              decoration: InputDecoration(
                labelText: 'Status Filter',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              items: statusOptions
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item,
                      child: Text(item),
                    ),
                  )
                  .toList(),
              onChanged: onStatusFilterChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmissionCard extends StatefulWidget {
  const _SubmissionCard({
    required this.document,
    required this.fields,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> document;
  final List<_SubmissionField> fields;

  @override
  State<_SubmissionCard> createState() => _SubmissionCardState();
}

class _SubmissionCardState extends State<_SubmissionCard> {
  bool _isUpdatingStatus = false;

  Future<void> _updateStatus(String? value) async {
    if (value == null || _isUpdatingStatus) return;
    setState(() => _isUpdatingStatus = true);

    try {
      await widget.document.reference.update({'status': value});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status updated to $value.')),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status update failed: ${e.message ?? e.code}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status update failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdatingStatus = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.document.data();
    final currentStatus = _normalizedStatus(data['status']);
    final statusColor = _statusColor(currentStatus);
    final statusTextColor = _foregroundFor(statusColor);
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF101A26)
            : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  currentStatus,
                  style: TextStyle(
                    color: statusTextColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<String>(
                  initialValue: currentStatus,
                  decoration: InputDecoration(
                    labelText: 'Update Status',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: const ['new', 'reviewed', 'resolved']
                      .map(
                        (item) => DropdownMenuItem<String>(
                          value: item,
                          child: Text(item),
                        ),
                      )
                      .toList(),
                  onChanged: _isUpdatingStatus ? null : _updateStatus,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...widget.fields.map(
            (field) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _FieldBlock(field: field),
            ),
          ),
          if (_isUpdatingStatus)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(minHeight: 3),
            ),
        ],
      ),
    );
  }
}

class _FieldBlock extends StatelessWidget {
  const _FieldBlock({required this.field});

  final _SubmissionField field;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          field.label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        SelectableText(
          field.value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _SubmissionStateView extends StatelessWidget {
  const _SubmissionStateView({
    required this.icon,
    required this.title,
    required this.message,
    this.isError = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF101A26)
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 42,
            color: isError ? scheme.error : AquaponicsColors.adminInfo,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmissionField {
  const _SubmissionField({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}

String _safeString(dynamic value, {String fallback = '-'}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

DateTime? _readDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

String _formatDateTime(dynamic value) {
  final date = _readDateTime(value);
  if (date == null) return 'No timestamp';
  final local = date.toLocal();
  final month = _monthName(local.month);
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour >= 12 ? 'PM' : 'AM';
  return '$month ${local.day}, ${local.year} - $hour:$minute $suffix';
}

String _monthName(int month) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return months[(month - 1).clamp(0, 11)];
}

String _normalizedStatus(dynamic value) {
  final text = value?.toString().trim().toLowerCase() ?? '';
  if (text == 'reviewed' || text == 'resolved') return text;
  return 'new';
}

Color _statusColor(String status) {
  switch (status) {
    case 'resolved':
      return AquaponicsColors.statusSafe;
    case 'reviewed':
      return AquaponicsColors.statusWarning;
    default:
      return AquaponicsColors.adminInfo;
  }
}

Color _foregroundFor(Color background) {
  final brightness = ThemeData.estimateBrightnessForColor(background);
  return brightness == Brightness.dark ? Colors.white : const Color(0xFF10211C);
}
