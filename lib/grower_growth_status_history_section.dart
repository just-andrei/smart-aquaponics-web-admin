import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'aquaponics_colors.dart';

class GrowerGrowthStatusHistorySection extends StatelessWidget {
  const GrowerGrowthStatusHistorySection({
    super.key,
    required this.userCollection,
    required this.userDocId,
    required this.growerUid,
    required this.growerName,
    required this.growerEmail,
    required this.systemId,
    required this.systemName,
    required this.hardwareUid,
    required this.defaultPlantName,
    required this.defaultSpeciesName,
  });

  final String userCollection;
  final String userDocId;
  final String growerUid;
  final String growerName;
  final String growerEmail;
  final String systemId;
  final String systemName;
  final String hardwareUid;
  final String defaultPlantName;
  final String defaultSpeciesName;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w800,
    );
    final scheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Growth / Status History', style: titleStyle),
          const SizedBox(height: 4),
          Text(
            'Review and maintain plant and aquaculture growth/status records for this assigned system.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              labelColor: scheme.onSurface,
              unselectedLabelColor: scheme.onSurfaceVariant,
              indicator: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              tabs: const [
                Tab(text: 'Plant Status Records'),
                Tab(text: 'Aquaculture Status Records'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 520,
            child: TabBarView(
              children: [
                _PlantStatusRecordsTab(
                  userCollection: userCollection,
                  userDocId: userDocId,
                  growerUid: growerUid,
                  growerName: growerName,
                  growerEmail: growerEmail,
                  systemId: systemId,
                  systemName: systemName,
                  hardwareUid: hardwareUid,
                  defaultPlantName: defaultPlantName,
                ),
                _AquacultureStatusRecordsTab(
                  userCollection: userCollection,
                  userDocId: userDocId,
                  growerUid: growerUid,
                  growerName: growerName,
                  growerEmail: growerEmail,
                  systemId: systemId,
                  systemName: systemName,
                  hardwareUid: hardwareUid,
                  defaultSpeciesName: defaultSpeciesName,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlantStatusRecordsTab extends StatefulWidget {
  const _PlantStatusRecordsTab({
    required this.userCollection,
    required this.userDocId,
    required this.growerUid,
    required this.growerName,
    required this.growerEmail,
    required this.systemId,
    required this.systemName,
    required this.hardwareUid,
    required this.defaultPlantName,
  });

  final String userCollection;
  final String userDocId;
  final String growerUid;
  final String growerName;
  final String growerEmail;
  final String systemId;
  final String systemName;
  final String hardwareUid;
  final String defaultPlantName;

  @override
  State<_PlantStatusRecordsTab> createState() => _PlantStatusRecordsTabState();
}

class _PlantStatusRecordsTabState extends State<_PlantStatusRecordsTab> {
  bool _isSaving = false;

  CollectionReference<Map<String, dynamic>> get _collection =>
      FirebaseFirestore.instance
          .collection(widget.userCollection)
          .doc(widget.userDocId)
          .collection('systems')
          .doc(widget.systemId)
          .collection('plant_status_records');

  Future<void> _showDialog({_PlantStatusRecord? existing}) async {
    final draft = await showDialog<_PlantStatusDraft>(
      context: context,
      builder: (context) => _PlantStatusDialog(
        initialRecord: existing,
        defaultPlantName: widget.defaultPlantName,
      ),
    );
    if (draft == null || _isSaving) return;

    setState(() => _isSaving = true);
    final payload = <String, dynamic>{
      'growerUid': widget.growerUid,
      'growerName': widget.growerName,
      'growerEmail': widget.growerEmail,
      'systemId': widget.systemId,
      'systemName': widget.systemName,
      'hardwareUid': widget.hardwareUid,
      'plantName': draft.plantName,
      'growthStage': draft.growthStage,
      'heightValue': draft.heightValue,
      'heightUnit': draft.heightUnit,
      'leafCondition': draft.leafCondition,
      'healthStatus': draft.healthStatus,
      'notes': draft.notes,
      'recordedAt': Timestamp.fromDate(draft.recordedAt),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      if (existing == null) {
        payload['createdAt'] = FieldValue.serverTimestamp();
        payload['createdBy'] = FirebaseAuth.instance.currentUser?.uid ?? '';
        await _collection.add(payload);
      } else {
        await _collection.doc(existing.id).update(payload);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existing == null
                ? 'Plant status record added.'
                : 'Plant status record updated.',
          ),
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Plant status save failed: ${e.message ?? e.code}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Plant status save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _StatusRecordsPanel(
      title: 'Plant Status Records',
      addLabel: 'Add Plant Status',
      isSaving: _isSaving,
      onAdd: _isSaving ? null : () => _showDialog(),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _collection.orderBy('recordedAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _RecordsStateCard(
              message:
                  'Plant status records could not be loaded: ${snapshot.error}',
              isError: true,
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const _RecordsLoadingCard();
          }

          final docs = snapshot.data?.docs ?? const [];
          if (docs.isEmpty) {
            return const _RecordsStateCard(
              message: 'No plant status records have been added for this system yet.',
            );
          }

          final records = docs.map(_PlantStatusRecord.fromDoc).toList();
          return ListView.separated(
            itemCount: records.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _PlantStatusCard(
              record: records[index],
              onEdit: _isSaving ? null : () => _showDialog(existing: records[index]),
            ),
          );
        },
      ),
    );
  }
}

class _AquacultureStatusRecordsTab extends StatefulWidget {
  const _AquacultureStatusRecordsTab({
    required this.userCollection,
    required this.userDocId,
    required this.growerUid,
    required this.growerName,
    required this.growerEmail,
    required this.systemId,
    required this.systemName,
    required this.hardwareUid,
    required this.defaultSpeciesName,
  });

  final String userCollection;
  final String userDocId;
  final String growerUid;
  final String growerName;
  final String growerEmail;
  final String systemId;
  final String systemName;
  final String hardwareUid;
  final String defaultSpeciesName;

  @override
  State<_AquacultureStatusRecordsTab> createState() =>
      _AquacultureStatusRecordsTabState();
}

class _AquacultureStatusRecordsTabState
    extends State<_AquacultureStatusRecordsTab> {
  bool _isSaving = false;

  CollectionReference<Map<String, dynamic>> get _collection =>
      FirebaseFirestore.instance
          .collection(widget.userCollection)
          .doc(widget.userDocId)
          .collection('systems')
          .doc(widget.systemId)
          .collection('aquaculture_status_records');

  Future<void> _showDialog({_AquacultureStatusRecord? existing}) async {
    final draft = await showDialog<_AquacultureStatusDraft>(
      context: context,
      builder: (context) => _AquacultureStatusDialog(
        initialRecord: existing,
        defaultSpeciesName: widget.defaultSpeciesName,
      ),
    );
    if (draft == null || _isSaving) return;

    setState(() => _isSaving = true);
    final payload = <String, dynamic>{
      'growerUid': widget.growerUid,
      'growerName': widget.growerName,
      'growerEmail': widget.growerEmail,
      'systemId': widget.systemId,
      'systemName': widget.systemName,
      'hardwareUid': widget.hardwareUid,
      'speciesName': draft.speciesName,
      'growthStage': draft.growthStage,
      'fishCount': draft.fishCount,
      'averageWeightValue': draft.averageWeightValue,
      'averageWeightUnit': draft.averageWeightUnit,
      'healthStatus': draft.healthStatus,
      'feedingObservation': draft.feedingObservation,
      'behaviorObservation': draft.behaviorObservation,
      'notes': draft.notes,
      'recordedAt': Timestamp.fromDate(draft.recordedAt),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      if (existing == null) {
        payload['createdAt'] = FieldValue.serverTimestamp();
        payload['createdBy'] = FirebaseAuth.instance.currentUser?.uid ?? '';
        await _collection.add(payload);
      } else {
        await _collection.doc(existing.id).update(payload);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existing == null
                ? 'Aquaculture status record added.'
                : 'Aquaculture status record updated.',
          ),
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Aquaculture status save failed: ${e.message ?? e.code}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Aquaculture status save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _StatusRecordsPanel(
      title: 'Aquaculture Status Records',
      addLabel: 'Add Aquaculture Status',
      isSaving: _isSaving,
      onAdd: _isSaving ? null : () => _showDialog(),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _collection.orderBy('recordedAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _RecordsStateCard(
              message:
                  'Aquaculture status records could not be loaded: ${snapshot.error}',
              isError: true,
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const _RecordsLoadingCard();
          }

          final docs = snapshot.data?.docs ?? const [];
          if (docs.isEmpty) {
            return const _RecordsStateCard(
              message: 'No aquaculture status records have been added for this system yet.',
            );
          }

          final records = docs.map(_AquacultureStatusRecord.fromDoc).toList();
          return ListView.separated(
            itemCount: records.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _AquacultureStatusCard(
              record: records[index],
              onEdit: _isSaving ? null : () => _showDialog(existing: records[index]),
            ),
          );
        },
      ),
    );
  }
}

class _StatusRecordsPanel extends StatelessWidget {
  const _StatusRecordsPanel({
    required this.title,
    required this.addLabel,
    required this.isSaving,
    required this.onAdd,
    required this.child,
  });

  final String title;
  final String addLabel;
  final bool isSaving;
  final VoidCallback? onAdd;
  final Widget child;

  @override
  Widget build(BuildContext context) {
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
            Text(
              title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            FilledButton.icon(
              onPressed: onAdd,
              icon: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_rounded),
              label: Text(isSaving ? 'Saving...' : addLabel),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: child,
            ),
          ),
        ),
      ],
    );
  }
}

class _PlantStatusDialog extends StatefulWidget {
  const _PlantStatusDialog({
    this.initialRecord,
    required this.defaultPlantName,
  });

  final _PlantStatusRecord? initialRecord;
  final String defaultPlantName;

  @override
  State<_PlantStatusDialog> createState() => _PlantStatusDialogState();
}

class _PlantStatusDialogState extends State<_PlantStatusDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _plantNameController;
  late final TextEditingController _heightValueController;
  late final TextEditingController _notesController;
  late String _growthStage;
  late String _heightUnit;
  late String _leafCondition;
  late String _healthStatus;
  late DateTime _recordedAt;

  static const List<String> _growthStages = [
    'seedling',
    'vegetative',
    'mature',
    'flowering',
    'ready_to_harvest',
  ];
  static const List<String> _heightUnits = ['cm', 'm', 'in'];
  static const List<String> _leafConditions = [
    'healthy',
    'yellowing',
    'wilting',
    'pest_damage',
    'nutrient_deficiency',
    'unknown',
  ];
  static const List<String> _healthStatuses = [
    'good',
    'fair',
    'poor',
    'critical',
  ];

  @override
  void initState() {
    super.initState();
    final record = widget.initialRecord;
    _plantNameController = TextEditingController(
      text: record?.plantName ?? widget.defaultPlantName,
    );
    _heightValueController = TextEditingController(
      text: record?.heightValue == null ? '' : _formatNumber(record!.heightValue!),
    );
    _notesController = TextEditingController(text: record?.notes ?? '');
    _growthStage = record?.growthStage ?? _growthStages.first;
    _heightUnit = record?.heightUnit ?? _heightUnits.first;
    _leafCondition = record?.leafCondition ?? _leafConditions.first;
    _healthStatus = record?.healthStatus ?? _healthStatuses.first;
    _recordedAt = record?.recordedAt ?? DateTime.now();
  }

  @override
  void dispose() {
    _plantNameController.dispose();
    _heightValueController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _recordedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _recordedAt = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop(
      _PlantStatusDraft(
        plantName: _plantNameController.text.trim(),
        growthStage: _growthStage,
        heightValue: _tryParseDouble(_heightValueController.text),
        heightUnit: _heightUnit,
        leafCondition: _leafCondition,
        healthStatus: _healthStatus,
        notes: _notesController.text.trim(),
        recordedAt: _recordedAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialRecord != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Plant Status' : 'Add Plant Status'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _plantNameController,
                  decoration: const InputDecoration(
                    labelText: 'Plant Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if ((value?.trim() ?? '').isEmpty) {
                      return 'Plant name is required.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _growthStage,
                  decoration: const InputDecoration(
                    labelText: 'Growth Stage',
                    border: OutlineInputBorder(),
                  ),
                  items: _growthStages
                      .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _growthStage = value);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _heightValueController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Height Value',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return null;
                    if (double.tryParse(text) == null) {
                      return 'Enter a valid height value.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _heightUnit,
                  decoration: const InputDecoration(
                    labelText: 'Height Unit',
                    border: OutlineInputBorder(),
                  ),
                  items: _heightUnits
                      .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _heightUnit = value);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _leafCondition,
                  decoration: const InputDecoration(
                    labelText: 'Leaf Condition',
                    border: OutlineInputBorder(),
                  ),
                  items: _leafConditions
                      .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _leafCondition = value);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _healthStatus,
                  decoration: const InputDecoration(
                    labelText: 'Health Status',
                    border: OutlineInputBorder(),
                  ),
                  items: _healthStatuses
                      .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _healthStatus = value);
                  },
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Recorded At',
                      border: OutlineInputBorder(),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(DateFormat('MMM d, y').format(_recordedAt)),
                        const Icon(Icons.calendar_today_rounded, size: 18),
                      ],
                    ),
                  ),
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

class _AquacultureStatusDialog extends StatefulWidget {
  const _AquacultureStatusDialog({
    this.initialRecord,
    required this.defaultSpeciesName,
  });

  final _AquacultureStatusRecord? initialRecord;
  final String defaultSpeciesName;

  @override
  State<_AquacultureStatusDialog> createState() =>
      _AquacultureStatusDialogState();
}

class _AquacultureStatusDialogState extends State<_AquacultureStatusDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _speciesNameController;
  late final TextEditingController _fishCountController;
  late final TextEditingController _averageWeightController;
  late final TextEditingController _notesController;
  late String _growthStage;
  late String _averageWeightUnit;
  late String _healthStatus;
  late String _feedingObservation;
  late String _behaviorObservation;
  late DateTime _recordedAt;

  static const List<String> _growthStages = [
    'small',
    'medium',
    'large',
    'harvest_ready',
  ];
  static const List<String> _averageWeightUnits = ['g', 'kg'];
  static const List<String> _healthStatuses = [
    'good',
    'fair',
    'poor',
    'critical',
  ];
  static const List<String> _feedingObservations = [
    'normal',
    'low_appetite',
    'overfeeding_signs',
    'missed_feeding',
    'unknown',
  ];
  static const List<String> _behaviorObservations = [
    'normal',
    'sluggish',
    'gasping',
    'hiding',
    'aggressive',
    'mortality_observed',
    'unknown',
  ];

  @override
  void initState() {
    super.initState();
    final record = widget.initialRecord;
    _speciesNameController = TextEditingController(
      text: record?.speciesName ?? widget.defaultSpeciesName,
    );
    _fishCountController = TextEditingController(
      text: record?.fishCount?.toString() ?? '',
    );
    _averageWeightController = TextEditingController(
      text: record?.averageWeightValue == null
          ? ''
          : _formatNumber(record!.averageWeightValue!),
    );
    _notesController = TextEditingController(text: record?.notes ?? '');
    _growthStage = record?.growthStage ?? _growthStages.first;
    _averageWeightUnit =
        record?.averageWeightUnit ?? _averageWeightUnits.first;
    _healthStatus = record?.healthStatus ?? _healthStatuses.first;
    _feedingObservation =
        record?.feedingObservation ?? _feedingObservations.first;
    _behaviorObservation =
        record?.behaviorObservation ?? _behaviorObservations.first;
    _recordedAt = record?.recordedAt ?? DateTime.now();
  }

  @override
  void dispose() {
    _speciesNameController.dispose();
    _fishCountController.dispose();
    _averageWeightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _recordedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _recordedAt = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop(
      _AquacultureStatusDraft(
        speciesName: _speciesNameController.text.trim(),
        growthStage: _growthStage,
        fishCount: _tryParseInt(_fishCountController.text),
        averageWeightValue: _tryParseDouble(_averageWeightController.text),
        averageWeightUnit: _averageWeightUnit,
        healthStatus: _healthStatus,
        feedingObservation: _feedingObservation,
        behaviorObservation: _behaviorObservation,
        notes: _notesController.text.trim(),
        recordedAt: _recordedAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialRecord != null;

    return AlertDialog(
      title: Text(
        isEditing ? 'Edit Aquaculture Status' : 'Add Aquaculture Status',
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _speciesNameController,
                  decoration: const InputDecoration(
                    labelText: 'Species Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if ((value?.trim() ?? '').isEmpty) {
                      return 'Species name is required.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _growthStage,
                  decoration: const InputDecoration(
                    labelText: 'Growth Stage',
                    border: OutlineInputBorder(),
                  ),
                  items: _growthStages
                      .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _growthStage = value);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _fishCountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Fish Count',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return null;
                    if (int.tryParse(text) == null) {
                      return 'Enter a valid fish count.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _averageWeightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Average Weight Value',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return null;
                    if (double.tryParse(text) == null) {
                      return 'Enter a valid average weight.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _averageWeightUnit,
                  decoration: const InputDecoration(
                    labelText: 'Average Weight Unit',
                    border: OutlineInputBorder(),
                  ),
                  items: _averageWeightUnits
                      .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _averageWeightUnit = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _healthStatus,
                  decoration: const InputDecoration(
                    labelText: 'Health Status',
                    border: OutlineInputBorder(),
                  ),
                  items: _healthStatuses
                      .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _healthStatus = value);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _feedingObservation,
                  decoration: const InputDecoration(
                    labelText: 'Feeding Observation',
                    border: OutlineInputBorder(),
                  ),
                  items: _feedingObservations
                      .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _feedingObservation = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _behaviorObservation,
                  decoration: const InputDecoration(
                    labelText: 'Behavior Observation',
                    border: OutlineInputBorder(),
                  ),
                  items: _behaviorObservations
                      .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _behaviorObservation = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Recorded At',
                      border: OutlineInputBorder(),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(DateFormat('MMM d, y').format(_recordedAt)),
                        const Icon(Icons.calendar_today_rounded, size: 18),
                      ],
                    ),
                  ),
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

class _PlantStatusCard extends StatelessWidget {
  const _PlantStatusCard({
    required this.record,
    required this.onEdit,
  });

  final _PlantStatusRecord record;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final healthColor = _healthColor(record.healthStatus);
    final leafColor = _leafConditionColor(record.leafCondition);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
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
                      record.plantName,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Recorded: ${_formatDateTime(record.recordedAt)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Badge(
                    label: record.growthStage,
                    background: AquaponicsColors.adminInfo.withValues(alpha: 0.14),
                    foreground: AquaponicsColors.adminInfo,
                  ),
                  _Badge(
                    label: record.healthStatus,
                    background: healthColor.withValues(alpha: 0.14),
                    foreground: healthColor,
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
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoChip(
                label: 'Height',
                value: record.heightValue == null
                    ? 'Not recorded'
                    : '${_formatNumber(record.heightValue!)} ${record.heightUnit}',
              ),
              _InfoChip(
                label: 'Leaf Condition',
                value: record.leafCondition,
                accent: leafColor,
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
        ],
      ),
    );
  }
}

class _AquacultureStatusCard extends StatelessWidget {
  const _AquacultureStatusCard({
    required this.record,
    required this.onEdit,
  });

  final _AquacultureStatusRecord record;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final healthColor = _healthColor(record.healthStatus);
    final feedingColor = _observationColor(record.feedingObservation);
    final behaviorColor = _observationColor(record.behaviorObservation);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
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
                      record.speciesName,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Recorded: ${_formatDateTime(record.recordedAt)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Badge(
                    label: record.growthStage,
                    background: AquaponicsColors.adminInfo.withValues(alpha: 0.14),
                    foreground: AquaponicsColors.adminInfo,
                  ),
                  _Badge(
                    label: record.healthStatus,
                    background: healthColor.withValues(alpha: 0.14),
                    foreground: healthColor,
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
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoChip(
                label: 'Fish Count',
                value: record.fishCount?.toString() ?? 'Not recorded',
              ),
              _InfoChip(
                label: 'Average Weight',
                value: record.averageWeightValue == null
                    ? 'Not recorded'
                    : '${_formatNumber(record.averageWeightValue!)} ${record.averageWeightUnit}',
              ),
              _InfoChip(
                label: 'Feeding',
                value: record.feedingObservation,
                accent: feedingColor,
              ),
              _InfoChip(
                label: 'Behavior',
                value: record.behaviorObservation,
                accent: behaviorColor,
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
        ],
      ),
    );
  }
}

class _RecordsStateCard extends StatelessWidget {
  const _RecordsStateCard({
    required this.message,
    this.isError = false,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: isError ? scheme.error : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _RecordsLoadingCard extends StatelessWidget {
  const _RecordsLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: LinearProgressIndicator(minHeight: 4),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
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

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.value,
    this.accent,
  });

  final String label;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: accent == null ? scheme.outlineVariant : accent!,
        ),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: accent ?? scheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PlantStatusRecord {
  const _PlantStatusRecord({
    required this.id,
    required this.plantName,
    required this.growthStage,
    required this.heightValue,
    required this.heightUnit,
    required this.leafCondition,
    required this.healthStatus,
    required this.notes,
    required this.recordedAt,
  });

  final String id;
  final String plantName;
  final String growthStage;
  final double? heightValue;
  final String heightUnit;
  final String leafCondition;
  final String healthStatus;
  final String notes;
  final DateTime recordedAt;

  factory _PlantStatusRecord.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return _PlantStatusRecord(
      id: doc.id,
      plantName: _readString(data['plantName'], fallback: 'Unnamed plant'),
      growthStage: _readString(data['growthStage'], fallback: 'unknown'),
      heightValue: _readDoubleNullable(data['heightValue']),
      heightUnit: _readString(data['heightUnit'], fallback: 'cm'),
      leafCondition: _readString(data['leafCondition'], fallback: 'unknown'),
      healthStatus: _readString(data['healthStatus'], fallback: 'good'),
      notes: _readString(data['notes']),
      recordedAt:
          _readDateTime(data['recordedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class _AquacultureStatusRecord {
  const _AquacultureStatusRecord({
    required this.id,
    required this.speciesName,
    required this.growthStage,
    required this.fishCount,
    required this.averageWeightValue,
    required this.averageWeightUnit,
    required this.healthStatus,
    required this.feedingObservation,
    required this.behaviorObservation,
    required this.notes,
    required this.recordedAt,
  });

  final String id;
  final String speciesName;
  final String growthStage;
  final int? fishCount;
  final double? averageWeightValue;
  final String averageWeightUnit;
  final String healthStatus;
  final String feedingObservation;
  final String behaviorObservation;
  final String notes;
  final DateTime recordedAt;

  factory _AquacultureStatusRecord.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return _AquacultureStatusRecord(
      id: doc.id,
      speciesName: _readString(data['speciesName'], fallback: 'Unnamed species'),
      growthStage: _readString(data['growthStage'], fallback: 'unknown'),
      fishCount: _readIntNullable(data['fishCount']),
      averageWeightValue: _readDoubleNullable(data['averageWeightValue']),
      averageWeightUnit: _readString(data['averageWeightUnit'], fallback: 'g'),
      healthStatus: _readString(data['healthStatus'], fallback: 'good'),
      feedingObservation:
          _readString(data['feedingObservation'], fallback: 'unknown'),
      behaviorObservation:
          _readString(data['behaviorObservation'], fallback: 'unknown'),
      notes: _readString(data['notes']),
      recordedAt:
          _readDateTime(data['recordedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class _PlantStatusDraft {
  const _PlantStatusDraft({
    required this.plantName,
    required this.growthStage,
    required this.heightValue,
    required this.heightUnit,
    required this.leafCondition,
    required this.healthStatus,
    required this.notes,
    required this.recordedAt,
  });

  final String plantName;
  final String growthStage;
  final double? heightValue;
  final String heightUnit;
  final String leafCondition;
  final String healthStatus;
  final String notes;
  final DateTime recordedAt;
}

class _AquacultureStatusDraft {
  const _AquacultureStatusDraft({
    required this.speciesName,
    required this.growthStage,
    required this.fishCount,
    required this.averageWeightValue,
    required this.averageWeightUnit,
    required this.healthStatus,
    required this.feedingObservation,
    required this.behaviorObservation,
    required this.notes,
    required this.recordedAt,
  });

  final String speciesName;
  final String growthStage;
  final int? fishCount;
  final double? averageWeightValue;
  final String averageWeightUnit;
  final String healthStatus;
  final String feedingObservation;
  final String behaviorObservation;
  final String notes;
  final DateTime recordedAt;
}

String _readString(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

DateTime? _readDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

double? _readDoubleNullable(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

int? _readIntNullable(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double? _tryParseDouble(String text) {
  final normalized = text.trim();
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}

int? _tryParseInt(String text) {
  final normalized = text.trim();
  if (normalized.isEmpty) return null;
  return int.tryParse(normalized);
}

String _formatNumber(num value) {
  if (value is int) return value.toString();
  final asDouble = value.toDouble();
  return asDouble == asDouble.truncateToDouble()
      ? asDouble.toInt().toString()
      : asDouble.toStringAsFixed(1);
}

String _formatDateTime(DateTime value) {
  return DateFormat('MMM d, y').format(value.toLocal());
}

Color _healthColor(String status) {
  switch (status) {
    case 'critical':
      return AquaponicsColors.statusDanger;
    case 'poor':
      return AquaponicsColors.statusWarning;
    case 'fair':
      return AquaponicsColors.adminInfo;
    default:
      return AquaponicsColors.statusSafe;
  }
}

Color _leafConditionColor(String condition) {
  switch (condition) {
    case 'yellowing':
    case 'wilting':
    case 'nutrient_deficiency':
      return AquaponicsColors.statusWarning;
    case 'pest_damage':
      return AquaponicsColors.statusDanger;
    default:
      return AquaponicsColors.statusSafe;
  }
}

Color _observationColor(String observation) {
  switch (observation) {
    case 'low_appetite':
    case 'sluggish':
    case 'hiding':
      return AquaponicsColors.statusWarning;
    case 'overfeeding_signs':
    case 'missed_feeding':
    case 'gasping':
    case 'aggressive':
    case 'mortality_observed':
      return AquaponicsColors.statusDanger;
    default:
      return AquaponicsColors.statusSafe;
  }
}
