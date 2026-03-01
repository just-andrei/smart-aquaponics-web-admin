import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

String _firebaseErrorMessage(Object error) {
  if (error is FirebaseException) {
    return error.message ?? error.code;
  }
  return error.toString();
}

class MasterSetsView extends StatefulWidget {
  const MasterSetsView({super.key});

  @override
  State<MasterSetsView> createState() => _MasterSetsViewState();
}

class _MasterSetsViewState extends State<MasterSetsView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchCtrl = TextEditingController();
  String? _selectedDocId;

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  String _cleanName(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.length >= 2 && raw.startsWith('"') && raw.endsWith('"')) {
      return raw.substring(1, raw.length - 1);
    }
    return raw;
  }

  Map<String, dynamic> _extractMasterSetData(DocumentSnapshot doc) {
    final raw = (doc.data() as Map<String, dynamic>? ?? <String, dynamic>{});
    return {
      'id': doc.id,
      'set_name': _cleanName(raw['set_name']),
      'min_temp': _toDouble(raw['min_temp']),
      'max_temp': _toDouble(raw['max_temp']),
      'min_ph': _toDouble(raw['min_ph']),
      'max_ph': _toDouble(raw['max_ph']),
      'min_do': _toDouble(raw['min_do']),
      'max_do': _toDouble(raw['max_do']),
      'min_salinity': _toDouble(raw['min_salinity']),
      'max_salinity': _toDouble(raw['max_salinity']),
      'min_turbidity': _toDouble(raw['min_turbidity']),
      'max_turbidity': _toDouble(raw['max_turbidity']),
      'min_ammonia': _toDouble(raw['min_ammonia']),
      'max_ammonia': _toDouble(raw['max_ammonia']),
    };
  }

  bool _matchesSetNameSearch(QueryDocumentSnapshot doc, String query) {
    if (query.isEmpty) return true;
    final data = doc.data() as Map<String, dynamic>;
    final setName = _cleanName(data['set_name']).toLowerCase();
    return setName.contains(query.toLowerCase());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _extractExistingMasterSets() async {
    try {
      final snapshot = await _firestore.collection('master_sets').get();
      final extracted =
          snapshot.docs.map((doc) => _extractMasterSetData(doc)).toList();
      debugPrint('Extracted master_sets (${extracted.length}): $extracted');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Extracted ${extracted.length} system sets')),
      );
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Extraction failed: ${_firebaseErrorMessage(e)}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('master_sets').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading sets: ${snapshot.error}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allData = snapshot.data?.docs ?? [];

          return LayoutBuilder(
            builder: (context, constraints) {
              if (allData.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'No master sets found.',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      const Text('Collection: master_sets'),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _extractExistingMasterSets,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Check Firebase Data'),
                      ),
                    ],
                  ),
                );
              }

              final rowsPerPage = math.min(
                PaginatedDataTable.defaultRowsPerPage,
                math.max(1, allData.length),
              );
              const baseTableWidth = 1080.0;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _searchCtrl,
                        builder: (context, value, _) {
                          final query = value.text.trim();
                          final filteredData = allData
                              .where((doc) => _matchesSetNameSearch(doc, query))
                              .toList();
                          QueryDocumentSnapshot? selectedDoc;
                          for (final doc in filteredData) {
                            if (doc.id == _selectedDocId) {
                              selectedDoc = doc;
                              break;
                            }
                          }

                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton(
                                onPressed: () => _showSetDialog(null),
                                child: const Text('Create'),
                              ),
                              OutlinedButton(
                                onPressed: selectedDoc == null
                                    ? null
                                    : () => _editSet(selectedDoc!),
                                child: const Text('Update'),
                              ),
                              FilledButton(
                                onPressed: selectedDoc == null
                                    ? null
                                    : () {
                                        final data =
                                            selectedDoc!.data() as Map<String, dynamic>;
                                        final name =
                                            (data['set_name'] ?? 'Unnamed Set')
                                                .toString();
                                        _deleteSet(selectedDoc.id, name);
                                      },
                                style: FilledButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.error,
                                ),
                                child: const Text('Delete'),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 360,
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          labelText: 'Search by Set Name',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => _searchCtrl.clear(),
                          ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _searchCtrl,
                      builder: (context, value, _) {
                        final query = value.text.trim();
                        final filteredData = allData
                            .where((doc) => _matchesSetNameSearch(doc, query))
                            .toList();
                        final filteredRowsPerPage = math.min(
                          rowsPerPage,
                          math.max(1, filteredData.length),
                        );
                        final source = _MasterSetsDataSource(
                          filteredData,
                          selectedDocId: _selectedDocId,
                          onSelect: (id) {
                            setState(() {
                              _selectedDocId = id;
                            });
                          },
                        );

                        if (filteredData.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              'No sets match your search.',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }

                        return ClipRect(
                          child: FittedBox(
                            fit: BoxFit.fitWidth,
                            alignment: Alignment.topLeft,
                            child: SizedBox(
                              width: baseTableWidth,
                              child: PaginatedDataTable(
                                header: const Text('System Sets'),
                                columnSpacing: 12,
                                horizontalMargin: 10,
                                headingRowHeight: 48,
                                dataRowMinHeight: 44,
                                dataRowMaxHeight: 44,
                                columns: const [
                                  DataColumn(label: Text('Set Name')),
                                  DataColumn(label: Text('Temp (Min-Max)')),
                                  DataColumn(label: Text('pH (Min-Max)')),
                                  DataColumn(label: Text('DO (Min-Max)')),
                                  DataColumn(label: Text('Salinity (Min-Max)')),
                                  DataColumn(label: Text('Turbidity (Min-Max)')),
                                  DataColumn(label: Text('Ammonia (Min-Max)')),
                                ],
                                source: source,
                                rowsPerPage: filteredRowsPerPage,
                                showCheckboxColumn: false,
                                actions: [
                                  IconButton(
                                    icon: const Icon(Icons.refresh),
                                    onPressed: _extractExistingMasterSets,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showSetDialog(DocumentSnapshot? document) {
    showDialog(
      context: context,
      builder: (context) => _MasterSetDialog(document: document),
    );
  }

  void _editSet(DocumentSnapshot document) {
    _showSetDialog(document);
  }

  void _deleteSet(String id, String name) {
    final rootContext = context;
    showDialog(
      context: rootContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete the set "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(rootContext).colorScheme.error,
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await _firestore.collection('master_sets').doc(id).delete();
                if (!rootContext.mounted) return;
                ScaffoldMessenger.of(rootContext).showSnackBar(
                  SnackBar(content: Text('Deleted "$name"')),
                );
              } on Object catch (e) {
                if (!rootContext.mounted) return;
                ScaffoldMessenger.of(rootContext).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Error deleting set: ${_firebaseErrorMessage(e)}',
                    ),
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _MasterSetsDataSource extends DataTableSource {
  final List<QueryDocumentSnapshot> _data;
  final String? selectedDocId;
  final ValueChanged<String?> onSelect;

  _MasterSetsDataSource(
    this._data, {
    required this.selectedDocId,
    required this.onSelect,
  });

  @override
  DataRow? getRow(int index) {
    if (index >= _data.length) return null;
    final doc = _data[index];
    final data = doc.data() as Map<String, dynamic>;

    final name = data['set_name'] ?? 'Unnamed Set';
    final minAmmonia = data['min_ammonia'] ?? 0;
    final maxAmmonia = data['max_ammonia'] ?? 0;
    final minDo = data['min_do'] ?? 0;
    final maxDo = data['max_do'] ?? 0;
    final minPh = data['min_ph'] ?? 0;
    final maxPh = data['max_ph'] ?? 0;
    final minSalinity = data['min_salinity'] ?? 0;
    final maxSalinity = data['max_salinity'] ?? 0;
    final minTemp = data['min_temp'] ?? 0;
    final maxTemp = data['max_temp'] ?? 0;
    final minTurbidity = data['min_turbidity'] ?? 0;
    final maxTurbidity = data['max_turbidity'] ?? 0;

    return DataRow.byIndex(index: index, selected: doc.id == selectedDocId, onSelectChanged: (selected) {
      onSelect(selected == true ? doc.id : null);
    }, cells: [
      DataCell(Text(name.toString(), style: const TextStyle(fontWeight: FontWeight.bold))),
      DataCell(Text('$minTemp - $maxTemp')),
      DataCell(Text('$minPh - $maxPh')),
      DataCell(Text('$minDo - $maxDo')),
      DataCell(Text('$minSalinity - $maxSalinity')),
      DataCell(Text('$minTurbidity - $maxTurbidity')),
      DataCell(Text('$minAmmonia - $maxAmmonia')),
    ]);
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => _data.length;

  @override
  int get selectedRowCount => 0;
}

class _MasterSetDialog extends StatefulWidget {
  final DocumentSnapshot? document;
  const _MasterSetDialog({this.document});

  @override
  State<_MasterSetDialog> createState() => _MasterSetDialogState();
}

class _MasterSetDialogState extends State<_MasterSetDialog> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  late TextEditingController _nameCtrl;
  late TextEditingController _minTempCtrl;
  late TextEditingController _maxTempCtrl;
  late TextEditingController _minPhCtrl;
  late TextEditingController _maxPhCtrl;
  late TextEditingController _minDoCtrl;
  late TextEditingController _maxDoCtrl;
  late TextEditingController _minSalinityCtrl;
  late TextEditingController _maxSalinityCtrl;
  late TextEditingController _minTurbidityCtrl;
  late TextEditingController _maxTurbidityCtrl;
  late TextEditingController _minAmmoniaCtrl;
  late TextEditingController _maxAmmoniaCtrl;

  @override
  void initState() {
    super.initState();
    final data = widget.document?.data() as Map<String, dynamic>? ?? {};
    
    _nameCtrl = TextEditingController(text: data['set_name']?.toString() ?? '');
    _minTempCtrl = TextEditingController(text: data['min_temp']?.toString() ?? '');
    _maxTempCtrl = TextEditingController(text: data['max_temp']?.toString() ?? '');
    _minPhCtrl = TextEditingController(text: data['min_ph']?.toString() ?? '');
    _maxPhCtrl = TextEditingController(text: data['max_ph']?.toString() ?? '');
    _minDoCtrl = TextEditingController(text: data['min_do']?.toString() ?? '');
    _maxDoCtrl = TextEditingController(text: data['max_do']?.toString() ?? '');
    _minSalinityCtrl = TextEditingController(text: data['min_salinity']?.toString() ?? '');
    _maxSalinityCtrl = TextEditingController(text: data['max_salinity']?.toString() ?? '');
    _minTurbidityCtrl = TextEditingController(text: data['min_turbidity']?.toString() ?? '');
    _maxTurbidityCtrl = TextEditingController(text: data['max_turbidity']?.toString() ?? '');
    _minAmmoniaCtrl = TextEditingController(text: data['min_ammonia']?.toString() ?? '');
    _maxAmmoniaCtrl = TextEditingController(text: data['max_ammonia']?.toString() ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _minTempCtrl.dispose();
    _maxTempCtrl.dispose();
    _minPhCtrl.dispose();
    _maxPhCtrl.dispose();
    _minDoCtrl.dispose();
    _maxDoCtrl.dispose();
    _minSalinityCtrl.dispose();
    _maxSalinityCtrl.dispose();
    _minTurbidityCtrl.dispose();
    _maxTurbidityCtrl.dispose();
    _minAmmoniaCtrl.dispose();
    _maxAmmoniaCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      final data = {
        'set_name': _nameCtrl.text.trim(),
        'min_temp': double.tryParse(_minTempCtrl.text) ?? 0,
        'max_temp': double.tryParse(_maxTempCtrl.text) ?? 0,
        'min_ph': double.tryParse(_minPhCtrl.text) ?? 0,
        'max_ph': double.tryParse(_maxPhCtrl.text) ?? 0,
        'min_do': double.tryParse(_minDoCtrl.text) ?? 0,
        'max_do': double.tryParse(_maxDoCtrl.text) ?? 0,
        'min_salinity': double.tryParse(_minSalinityCtrl.text) ?? 0,
        'max_salinity': double.tryParse(_maxSalinityCtrl.text) ?? 0,
        'min_turbidity': double.tryParse(_minTurbidityCtrl.text) ?? 0,
        'max_turbidity': double.tryParse(_maxTurbidityCtrl.text) ?? 0,
        'min_ammonia': double.tryParse(_minAmmoniaCtrl.text) ?? 0,
        'max_ammonia': double.tryParse(_maxAmmoniaCtrl.text) ?? 0,
        'updated_at': FieldValue.serverTimestamp(),
      };

      try {
        if (widget.document == null) {
          await FirebaseFirestore.instance.collection('master_sets').add({
            ...data,
            'created_at': FieldValue.serverTimestamp(),
          });
        } else {
          await widget.document!.reference.update(data);
        }
        if (mounted) Navigator.pop(context);
      } on Object catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: ${_firebaseErrorMessage(e)}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.document != null;
    return Dialog(
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEditing ? 'Edit Master Set' : 'Create Master Set',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            Flexible(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(labelText: 'Set Name', border: OutlineInputBorder()),
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      _buildRangeRow('Temperature (°C)', _minTempCtrl, _maxTempCtrl),
                      const SizedBox(height: 16),
                      _buildRangeRow('pH Level', _minPhCtrl, _maxPhCtrl),
                      const SizedBox(height: 16),
                      _buildRangeRow('Dissolved Oxygen (mg/L)', _minDoCtrl, _maxDoCtrl),
                      const SizedBox(height: 16),
                      _buildRangeRow('Salinity (ppt)', _minSalinityCtrl, _maxSalinityCtrl),
                      const SizedBox(height: 16),
                      _buildRangeRow('Turbidity (NTU)', _minTurbidityCtrl, _maxTurbidityCtrl),
                      const SizedBox(height: 16),
                      _buildRangeRow('Ammonia (mg/L)', _minAmmoniaCtrl, _maxAmmoniaCtrl),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 16),
                FilledButton(
                  onPressed: _save,
                  child: Text(isEditing ? 'Update' : 'Create'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRangeRow(String label, TextEditingController minCtrl, TextEditingController maxCtrl) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextFormField(
            controller: minCtrl,
            decoration: InputDecoration(labelText: 'Min $label', border: const OutlineInputBorder()),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TextFormField(
            controller: maxCtrl,
            decoration: InputDecoration(labelText: 'Max $label', border: const OutlineInputBorder()),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
        ),
      ],
    );
  }
}
