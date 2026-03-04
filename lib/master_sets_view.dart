import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

const List<String> _plantTypeOptions = <String>['Leafy Greens'];
const List<String> _aquacultureTypeOptions = <String>['Fin fish', 'Shellfish'];

String _firebaseErrorMessage(Object error) {
  if (error is FirebaseException) {
    return error.message ?? error.code;
  }
  return error.toString();
}

String _shortDescription(dynamic value) {
  final text = (value ?? '').toString().trim();
  if (text.isEmpty) return 'No description';
  return text;
}

String _rangeText(dynamic min, dynamic max) {
  final minValue = min is num ? min.toDouble() : double.tryParse('$min') ?? 0;
  final maxValue = max is num ? max.toDouble() : double.tryParse('$max') ?? 0;
  return '${minValue.toStringAsFixed(1)} - ${maxValue.toStringAsFixed(1)}';
}

String _valueText(dynamic value) {
  if (value == null) return '';
  if (value is num) return value.toString();
  return value.toString();
}

String _resolvePlantKey(String documentId, Map<String, dynamic> data) {
  final customId = _valueText(data['plant_id']).trim();
  if (customId.isNotEmpty) return customId;
  return documentId;
}

String _resolveAquacultureKey(String documentId, Map<String, dynamic> data) {
  final fishId = _valueText(data['fish_id']).trim();
  if (fishId.isNotEmpty) return fishId;
  final aquacultureId = _valueText(data['aquaculture_id']).trim();
  if (aquacultureId.isNotEmpty) return aquacultureId;
  return documentId;
}

List<String> _toIdList(dynamic value) {
  if (value is! List) return <String>[];
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

Map<String, Map<String, int>> _toPlantOverrides(dynamic value) {
  final overrides = <String, Map<String, int>>{};
  if (value is! List) return overrides;

  for (final item in value) {
    if (item is String) {
      final plantId = item.trim();
      if (plantId.isNotEmpty) {
        overrides[plantId] = <String, int>{'ideal_days': 0, 'batches': 0};
      }
      continue;
    }
    if (item is! Map) continue;
    final rawId = item['plant_id'];
    final plantId = rawId?.toString().trim() ?? '';
    if (plantId.isEmpty) continue;

    final idealDays = int.tryParse('${item['ideal_days'] ?? ''}') ?? 0;
    final batches = int.tryParse('${item['batches'] ?? ''}') ?? 0;
    overrides[plantId] = <String, int>{
      'ideal_days': idealDays,
      'batches': batches,
    };
  }

  return overrides;
}

String _timestampText(dynamic value) {
  if (value is Timestamp) return value.toDate().toString();
  return value?.toString() ?? '';
}

String _formatFeedingTime(TimeOfDay time) {
  final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
  final minute = time.minute.toString().padLeft(2, '0');
  final period = time.period == DayPeriod.am ? 'AM' : 'PM';
  return '${hour.toString().padLeft(2, '0')}:$minute $period';
}

Widget _viewRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 150,
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        Expanded(child: Text(value.isEmpty ? 'N/A' : value)),
      ],
    ),
  );
}

Future<void> _showViewAquacultureDialog(
  BuildContext context,
  DocumentSnapshot doc,
) async {
  final data = (doc.data() as Map<String, dynamic>? ?? <String, dynamic>{});
  final compatiblePlantOverrides = _toPlantOverrides(data['compatible_plants']);
  final plantsSnap = await FirebaseFirestore.instance.collection('plants').get();
  final plantNameById = <String, String>{
    for (final item in plantsSnap.docs)
      _resolvePlantKey(item.id, item.data()): (item.data()['name'] ?? item.id).toString(),
  };
  final compatiblePlantNames = compatiblePlantOverrides.entries.map((entry) {
    final plantId = entry.key;
    final idealDays = entry.value['ideal_days'] ?? 0;
    final batches = entry.value['batches'] ?? 0;
    final name = plantNameById[plantId] ?? 'Unknown Plant';
    return '$name ($idealDays days | $batches batches)';
  }).toList();
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('View Aquaculture'),
        content: SizedBox(
          width: 760,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _viewRow('ID', doc.id),
                _viewRow('Name', _valueText(data['name'])),
                _viewRow('Type', _valueText(data['type'])),
                _viewRow('Description', _valueText(data['description'])),
                _viewRow('Temp', _rangeText(data['min_temp'], data['max_temp'])),
                _viewRow('pH', _rangeText(data['min_ph'], data['max_ph'])),
                _viewRow('DO', _rangeText(data['min_do'], data['max_do'])),
                _viewRow('Salinity', _rangeText(data['min_salinity'], data['max_salinity'])),
                _viewRow('Turbidity', _rangeText(data['min_turbidity'], data['max_turbidity'])),
                _viewRow('Ammonia', _rangeText(data['min_ammonia'], data['max_ammonia'])),
                _viewRow('Updated At', _timestampText(data['updated_at'])),
                const SizedBox(height: 8),
                const Text('Compatible Plants', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: compatiblePlantNames.isEmpty
                      ? const [Chip(label: Text('None'))]
                      : compatiblePlantNames.map((name) => Chip(label: Text(name))).toList(),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}

Future<void> _showViewPlantDialog(
  BuildContext context,
  DocumentSnapshot doc,
) async {
  final data = (doc.data() as Map<String, dynamic>? ?? <String, dynamic>{});
  final compatibleFishIds = _toIdList(data['compatible_fish']);
  final fishSnap = await FirebaseFirestore.instance.collection('aquaculture').get();
  final fishNameById = <String, String>{
    for (final item in fishSnap.docs)
      _resolveAquacultureKey(item.id, item.data()): (item.data()['name'] ?? item.id).toString(),
  };
  final compatibleFishNames =
      compatibleFishIds.map((id) => fishNameById[id] ?? 'Unknown Fish').toList();
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('View Plant'),
        content: SizedBox(
          width: 700,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _viewRow('ID', doc.id),
                _viewRow('Name', _valueText(data['name'])),
                _viewRow('Type', _valueText(data['type'])),
                _viewRow('Description', _valueText(data['description'])),
                _viewRow('Updated At', _timestampText(data['updated_at'])),
                const SizedBox(height: 8),
                const Text('Compatible Fish', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: compatibleFishNames.isEmpty
                      ? const [Chip(label: Text('None'))]
                      : compatibleFishNames.map((name) => Chip(label: Text(name))).toList(),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}

Future<void> _showEditAquacultureDialog(
  BuildContext context,
  DocumentSnapshot doc,
) async {
  final data = (doc.data() as Map<String, dynamic>? ?? <String, dynamic>{});
  final currentFishCustomId = _valueText(data['fish_id']).trim().isNotEmpty
      ? _valueText(data['fish_id']).trim()
      : _valueText(data['aquaculture_id']).trim().isNotEmpty
          ? _valueText(data['aquaculture_id']).trim()
          : doc.id;
  final plantsSnap = await FirebaseFirestore.instance.collection('plants').get();
  final plantCustomIdToDocId = <String, String>{};
  final plantOptions = plantsSnap.docs
      .map((item) {
        final plantData = item.data();
        final customId = _valueText(plantData['plant_id']).trim().isEmpty
            ? item.id
            : _valueText(plantData['plant_id']).trim();
        plantCustomIdToDocId[customId] = item.id;
        return _EntityOption(
          id: customId,
          name: (plantData['name'] ?? customId).toString(),
        );
      })
      .toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  final originalPlantOverrides = _toPlantOverrides(data['compatible_plants']);
  final originalCompatiblePlants = originalPlantOverrides.keys.toSet();
  final selectedCompatiblePlants = Set<String>.from(originalCompatiblePlants);
  final plantOverrides = <String, Map<String, int>>{
    for (final entry in originalPlantOverrides.entries)
      entry.key: <String, int>{
        'ideal_days': entry.value['ideal_days'] ?? 0,
        'batches': entry.value['batches'] ?? 0,
      },
  };
  if (!context.mounted) return;
  final formKey = GlobalKey<FormState>();

  final nameCtrl = TextEditingController(text: _valueText(data['name']));
  final typeCtrl = TextEditingController(text: _valueText(data['type']));
  String? selectedType = _aquacultureTypeOptions.contains(typeCtrl.text.trim())
      ? typeCtrl.text.trim()
      : null;
  final descriptionCtrl = TextEditingController(
    text: _valueText(data['description']),
  );
  final minTempCtrl = TextEditingController(text: _valueText(data['min_temp']));
  final maxTempCtrl = TextEditingController(text: _valueText(data['max_temp']));
  final minPhCtrl = TextEditingController(text: _valueText(data['min_ph']));
  final maxPhCtrl = TextEditingController(text: _valueText(data['max_ph']));
  final minDoCtrl = TextEditingController(text: _valueText(data['min_do']));
  final maxDoCtrl = TextEditingController(text: _valueText(data['max_do']));
  final minAmmoniaCtrl = TextEditingController(
    text: _valueText(data['min_ammonia']),
  );
  final maxAmmoniaCtrl = TextEditingController(
    text: _valueText(data['max_ammonia']),
  );
  final minSalinityCtrl = TextEditingController(
    text: _valueText(data['min_salinity']),
  );
  final maxSalinityCtrl = TextEditingController(
    text: _valueText(data['max_salinity']),
  );
  final minTurbidityCtrl = TextEditingController(
    text: _valueText(data['min_turbidity']),
  );
  final maxTurbidityCtrl = TextEditingController(
    text: _valueText(data['max_turbidity']),
  );
  final targetHarvestWeightCtrl = TextEditingController(
    text: _valueText(data['target_harvest_weight']),
  );
  final growOutPeriodCtrl = TextEditingController(
    text: _valueText(data['grow_out_period']),
  );
  final feedingTimes = List<String>.from(data['feeding_schedule'] ?? const []);

  String? requiredText(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    return null;
  }

  String? requiredDouble(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    if (double.tryParse(value.trim()) == null) return 'Enter a valid number';
    return null;
  }

  String? optionalDouble(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (double.tryParse(value.trim()) == null) return 'Enter a valid number';
    return null;
  }

  String? optionalInt(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (int.tryParse(value.trim()) == null) return 'Enter a valid whole number';
    return null;
  }

  double parseDouble(TextEditingController controller) {
    return double.parse(controller.text.trim());
  }

  double? parseOptionalDouble(TextEditingController controller) {
    final text = controller.text.trim();
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  int? parseOptionalInt(TextEditingController controller) {
    final text = controller.text.trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  Widget numberField(
    String label,
    TextEditingController controller, {
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: validator ?? requiredDouble,
    );
  }

  Future<void> saveFromDialog(BuildContext dialogContext) async {
    if (!formKey.currentState!.validate()) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(dialogContext);

    navigator.pop();

    try {
      final aquacultureRef =
          FirebaseFirestore.instance.collection('aquaculture').doc(doc.id);
      await aquacultureRef.update({
        'name': nameCtrl.text.trim(),
        'type': selectedType?.trim() ?? '',
        'description': descriptionCtrl.text.trim(),
        'min_temp': parseDouble(minTempCtrl),
        'max_temp': parseDouble(maxTempCtrl),
        'min_ph': parseDouble(minPhCtrl),
        'max_ph': parseDouble(maxPhCtrl),
        'min_do': parseDouble(minDoCtrl),
        'max_do': parseDouble(maxDoCtrl),
        'min_ammonia': parseDouble(minAmmoniaCtrl),
        'max_ammonia': parseDouble(maxAmmoniaCtrl),
        'min_salinity': parseDouble(minSalinityCtrl),
        'max_salinity': parseDouble(maxSalinityCtrl),
        'min_turbidity': parseDouble(minTurbidityCtrl),
        'max_turbidity': parseDouble(maxTurbidityCtrl),
        'target_harvest_weight': parseOptionalDouble(targetHarvestWeightCtrl),
        'grow_out_period': parseOptionalInt(growOutPeriodCtrl),
        'feeding_schedule': feedingTimes,
        'compatible_plants': plantOverrides.entries.map((entry) {
          return <String, dynamic>{
            'plant_id': entry.key,
            'ideal_days':
                int.tryParse('${entry.value['ideal_days'] ?? ''}') ?? 0,
            'batches': int.tryParse('${entry.value['batches'] ?? ''}') ?? 0,
          };
        }).toList(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      final toAdd = selectedCompatiblePlants.difference(originalCompatiblePlants);
      final toRemove = originalCompatiblePlants.difference(selectedCompatiblePlants);

      if (toAdd.isNotEmpty) {
        for (final customId in toAdd) {
          final plantDocId = plantCustomIdToDocId[customId] ?? customId;
          await FirebaseFirestore.instance.collection('plants').doc(plantDocId).update({
            'compatible_fish': FieldValue.arrayUnion([currentFishCustomId]),
            'updated_at': FieldValue.serverTimestamp(),
          });
        }
      }

      if (toRemove.isNotEmpty) {
        for (final customId in toRemove) {
          final plantDocId = plantCustomIdToDocId[customId] ?? customId;
          await FirebaseFirestore.instance.collection('plants').doc(plantDocId).update({
            'compatible_fish': FieldValue.arrayRemove([currentFishCustomId]),
            'updated_at': FieldValue.serverTimestamp(),
          });
        }
      }

      messenger.showSnackBar(
        const SnackBar(content: Text('Aquaculture updated successfully')),
      );
    } on Object catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to update aquaculture: ${_firebaseErrorMessage(e)}'),
        ),
      );
    } finally {
      nameCtrl.dispose();
      typeCtrl.dispose();
      descriptionCtrl.dispose();
      minTempCtrl.dispose();
      maxTempCtrl.dispose();
      minPhCtrl.dispose();
      maxPhCtrl.dispose();
      minDoCtrl.dispose();
      maxDoCtrl.dispose();
      minAmmoniaCtrl.dispose();
      maxAmmoniaCtrl.dispose();
      minSalinityCtrl.dispose();
      maxSalinityCtrl.dispose();
      minTurbidityCtrl.dispose();
      maxTurbidityCtrl.dispose();
      targetHarvestWeightCtrl.dispose();
      growOutPeriodCtrl.dispose();
    }
  }

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setStateDialog) {
          return AlertDialog(
            title: const Text('Edit Aquaculture'),
            content: SizedBox(
              width: 760,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Species Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: requiredText,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedType,
                        decoration: const InputDecoration(
                          labelText: 'Aquaculture Type',
                          border: OutlineInputBorder(),
                        ),
                        items: _aquacultureTypeOptions
                            .map(
                              (type) => DropdownMenuItem<String>(
                                value: type,
                                child: Text(type),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setStateDialog(() {
                            selectedType = value;
                            typeCtrl.text = value ?? '';
                          });
                        },
                        validator: (value) =>
                            value == null || value.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descriptionCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Detailed Description',
                          border: OutlineInputBorder(),
                        ),
                        validator: requiredText,
                      ),
                      const SizedBox(height: 12),
                      GridView.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 4,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          numberField('Minimum Temperature (°C)', minTempCtrl),
                          numberField('Maximum Temperature (°C)', maxTempCtrl),
                          numberField('Minimum pH Level', minPhCtrl),
                          numberField('Maximum pH Level', maxPhCtrl),
                          numberField('Minimum Dissolved Oxygen (mg/L)', minDoCtrl),
                          numberField('Maximum Dissolved Oxygen (mg/L)', maxDoCtrl),
                          numberField('Minimum Ammonia (ppm)', minAmmoniaCtrl),
                          numberField('Maximum Ammonia (ppm)', maxAmmoniaCtrl),
                          numberField('Minimum Salinity (ppt)', minSalinityCtrl),
                          numberField('Maximum Salinity (ppt)', maxSalinityCtrl),
                          numberField('Minimum Turbidity (NTU)', minTurbidityCtrl),
                          numberField('Maximum Turbidity (NTU)', maxTurbidityCtrl),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Growth Parameters',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 8),
                      GridView.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 4,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          numberField(
                            'Target Harvest Weight (g)',
                            targetHarvestWeightCtrl,
                            validator: optionalDouble,
                          ),
                          numberField(
                            'Grow Out Period (days)',
                            growOutPeriodCtrl,
                            validator: optionalInt,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Feeding Schedule',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (feedingTimes.isEmpty)
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('No feeding times added.'),
                        )
                      else
                        Column(
                          children: feedingTimes
                              .asMap()
                              .entries
                              .map(
                                (entry) => Row(
                                  children: [
                                    Expanded(child: Text(entry.value)),
                                    IconButton(
                                      onPressed: () {
                                        setStateDialog(() {
                                          feedingTimes.removeAt(entry.key);
                                        });
                                      },
                                      icon: const Icon(Icons.delete_outline),
                                      tooltip: 'Remove',
                                    ),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final pickedTime = await showTimePicker(
                              context: dialogContext,
                              initialTime: TimeOfDay.now(),
                            );
                            if (pickedTime == null) return;
                            final formatted = _formatFeedingTime(pickedTime);
                            setStateDialog(() {
                              feedingTimes.add(formatted);
                            });
                          },
                          icon: const Icon(Icons.add_alarm),
                          label: const Text('Add Feeding Time'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Compatible Plants',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 220),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: plantOptions.isEmpty
                            ? const Align(
                                alignment: Alignment.centerLeft,
                                child: Text('No plants found.'),
                              )
                            : ListView(
                                shrinkWrap: true,
                                children: plantOptions.map((option) {
                                  final customId = option.id;
                                  final checked = selectedCompatiblePlants.contains(customId);
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CheckboxListTile(
                                        value: checked,
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(option.name),
                                        onChanged: (value) {
                                          setStateDialog(() {
                                            if (value == true) {
                                              selectedCompatiblePlants.add(customId);
                                              plantOverrides.putIfAbsent(
                                                customId,
                                                () => <String, int>{
                                                  'ideal_days': 0,
                                                  'batches': 0,
                                                },
                                              );
                                            } else {
                                              selectedCompatiblePlants.remove(customId);
                                              plantOverrides.remove(customId);
                                            }
                                          });
                                        },
                                      ),
                                      if (checked)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            left: 12,
                                            right: 12,
                                            bottom: 8,
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: TextFormField(
                                                  initialValue:
                                                      '${plantOverrides[customId]?['ideal_days'] ?? 0}',
                                                  keyboardType: TextInputType.number,
                                                  decoration: const InputDecoration(
                                                    labelText:
                                                        'Ideal Days to Harvest (for this fish)',
                                                    border: OutlineInputBorder(),
                                                    isDense: true,
                                                  ),
                                                  onChanged: (value) {
                                                    plantOverrides.putIfAbsent(
                                                      customId,
                                                      () => <String, int>{
                                                        'ideal_days': 0,
                                                        'batches': 0,
                                                      },
                                                    );
                                                    plantOverrides[customId]!['ideal_days'] =
                                                        int.tryParse(value.trim()) ?? 0;
                                                  },
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: TextFormField(
                                                  initialValue:
                                                      '${plantOverrides[customId]?['batches'] ?? 0}',
                                                  keyboardType: TextInputType.number,
                                                  decoration: const InputDecoration(
                                                    labelText: 'Number of Batches',
                                                    border: OutlineInputBorder(),
                                                    isDense: true,
                                                  ),
                                                  onChanged: (value) {
                                                    plantOverrides.putIfAbsent(
                                                      customId,
                                                      () => <String, int>{
                                                        'ideal_days': 0,
                                                        'batches': 0,
                                                      },
                                                    );
                                                    plantOverrides[customId]!['batches'] =
                                                        int.tryParse(value.trim()) ?? 0;
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  );
                                }).toList(),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => saveFromDialog(dialogContext),
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> _showEditPlantDialog(
  BuildContext context,
  DocumentSnapshot doc,
) async {
  final data = (doc.data() as Map<String, dynamic>? ?? <String, dynamic>{});
  final currentPlantCustomId = _valueText(data['plant_id']).trim().isNotEmpty
      ? _valueText(data['plant_id']).trim()
      : doc.id;
  final fishSnap = await FirebaseFirestore.instance.collection('aquaculture').get();
  final fishCustomIdToDocId = <String, String>{};
  final fishOptions = fishSnap.docs
      .map((item) {
        final fishData = item.data();
        final fishId = _valueText(fishData['fish_id']).trim();
        final aquacultureId = _valueText(fishData['aquaculture_id']).trim();
        final customId = fishId.isNotEmpty
            ? fishId
            : aquacultureId.isNotEmpty
                ? aquacultureId
                : item.id;
        fishCustomIdToDocId[customId] = item.id;
        return _EntityOption(
          id: customId,
          name: (fishData['name'] ?? customId).toString(),
        );
      })
      .toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  final originalCompatibleFish = _toIdList(data['compatible_fish']).toSet();
  final selectedCompatibleFish = Set<String>.from(originalCompatibleFish);
  if (!context.mounted) return;

  final formKey = GlobalKey<FormState>();
  final nameCtrl = TextEditingController(text: _valueText(data['name']));
  final typeCtrl = TextEditingController(text: _valueText(data['type']));
  String? selectedType = _plantTypeOptions.contains(typeCtrl.text.trim())
      ? typeCtrl.text.trim()
      : null;
  final descriptionCtrl = TextEditingController(text: _valueText(data['description']));
  final idealDaysToHarvestCtrl = TextEditingController(
    text: _valueText(data['ideal_days_to_harvest']),
  );
  final numberOfBatchesCtrl = TextEditingController(
    text: _valueText(data['number_of_batches']),
  );

  String? requiredText(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    return null;
  }

  String? optionalInt(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (int.tryParse(value.trim()) == null) return 'Enter a valid whole number';
    return null;
  }

  int? parseOptionalInt(TextEditingController controller) {
    final text = controller.text.trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setStateDialog) {
          Future<void> saveFromDialog() async {
            if (!formKey.currentState!.validate()) return;
            final messenger = ScaffoldMessenger.of(context);
            final navigator = Navigator.of(dialogContext);
            navigator.pop();

            try {
              final plantRef = FirebaseFirestore.instance.collection('plants').doc(doc.id);
              await plantRef.update({
                'name': nameCtrl.text.trim(),
                'type': selectedType?.trim() ?? '',
                'description': descriptionCtrl.text.trim(),
                'ideal_days_to_harvest': parseOptionalInt(
                  idealDaysToHarvestCtrl,
                ),
                'number_of_batches': parseOptionalInt(numberOfBatchesCtrl),
                'updated_at': FieldValue.serverTimestamp(),
              });

              final toAdd = selectedCompatibleFish.difference(originalCompatibleFish);
              final toRemove = originalCompatibleFish.difference(selectedCompatibleFish);
              final defaultIdealDays =
                  parseOptionalInt(idealDaysToHarvestCtrl) ?? 0;
              final defaultBatches =
                  parseOptionalInt(numberOfBatchesCtrl) ?? 0;

              Future<void> upsertPlantOverrideForFish(String fishDocId) async {
                final fishRef = FirebaseFirestore.instance
                    .collection('aquaculture')
                    .doc(fishDocId);
                await FirebaseFirestore.instance.runTransaction((tx) async {
                  final fishSnap = await tx.get(fishRef);
                  final fishData = fishSnap.data() ?? <String, dynamic>{};
                  final overrides = _toPlantOverrides(fishData['compatible_plants']);
                  overrides[currentPlantCustomId] = <String, int>{
                    'ideal_days': defaultIdealDays,
                    'batches': defaultBatches,
                  };
                  tx.update(fishRef, {
                    'compatible_plants': overrides.entries
                        .map(
                          (entry) => <String, dynamic>{
                            'plant_id': entry.key,
                            'ideal_days': entry.value['ideal_days'] ?? 0,
                            'batches': entry.value['batches'] ?? 0,
                          },
                        )
                        .toList(),
                    'updated_at': FieldValue.serverTimestamp(),
                  });
                });
              }

              Future<void> removePlantOverrideForFish(String fishDocId) async {
                final fishRef = FirebaseFirestore.instance
                    .collection('aquaculture')
                    .doc(fishDocId);
                await FirebaseFirestore.instance.runTransaction((tx) async {
                  final fishSnap = await tx.get(fishRef);
                  final fishData = fishSnap.data() ?? <String, dynamic>{};
                  final overrides = _toPlantOverrides(fishData['compatible_plants']);
                  overrides.remove(currentPlantCustomId);
                  tx.update(fishRef, {
                    'compatible_plants': overrides.entries
                        .map(
                          (entry) => <String, dynamic>{
                            'plant_id': entry.key,
                            'ideal_days': entry.value['ideal_days'] ?? 0,
                            'batches': entry.value['batches'] ?? 0,
                          },
                        )
                        .toList(),
                    'updated_at': FieldValue.serverTimestamp(),
                  });
                });
              }

              if (toAdd.isNotEmpty) {
                await plantRef.update({
                  'compatible_fish': FieldValue.arrayUnion(toAdd.toList()),
                });
                for (final customId in toAdd) {
                  final fishDocId = fishCustomIdToDocId[customId] ?? customId;
                  await upsertPlantOverrideForFish(fishDocId);
                }
              }

              if (toRemove.isNotEmpty) {
                await plantRef.update({
                  'compatible_fish': FieldValue.arrayRemove(toRemove.toList()),
                });
                for (final customId in toRemove) {
                  final fishDocId = fishCustomIdToDocId[customId] ?? customId;
                  await removePlantOverrideForFish(fishDocId);
                }
              }

              messenger.showSnackBar(
                const SnackBar(content: Text('Plant updated successfully')),
              );
            } on Object catch (e) {
              messenger.showSnackBar(
                SnackBar(
                  content: Text('Failed to update plant: ${_firebaseErrorMessage(e)}'),
                ),
              );
            } finally {
              nameCtrl.dispose();
              typeCtrl.dispose();
              descriptionCtrl.dispose();
              idealDaysToHarvestCtrl.dispose();
              numberOfBatchesCtrl.dispose();
            }
          }

          return AlertDialog(
            title: const Text('Edit Plant'),
            content: SizedBox(
              width: 700,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'name',
                          border: OutlineInputBorder(),
                        ),
                        validator: requiredText,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedType,
                        decoration: const InputDecoration(
                          labelText: 'type',
                          border: OutlineInputBorder(),
                        ),
                        items: _plantTypeOptions
                            .map(
                              (type) => DropdownMenuItem<String>(
                                value: type,
                                child: Text(type),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setStateDialog(() {
                            selectedType = value;
                            typeCtrl.text = value ?? '';
                          });
                        },
                        validator: (value) =>
                            value == null || value.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descriptionCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'description',
                          border: OutlineInputBorder(),
                        ),
                        validator: requiredText,
                      ),
                      const SizedBox(height: 12),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Growth Parameters',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: idealDaysToHarvestCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Ideal Days to Harvest',
                          border: OutlineInputBorder(),
                        ),
                        validator: optionalInt,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: numberOfBatchesCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Number of Batches',
                          border: OutlineInputBorder(),
                        ),
                        validator: optionalInt,
                      ),
                      const SizedBox(height: 12),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Compatible Fish',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 220),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: fishOptions.isEmpty
                            ? const Align(
                                alignment: Alignment.centerLeft,
                                child: Text('No aquaculture records found.'),
                              )
                            : ListView(
                                shrinkWrap: true,
                                children: fishOptions.map((option) {
                                  final customId = option.id;
                                  final checked = selectedCompatibleFish.contains(customId);
                                  return CheckboxListTile(
                                    value: checked,
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(option.name),
                                    onChanged: (value) {
                                      setStateDialog(() {
                                        if (value == true) {
                                          selectedCompatibleFish.add(customId);
                                        } else {
                                          selectedCompatibleFish.remove(customId);
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saveFromDialog,
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
}

class _EntityOption {
  const _EntityOption({required this.id, required this.name});

  final String id;
  final String name;
}

class MasterSetsView extends StatefulWidget {
  const MasterSetsView({super.key, required this.userRole});

  final String userRole;

  @override
  State<MasterSetsView> createState() => _MasterSetsViewState();
}

class _MasterSetsViewState extends State<MasterSetsView> {
  bool get _canManageMasterSets =>
      widget.userRole.trim().toLowerCase() == 'admin';

  void _showAddFishDialog() {
    if (!_canManageMasterSets) return;
    showDialog(
      context: context,
      builder: (context) => const _AddFishDialog(),
    );
  }

  void _showAddPlantDialog() {
    if (!_canManageMasterSets) return;
    showDialog(
      context: context,
      builder: (context) => const _AddPlantDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'Aquaculture'),
                Tab(text: 'Plants'),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('aquaculture').snapshots(),
                builder: (context, aquacultureSnapshot) {
                  if (aquacultureSnapshot.hasError) {
                    return _ErrorText(
                      message:
                          'Error loading aquaculture: ${aquacultureSnapshot.error}',
                    );
                  }
                  if (aquacultureSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final aquacultureDocs =
                      aquacultureSnapshot.data?.docs ?? <QueryDocumentSnapshot>[];
                  final aquacultureIdToName = <String, String>{
                    for (final doc in aquacultureDocs)
                      _resolveAquacultureKey(
                        doc.id,
                        doc.data() as Map<String, dynamic>,
                      ): ((doc.data() as Map<String, dynamic>)['name'] ?? 'Unknown Fish')
                          .toString(),
                  };

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('plants').snapshots(),
                    builder: (context, plantsSnapshot) {
                      if (plantsSnapshot.hasError) {
                        return _ErrorText(
                          message: 'Error loading plants: ${plantsSnapshot.error}',
                        );
                      }
                      if (plantsSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final plantDocs =
                          plantsSnapshot.data?.docs ?? <QueryDocumentSnapshot>[];
                      final plantIdToName = <String, String>{
                        for (final doc in plantDocs)
                          _resolvePlantKey(
                            doc.id,
                            doc.data() as Map<String, dynamic>,
                          ): ((doc.data() as Map<String, dynamic>)['name'] ??
                                  'Unknown Plant')
                              .toString(),
                      };

                      return TabBarView(
                        children: [
                          _AquacultureTab(
                            canManage: _canManageMasterSets,
                            onAddFish: _showAddFishDialog,
                            aquacultureDocs: aquacultureDocs,
                            plantIdToName: plantIdToName,
                          ),
                          _PlantsTab(
                            canManage: _canManageMasterSets,
                            onAddPlant: _showAddPlantDialog,
                            plantDocs: plantDocs,
                            aquacultureIdToName: aquacultureIdToName,
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AquacultureTab extends StatelessWidget {
  const _AquacultureTab({
    required this.canManage,
    required this.onAddFish,
    required this.aquacultureDocs,
    required this.plantIdToName,
  });

  final bool canManage;
  final VoidCallback onAddFish;
  final List<QueryDocumentSnapshot> aquacultureDocs;
  final Map<String, String> plantIdToName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canManage)
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: onAddFish,
              icon: const Icon(Icons.add),
              label: const Text('Add Aquaculture'),
            ),
          ),
        const SizedBox(height: 12),
        Expanded(
          child: aquacultureDocs.isEmpty
              ? const _EmptyCard(message: 'No aquaculture records found.')
              : ListView.builder(
                  itemCount: aquacultureDocs.length,
                  itemBuilder: (context, index) {
                    final doc = aquacultureDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final compatiblePlantOverrides = _toPlantOverrides(
                      data['compatible_plants'],
                    );
                    final compatiblePlantNames = compatiblePlantOverrides.entries
                        .map((entry) {
                          final name = plantIdToName[entry.key] ?? 'Unknown Plant';
                          final idealDays = entry.value['ideal_days'] ?? 0;
                          final batches = entry.value['batches'] ?? 0;
                          return '$name ($idealDays days | $batches batches)';
                        })
                        .toList();

                    return _HorizontalAquacultureCard(
                      doc: doc,
                      name: (data['name'] ?? 'Unnamed Fish').toString(),
                      type: (data['type'] ?? 'N/A').toString(),
                      description: _shortDescription(data['description']),
                      compatiblePlants: compatiblePlantNames,
                      tempRange: _rangeText(data['min_temp'], data['max_temp']),
                      phRange: _rangeText(data['min_ph'], data['max_ph']),
                      doRange: _rangeText(data['min_do'], data['max_do']),
                      salinityRange:
                          _rangeText(data['min_salinity'], data['max_salinity']),
                      turbidityRange:
                          _rangeText(data['min_turbidity'], data['max_turbidity']),
                      ammoniaRange:
                          _rangeText(data['min_ammonia'], data['max_ammonia']),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _PlantsTab extends StatelessWidget {
  const _PlantsTab({
    required this.canManage,
    required this.onAddPlant,
    required this.plantDocs,
    required this.aquacultureIdToName,
  });

  final bool canManage;
  final VoidCallback onAddPlant;
  final List<QueryDocumentSnapshot> plantDocs;
  final Map<String, String> aquacultureIdToName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canManage)
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: onAddPlant,
              icon: const Icon(Icons.add),
              label: const Text('Add Plant'),
            ),
          ),
        const SizedBox(height: 12),
        Expanded(
          child: plantDocs.isEmpty
              ? const _EmptyCard(message: 'No plant records found.')
              : ListView.builder(
                  itemCount: plantDocs.length,
                  itemBuilder: (context, index) {
                    final doc = plantDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final compatibleFishIds = (data['compatible_fish'] as List?)
                            ?.map((e) => e.toString())
                            .where((e) => e.trim().isNotEmpty)
                            .toList() ??
                        <String>[];
                    final compatibleFishNames = compatibleFishIds
                        .map((id) => aquacultureIdToName[id] ?? 'Unknown Fish')
                        .toList();

                    return _HorizontalPlantCard(
                      doc: doc,
                      name: (data['name'] ?? 'Unnamed Plant').toString(),
                      type: (data['type'] ?? 'N/A').toString(),
                      description: _shortDescription(data['description']),
                      compatibleFish: compatibleFishNames,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _HorizontalAquacultureCard extends StatelessWidget {
  const _HorizontalAquacultureCard({
    required this.doc,
    required this.name,
    required this.type,
    required this.description,
    required this.compatiblePlants,
    required this.tempRange,
    required this.phRange,
    required this.doRange,
    required this.salinityRange,
    required this.turbidityRange,
    required this.ammoniaRange,
  });

  final DocumentSnapshot doc;
  final String name;
  final String type;
  final String description;
  final List<String> compatiblePlants;
  final String tempRange;
  final String phRange;
  final String doRange;
  final String salinityRange;
  final String turbidityRange;
  final String ammoniaRange;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 980;
    return Card(
      color: Colors.white,
      elevation: 1.2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE7E7E7)),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: isCompact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailsSection(
                    name: name,
                    type: type,
                    description: description,
                    compatibilityLabel: 'Compatible Plants',
                    compatibilityItems: compatiblePlants,
                  ),
                  const SizedBox(height: 12),
                  _ParameterSection(
                    tempRange: tempRange,
                    phRange: phRange,
                    doRange: doRange,
                    salinityRange: salinityRange,
                    turbidityRange: turbidityRange,
                    ammoniaRange: ammoniaRange,
                  ),
                  const SizedBox(height: 12),
                  _ActionSection(
                    viewLabel: 'View Aquaculture',
                    onView: () => _showViewAquacultureDialog(context, doc),
                    onEdit: () => _showEditAquacultureDialog(context, doc),
                  ),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: _DetailsSection(
                      name: name,
                      type: type,
                      description: description,
                      compatibilityLabel: 'Compatible Plants',
                      compatibilityItems: compatiblePlants,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 3,
                    child: _ParameterSection(
                      tempRange: tempRange,
                      phRange: phRange,
                      doRange: doRange,
                      salinityRange: salinityRange,
                      turbidityRange: turbidityRange,
                      ammoniaRange: ammoniaRange,
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 170,
                    child: _ActionSection(
                      viewLabel: 'View Aquaculture',
                      onView: () => _showViewAquacultureDialog(context, doc),
                      onEdit: () => _showEditAquacultureDialog(context, doc),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _HorizontalPlantCard extends StatelessWidget {
  const _HorizontalPlantCard({
    required this.doc,
    required this.name,
    required this.type,
    required this.description,
    required this.compatibleFish,
  });

  final DocumentSnapshot doc;
  final String name;
  final String type;
  final String description;
  final List<String> compatibleFish;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 820;
    return Card(
      color: Colors.white,
      elevation: 1.2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE7E7E7)),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: isCompact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailsSection(
                    name: name,
                    type: type,
                    description: description,
                    compatibilityLabel: 'Compatible Fish',
                    compatibilityItems: compatibleFish,
                  ),
                  const SizedBox(height: 12),
                  _ActionSection(
                    viewLabel: 'View Plant',
                    onView: () => _showViewPlantDialog(context, doc),
                    onEdit: () => _showEditPlantDialog(context, doc),
                  ),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _DetailsSection(
                      name: name,
                      type: type,
                      description: description,
                      compatibilityLabel: 'Compatible Fish',
                      compatibilityItems: compatibleFish,
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 170,
                    child: _ActionSection(
                      viewLabel: 'View Plant',
                      onView: () => _showViewPlantDialog(context, doc),
                      onEdit: () => _showEditPlantDialog(context, doc),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _DetailsSection extends StatelessWidget {
  const _DetailsSection({
    required this.name,
    required this.type,
    required this.description,
    required this.compatibilityLabel,
    required this.compatibilityItems,
  });

  final String name;
  final String type;
  final String description;
  final String compatibilityLabel;
  final List<String> compatibilityItems;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          type,
          style: const TextStyle(color: Colors.black54, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 10),
        Text(
          compatibilityLabel,
          style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: compatibilityItems.isEmpty
              ? const [Chip(label: Text('None'))]
              : compatibilityItems.map((item) => Chip(label: Text(item))).toList(),
        ),
      ],
    );
  }
}

class _ParameterSection extends StatelessWidget {
  const _ParameterSection({
    required this.tempRange,
    required this.phRange,
    required this.doRange,
    required this.salinityRange,
    required this.turbidityRange,
    required this.ammoniaRange,
  });

  final String tempRange;
  final String phRange;
  final String doRange;
  final String salinityRange;
  final String turbidityRange;
  final String ammoniaRange;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _ParameterItem(label: 'Temp', value: tempRange),
        _ParameterItem(label: 'pH', value: phRange),
        _ParameterItem(label: 'DO', value: doRange),
        _ParameterItem(label: 'Salinity', value: salinityRange),
        _ParameterItem(label: 'Turbidity', value: turbidityRange),
        _ParameterItem(label: 'Ammonia', value: ammoniaRange),
      ],
    );
  }
}

class _ParameterItem extends StatelessWidget {
  const _ParameterItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 140),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ActionSection extends StatelessWidget {
  const _ActionSection({
    required this.viewLabel,
    required this.onView,
    required this.onEdit,
  });

  final String viewLabel;
  final VoidCallback onView;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton(
          onPressed: onView,
          child: Text(viewLabel),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined, size: 16),
          label: const Text('Edit'),
        ),
      ],
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(message),
      ),
    );
  }
}

class _AddFishDialog extends StatefulWidget {
  const _AddFishDialog();

  @override
  State<_AddFishDialog> createState() => _AddFishDialogState();
}

class _AddFishDialogState extends State<_AddFishDialog> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _minTempCtrl = TextEditingController();
  final _maxTempCtrl = TextEditingController();
  final _minPhCtrl = TextEditingController();
  final _maxPhCtrl = TextEditingController();
  final _minDoCtrl = TextEditingController();
  final _maxDoCtrl = TextEditingController();
  final _minAmmoniaCtrl = TextEditingController();
  final _maxAmmoniaCtrl = TextEditingController();
  final _minSalinityCtrl = TextEditingController();
  final _maxSalinityCtrl = TextEditingController();
  final _minTurbidityCtrl = TextEditingController();
  final _maxTurbidityCtrl = TextEditingController();
  final _targetHarvestWeightCtrl = TextEditingController();
  final _growOutPeriodCtrl = TextEditingController();
  final List<String> _feedingTimes = [];

  List<_EntityOption> _plantOptions = <_EntityOption>[];
  final Map<String, String> _plantCustomIdToDocId = <String, String>{};
  final Map<String, Map<String, int>> _plantOverrides = {};
  String? _selectedType;
  bool _loadingOptions = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadPlantOptions();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    _minTempCtrl.dispose();
    _maxTempCtrl.dispose();
    _minPhCtrl.dispose();
    _maxPhCtrl.dispose();
    _minDoCtrl.dispose();
    _maxDoCtrl.dispose();
    _minAmmoniaCtrl.dispose();
    _maxAmmoniaCtrl.dispose();
    _minSalinityCtrl.dispose();
    _maxSalinityCtrl.dispose();
    _minTurbidityCtrl.dispose();
    _maxTurbidityCtrl.dispose();
    _targetHarvestWeightCtrl.dispose();
    _growOutPeriodCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPlantOptions() async {
    setState(() {
      _loadingOptions = true;
    });

    try {
      final snapshot = await FirebaseFirestore.instance.collection('plants').get();
      _plantCustomIdToDocId.clear();
      final options = snapshot.docs.map((doc) {
        final data = doc.data();
        final customId = _resolvePlantKey(doc.id, data);
        _plantCustomIdToDocId[customId] = doc.id;
        return _EntityOption(
          id: customId,
          name: (data['name'] ?? customId).toString(),
        );
      }).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      if (!mounted) return;
      setState(() {
        _plantOptions = options;
      });
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading plants: ${_firebaseErrorMessage(e)}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingOptions = false;
        });
      }
    }
  }

  String? _requiredText(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    return null;
  }

  String? _requiredDouble(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    if (double.tryParse(value.trim()) == null) return 'Enter a valid number';
    return null;
  }

  String? _optionalDouble(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (double.tryParse(value.trim()) == null) return 'Enter a valid number';
    return null;
  }

  String? _optionalInt(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (int.tryParse(value.trim()) == null) return 'Enter a valid whole number';
    return null;
  }

  double _parseDouble(TextEditingController ctrl) => double.parse(ctrl.text.trim());

  double? _parseOptionalDouble(TextEditingController ctrl) {
    final text = ctrl.text.trim();
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  int? _parseOptionalInt(TextEditingController ctrl) {
    final text = ctrl.text.trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  Widget _numberField(String label, TextEditingController ctrl) {
    return TextFormField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: _requiredDouble,
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
    });

    try {
      final fishRef = FirebaseFirestore.instance.collection('aquaculture').doc();
      final selectedPlantIds = _plantOverrides.keys.toSet();
      await fishRef.set({
        'name': _nameCtrl.text.trim(),
        'type': _selectedType ?? '',
        'description': _descriptionCtrl.text.trim(),
        'min_temp': _parseDouble(_minTempCtrl),
        'max_temp': _parseDouble(_maxTempCtrl),
        'min_ph': _parseDouble(_minPhCtrl),
        'max_ph': _parseDouble(_maxPhCtrl),
        'min_do': _parseDouble(_minDoCtrl),
        'max_do': _parseDouble(_maxDoCtrl),
        'min_ammonia': _parseDouble(_minAmmoniaCtrl),
        'max_ammonia': _parseDouble(_maxAmmoniaCtrl),
        'min_salinity': _parseDouble(_minSalinityCtrl),
        'max_salinity': _parseDouble(_maxSalinityCtrl),
        'min_turbidity': _parseDouble(_minTurbidityCtrl),
        'max_turbidity': _parseDouble(_maxTurbidityCtrl),
        'target_harvest_weight': _parseOptionalDouble(_targetHarvestWeightCtrl),
        'grow_out_period': _parseOptionalInt(_growOutPeriodCtrl),
        'feeding_schedule': _feedingTimes,
        'compatible_plants': _plantOverrides.entries.map((entry) {
          return <String, dynamic>{
            'plant_id': entry.key,
            'ideal_days':
                int.tryParse('${entry.value['ideal_days'] ?? ''}') ?? 0,
            'batches': int.tryParse('${entry.value['batches'] ?? ''}') ?? 0,
          };
        }).toList(),
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      for (final customId in selectedPlantIds) {
        final plantDocId = _plantCustomIdToDocId[customId] ?? customId;
        await FirebaseFirestore.instance.collection('plants').doc(plantDocId).update({
          'compatible_fish': FieldValue.arrayUnion([fishRef.id]),
          'updated_at': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;
      Navigator.pop(context);
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving fish: ${_firebaseErrorMessage(e)}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedPlantIds = _plantOverrides.keys.toSet();

    return AlertDialog(
      title: const Text('Add Aquaculture'),
      content: SizedBox(
        width: 760,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Species Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: _requiredText,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Aquaculture Type',
                    border: OutlineInputBorder(),
                  ),
                  items: _aquacultureTypeOptions
                      .map(
                        (type) => DropdownMenuItem<String>(
                          value: type,
                          child: Text(type),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _selectedType = value),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Detailed Description',
                    border: OutlineInputBorder(),
                  ),
                  validator: _requiredText,
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _numberField('Minimum Temperature (°C)', _minTempCtrl),
                    _numberField('Maximum Temperature (°C)', _maxTempCtrl),
                    _numberField('Minimum pH Level', _minPhCtrl),
                    _numberField('Maximum pH Level', _maxPhCtrl),
                    _numberField('Minimum Dissolved Oxygen (mg/L)', _minDoCtrl),
                    _numberField('Maximum Dissolved Oxygen (mg/L)', _maxDoCtrl),
                    _numberField('Minimum Ammonia (ppm)', _minAmmoniaCtrl),
                    _numberField('Maximum Ammonia (ppm)', _maxAmmoniaCtrl),
                    _numberField('Minimum Salinity (ppt)', _minSalinityCtrl),
                    _numberField('Maximum Salinity (ppt)', _maxSalinityCtrl),
                    _numberField('Minimum Turbidity (NTU)', _minTurbidityCtrl),
                    _numberField('Maximum Turbidity (NTU)', _maxTurbidityCtrl),
                  ],
                ),
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Growth Parameters',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    TextFormField(
                      controller: _targetHarvestWeightCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Target Harvest Weight in grams',
                        border: OutlineInputBorder(),
                      ),
                      validator: _optionalDouble,
                    ),
                    TextFormField(
                      controller: _growOutPeriodCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Grow Out Period in days',
                        border: OutlineInputBorder(),
                      ),
                      validator: _optionalInt,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Feeding Schedule',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 8),
                if (_feedingTimes.isEmpty)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('No feeding times added.'),
                  )
                else
                  Column(
                    children: _feedingTimes
                        .asMap()
                        .entries
                        .map(
                          (entry) => Row(
                            children: [
                              Expanded(child: Text(entry.value)),
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    _feedingTimes.removeAt(entry.key);
                                  });
                                },
                                icon: const Icon(Icons.delete_outline),
                                tooltip: 'Remove',
                              ),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final pickedTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (pickedTime == null) return;
                      final formatted = _formatFeedingTime(pickedTime);
                      setState(() {
                        _feedingTimes.add(formatted);
                      });
                    },
                    icon: const Icon(Icons.add_alarm),
                    label: const Text('Add Feeding Time'),
                  ),
                ),
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Compatible Plants',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 8),
                if (_loadingOptions)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: CircularProgressIndicator(),
                  )
                else
                  Container(
                    constraints: const BoxConstraints(maxHeight: 260),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: _plantOptions.isEmpty
                        ? const Align(
                            alignment: Alignment.centerLeft,
                            child: Text('No plants available.'),
                          )
                        : ListView(
                            shrinkWrap: true,
                            children: _plantOptions.map((option) {
                              final customId = option.id;
                              final checked = selectedPlantIds.contains(customId);
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CheckboxListTile(
                                    value: checked,
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(option.name),
                                    onChanged: (value) {
                                      setState(() {
                                        if (value == true) {
                                          _plantOverrides.putIfAbsent(
                                            customId,
                                            () => <String, int>{
                                              'ideal_days': 0,
                                              'batches': 0,
                                            },
                                          );
                                        } else {
                                          _plantOverrides.remove(customId);
                                        }
                                      });
                                    },
                                  ),
                                  if (checked)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        left: 12,
                                        right: 12,
                                        bottom: 8,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: TextFormField(
                                              initialValue:
                                                  '${_plantOverrides[customId]?['ideal_days'] ?? 0}',
                                              keyboardType: TextInputType.number,
                                              decoration: const InputDecoration(
                                                labelText:
                                                    'Ideal Days to Harvest (for this fish)',
                                                border: OutlineInputBorder(),
                                                isDense: true,
                                              ),
                                              onChanged: (value) {
                                                _plantOverrides.putIfAbsent(
                                                  customId,
                                                  () => <String, int>{
                                                    'ideal_days': 0,
                                                    'batches': 0,
                                                  },
                                                );
                                                _plantOverrides[customId]!['ideal_days'] =
                                                    int.tryParse(value.trim()) ?? 0;
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: TextFormField(
                                              initialValue:
                                                  '${_plantOverrides[customId]?['batches'] ?? 0}',
                                              keyboardType: TextInputType.number,
                                              decoration: const InputDecoration(
                                                labelText: 'Number of Batches',
                                                border: OutlineInputBorder(),
                                                isDense: true,
                                              ),
                                              onChanged: (value) {
                                                _plantOverrides.putIfAbsent(
                                                  customId,
                                                  () => <String, int>{
                                                    'ideal_days': 0,
                                                    'batches': 0,
                                                  },
                                                );
                                                _plantOverrides[customId]!['batches'] =
                                                    int.tryParse(value.trim()) ?? 0;
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              );
                            }).toList(),
                          ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving...' : 'Create'),
        ),
      ],
    );
  }
}

class _AddPlantDialog extends StatefulWidget {
  const _AddPlantDialog();

  @override
  State<_AddPlantDialog> createState() => _AddPlantDialogState();
}

class _AddPlantDialogState extends State<_AddPlantDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _idealDaysToHarvestCtrl = TextEditingController();
  final _numberOfBatchesCtrl = TextEditingController();

  List<_EntityOption> _fishOptions = <_EntityOption>[];
  final Set<String> _selectedFishIds = <String>{};
  String? _selectedType = _plantTypeOptions.first;
  bool _loadingOptions = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadFishOptions();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    _idealDaysToHarvestCtrl.dispose();
    _numberOfBatchesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFishOptions() async {
    setState(() {
      _loadingOptions = true;
    });

    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('aquaculture').get();
      final options = snapshot.docs.map((doc) {
        final data = doc.data();
        return _EntityOption(
          id: doc.id,
          name: (data['name'] ?? doc.id).toString(),
        );
      }).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      if (!mounted) return;
      setState(() {
        _fishOptions = options;
      });
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading aquaculture: ${_firebaseErrorMessage(e)}'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingOptions = false;
        });
      }
    }
  }

  String? _requiredText(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    return null;
  }

  String? _optionalInt(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (int.tryParse(value.trim()) == null) return 'Enter a valid whole number';
    return null;
  }

  int? _parseOptionalInt(TextEditingController ctrl) {
    final text = ctrl.text.trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  Future<void> _selectFish() async {
    final current = Set<String>.from(_selectedFishIds);
    final picked = await showDialog<Set<String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Select Compatible Fish'),
              content: SizedBox(
                width: 420,
                child: _fishOptions.isEmpty
                    ? const Text('No aquaculture records available.')
                    : ListView(
                        shrinkWrap: true,
                        children: _fishOptions.map((option) {
                          final checked = current.contains(option.id);
                          return CheckboxListTile(
                            value: checked,
                            title: Text(option.name),
                            onChanged: (value) {
                              setStateDialog(() {
                                if (value == true) {
                                  current.add(option.id);
                                } else {
                                  current.remove(option.id);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, current),
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );

    if (picked == null) return;
    setState(() {
      _selectedFishIds
        ..clear()
        ..addAll(picked);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
    });

    try {
      final firestore = FirebaseFirestore.instance;
      final plantRef = firestore.collection('plants').doc();
      final batch = firestore.batch();

      batch.set(plantRef, {
        'name': _nameCtrl.text.trim(),
        'type': _selectedType ?? '',
        'description': _descriptionCtrl.text.trim(),
        'ideal_days_to_harvest': _parseOptionalInt(_idealDaysToHarvestCtrl),
        'number_of_batches': _parseOptionalInt(_numberOfBatchesCtrl),
        'compatible_fish': _selectedFishIds.toList(),
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      final defaultIdealDays = _parseOptionalInt(_idealDaysToHarvestCtrl) ?? 0;
      final defaultBatches = _parseOptionalInt(_numberOfBatchesCtrl) ?? 0;

      for (final fishId in _selectedFishIds) {
        final fishRef = firestore.collection('aquaculture').doc(fishId);
        await firestore.runTransaction((tx) async {
          final fishSnap = await tx.get(fishRef);
          final fishData = fishSnap.data() ?? <String, dynamic>{};
          final overrides = _toPlantOverrides(fishData['compatible_plants']);
          overrides[plantRef.id] = <String, int>{
            'ideal_days': defaultIdealDays,
            'batches': defaultBatches,
          };
          tx.update(fishRef, {
            'compatible_plants': overrides.entries
                .map(
                  (entry) => <String, dynamic>{
                    'plant_id': entry.key,
                    'ideal_days': entry.value['ideal_days'] ?? 0,
                    'batches': entry.value['batches'] ?? 0,
                  },
                )
                .toList(),
            'updated_at': FieldValue.serverTimestamp(),
          });
        });
      }

      if (!mounted) return;
      Navigator.pop(context);
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving plant: ${_firebaseErrorMessage(e)}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedFishNames = _fishOptions
        .where((option) => _selectedFishIds.contains(option.id))
        .map((option) => option.name)
        .toList();

    return AlertDialog(
      title: const Text('Add Plant'),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Plant Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: _requiredText,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Plant Type',
                    border: OutlineInputBorder(),
                  ),
                  items: _plantTypeOptions
                      .map(
                        (type) => DropdownMenuItem<String>(
                          value: type,
                          child: Text(type),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _selectedType = value),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  validator: _requiredText,
                ),
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Growth Parameters',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _idealDaysToHarvestCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Ideal Days to Harvest',
                    border: OutlineInputBorder(),
                  ),
                  validator: _optionalInt,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _numberOfBatchesCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Number of Batches',
                    border: OutlineInputBorder(),
                  ),
                  validator: _optionalInt,
                ),
                const SizedBox(height: 12),
                if (_loadingOptions)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: CircularProgressIndicator(),
                  )
                else
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _selectFish,
                      icon: const Icon(Icons.arrow_drop_down),
                      label: Text(
                        selectedFishNames.isEmpty
                            ? 'Select compatible fish'
                            : '${selectedFishNames.length} selected',
                      ),
                    ),
                  ),
                if (selectedFishNames.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: selectedFishNames
                          .map((name) => Chip(label: Text(name)))
                          .toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving...' : 'Create'),
        ),
      ],
    );
  }
}
