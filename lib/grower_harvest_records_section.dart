import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'aquaponics_colors.dart';

class GrowerHarvestRecordsSection extends StatefulWidget {
  const GrowerHarvestRecordsSection({
    super.key,
    required this.userCollection,
    required this.userDocId,
    required this.growerUid,
    required this.growerName,
    required this.growerEmail,
    required this.systemId,
    required this.systemName,
    required this.hardwareUid,
  });

  final String userCollection;
  final String userDocId;
  final String growerUid;
  final String growerName;
  final String growerEmail;
  final String systemId;
  final String systemName;
  final String hardwareUid;

  @override
  State<GrowerHarvestRecordsSection> createState() =>
      _GrowerHarvestRecordsSectionState();
}

class _GrowerHarvestRecordsSectionState
    extends State<GrowerHarvestRecordsSection> {
  bool _isSaving = false;

  CollectionReference<Map<String, dynamic>> get _recordsCollection =>
      FirebaseFirestore.instance
          .collection(widget.userCollection)
          .doc(widget.userDocId)
          .collection('systems')
          .doc(widget.systemId)
          .collection('harvest_records');

  Future<void> _showAddDialog() async {
    await _showRecordDialog();
  }

  Future<void> _showEditDialog(_HarvestRecord record) async {
    await _showRecordDialog(existing: record);
  }

  Future<void> _showRecordDialog({_HarvestRecord? existing}) async {
    final result = await showDialog<_HarvestRecordDraft>(
      context: context,
      builder: (context) => _HarvestRecordDialog(
        initialRecord: existing,
      ),
    );
    if (result == null) return;

    if (_isSaving) return;
    setState(() => _isSaving = true);

    final payload = <String, dynamic>{
      'growerUid': widget.growerUid,
      'growerName': widget.growerName,
      'growerEmail': widget.growerEmail,
      'systemId': widget.systemId,
      'systemName': widget.systemName,
      'hardwareUid': widget.hardwareUid,
      'recordType': result.recordType,
      'itemName': result.itemName,
      'quantity': result.quantity,
      'unit': result.unit,
      'harvestDate': Timestamp.fromDate(result.harvestDate),
      'condition': result.condition,
      'notes': result.notes,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      if (existing == null) {
        payload['createdAt'] = FieldValue.serverTimestamp();
        payload['createdBy'] = FirebaseAuth.instance.currentUser?.uid ?? '';
        await _recordsCollection.add(payload);
      } else {
        await _recordsCollection.doc(existing.id).update(payload);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existing == null
                ? 'Harvest record added.'
                : 'Harvest record updated.',
          ),
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Harvest record save failed: ${e.message ?? e.code}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Harvest record save failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w800,
    );
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 520,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Harvest Records', style: titleStyle),
                  const SizedBox(height: 4),
                  Text(
                    'Record and review plant and aquaculture harvest entries for this assigned system.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: _isSaving ? null : _showAddDialog,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_chart_rounded),
              label: Text(_isSaving ? 'Saving...' : 'Add Harvest Record'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _recordsCollection
              .orderBy('harvestDate', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _HarvestStateCard(
                message:
                    'Harvest records could not be loaded: ${snapshot.error}',
                isError: true,
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const _HarvestLoadingCard();
            }

            final docs = snapshot.data?.docs ?? const [];
            if (docs.isEmpty) {
              return const _HarvestStateCard(
                message: 'No harvest records have been added for this system yet.',
              );
            }

            final records = docs.map(_HarvestRecord.fromDoc).toList();
            return Column(
              children: records
                  .map(
                    (record) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _HarvestRecordCard(
                        record: record,
                        onEdit: _isSaving ? null : () => _showEditDialog(record),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _HarvestRecordDialog extends StatefulWidget {
  const _HarvestRecordDialog({this.initialRecord});

  final _HarvestRecord? initialRecord;

  @override
  State<_HarvestRecordDialog> createState() => _HarvestRecordDialogState();
}

class _HarvestRecordDialogState extends State<_HarvestRecordDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _itemNameController;
  late final TextEditingController _quantityController;
  late final TextEditingController _notesController;
  late String _recordType;
  late String _unit;
  late String _condition;
  late DateTime _harvestDate;

  static const List<String> _recordTypes = ['plant', 'aquaculture'];
  static const List<String> _units = ['kg', 'g', 'pcs', 'bundles'];
  static const List<String> _conditions = ['good', 'fair', 'poor'];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialRecord;
    _itemNameController = TextEditingController(text: initial?.itemName ?? '');
    _quantityController = TextEditingController(
      text: initial == null ? '' : _formatQuantity(initial.quantity),
    );
    _notesController = TextEditingController(text: initial?.notes ?? '');
    _recordType = initial?.recordType ?? _recordTypes.first;
    _unit = initial?.unit ?? _units.first;
    _condition = initial?.condition ?? _conditions.first;
    _harvestDate = initial?.harvestDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _formatQuantity(num value) {
    if (value is int) return value.toString();
    final asDouble = value.toDouble();
    return asDouble == asDouble.truncateToDouble()
        ? asDouble.toInt().toString()
        : asDouble.toString();
  }

  Future<void> _pickHarvestDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _harvestDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _harvestDate = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final quantity = double.tryParse(_quantityController.text.trim());
    if (quantity == null || quantity <= 0) return;

    Navigator.of(context).pop(
      _HarvestRecordDraft(
        recordType: _recordType,
        itemName: _itemNameController.text.trim(),
        quantity: quantity,
        unit: _unit,
        harvestDate: _harvestDate,
        condition: _condition,
        notes: _notesController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialRecord != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Harvest Record' : 'Add Harvest Record'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _recordType,
                  decoration: const InputDecoration(
                    labelText: 'Record Type',
                    border: OutlineInputBorder(),
                  ),
                  items: _recordTypes
                      .map(
                        (value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _recordType = value);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _itemNameController,
                  decoration: const InputDecoration(
                    labelText: 'Item Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return 'Item name is required.';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _quantityController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final parsed = double.tryParse(value?.trim() ?? '');
                    if (parsed == null || parsed <= 0) {
                      return 'Enter a quantity greater than zero.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _unit,
                  decoration: const InputDecoration(
                    labelText: 'Unit',
                    border: OutlineInputBorder(),
                  ),
                  items: _units
                      .map(
                        (value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _unit = value);
                  },
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickHarvestDate,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Harvest Date',
                      border: OutlineInputBorder(),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(DateFormat('MMM d, y').format(_harvestDate)),
                        const Icon(Icons.calendar_today_rounded, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _condition,
                  decoration: const InputDecoration(
                    labelText: 'Condition',
                    border: OutlineInputBorder(),
                  ),
                  items: _conditions
                      .map(
                        (value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _condition = value);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(isEditing ? 'Update' : 'Save'),
        ),
      ],
    );
  }
}

class _HarvestRecordCard extends StatelessWidget {
  const _HarvestRecordCard({
    required this.record,
    required this.onEdit,
  });

  final _HarvestRecord record;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final recordTypeColor = record.recordType == 'aquaculture'
        ? AquaponicsColors.adminInfo
        : AquaponicsColors.statusSafe;
    final conditionColor = _conditionColor(record.condition);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 520,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.itemName,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatQuantity(record.quantity)} ${record.unit} | ${DateFormat('MMM d, y').format(record.harvestDate)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ChipLabel(
                    label: record.recordType,
                    background: recordTypeColor.withValues(alpha: 0.14),
                    foreground: recordTypeColor,
                  ),
                  _ChipLabel(
                    label: record.condition,
                    background: conditionColor.withValues(alpha: 0.14),
                    foreground: conditionColor,
                  ),
                  OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: const Text('Edit'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            record.notes.isEmpty ? 'No notes recorded.' : record.notes,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Created: ${_formatDateTime(record.createdAt)} | Updated: ${_formatDateTime(record.updatedAt)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _HarvestStateCard extends StatelessWidget {
  const _HarvestStateCard({
    required this.message,
    this.isError = false,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: isError ? scheme.error : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _HarvestLoadingCard extends StatelessWidget {
  const _HarvestLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: const LinearProgressIndicator(minHeight: 4),
    );
  }
}

class _ChipLabel extends StatelessWidget {
  const _ChipLabel({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _HarvestRecord {
  const _HarvestRecord({
    required this.id,
    required this.recordType,
    required this.itemName,
    required this.quantity,
    required this.unit,
    required this.harvestDate,
    required this.condition,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String recordType;
  final String itemName;
  final num quantity;
  final String unit;
  final DateTime harvestDate;
  final String condition;
  final String notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory _HarvestRecord.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return _HarvestRecord(
      id: doc.id,
      recordType: _normalizedRecordType(data['recordType']),
      itemName: _safeString(data['itemName'], fallback: 'Unnamed item'),
      quantity: _readNum(data['quantity']),
      unit: _safeString(data['unit'], fallback: '-'),
      harvestDate:
          _readDateTime(data['harvestDate']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      condition: _normalizedCondition(data['condition']),
      notes: _safeString(data['notes']),
      createdAt: _readDateTime(data['createdAt']),
      updatedAt: _readDateTime(data['updatedAt']),
    );
  }
}

class _HarvestRecordDraft {
  const _HarvestRecordDraft({
    required this.recordType,
    required this.itemName,
    required this.quantity,
    required this.unit,
    required this.harvestDate,
    required this.condition,
    required this.notes,
  });

  final String recordType;
  final String itemName;
  final double quantity;
  final String unit;
  final DateTime harvestDate;
  final String condition;
  final String notes;
}

String _safeString(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

num _readNum(dynamic value) {
  if (value is num) return value;
  return num.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _readDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

String _normalizedRecordType(dynamic value) {
  final text = value?.toString().trim().toLowerCase() ?? '';
  return text == 'aquaculture' ? 'aquaculture' : 'plant';
}

String _normalizedCondition(dynamic value) {
  final text = value?.toString().trim().toLowerCase() ?? '';
  if (text == 'fair' || text == 'poor') return text;
  return 'good';
}

String _formatQuantity(num value) {
  if (value is int) return value.toString();
  final asDouble = value.toDouble();
  return asDouble == asDouble.truncateToDouble()
      ? asDouble.toInt().toString()
      : asDouble.toString();
}

String _formatDateTime(DateTime? value) {
  if (value == null) return 'No timestamp';
  return DateFormat('MMM d, y - h:mm a').format(value.toLocal());
}

Color _conditionColor(String condition) {
  switch (condition) {
    case 'poor':
      return AquaponicsColors.statusDanger;
    case 'fair':
      return AquaponicsColors.statusWarning;
    default:
      return AquaponicsColors.statusSafe;
  }
}
