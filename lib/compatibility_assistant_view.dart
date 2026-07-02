import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'aquaponics_colors.dart';
import 'compatibility_models.dart';
import 'compatibility_service.dart';
import 'feeding_service.dart';
import 'fish_profiles.dart';
import 'plant_profiles.dart';

class CompatibilityAssistantView extends StatefulWidget {
  const CompatibilityAssistantView({super.key});

  @override
  State<CompatibilityAssistantView> createState() =>
      _CompatibilityAssistantViewState();
}

class _CompatibilityAssistantViewState
    extends State<CompatibilityAssistantView> {
  final CompatibilityService _compatibilityService =
      const CompatibilityService();
  final FeedingService _feedingService = const FeedingService();
  final TextEditingController _fishCountController = TextEditingController(
    text: '80',
  );
  final TextEditingController _averageWeightController = TextEditingController(
    text: '35',
  );
  final TextEditingController _tankSizeController = TextEditingController(
    text: '1000',
  );

  String _selectedFishId = fishProfiles.keys.first;
  String _selectedPlantId = plantProfiles.keys.first;
  String _selectedGrowthStageId = fishProfiles.values.first.growthStages[1].id;
  int _feedingsPerDay = fishProfiles.values.first.defaultFeedingsPerDay;

  @override
  void dispose() {
    _fishCountController.dispose();
    _averageWeightController.dispose();
    _tankSizeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collectionGroup('systems').snapshots(),
      builder: (context, snapshot) {
        final readings = _resolveSystemReadings(snapshot.data?.docs ?? const []);
        final feedingResult = _buildFeedingResult(readings);
        final compatibilityResult = _compatibilityService.evaluate(
          fishId: _selectedFishId,
          plantId: _selectedPlantId,
          readings: readings,
          feedingStocking: feedingResult,
        );

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading system readings: ${snapshot.error}',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final isNarrow = MediaQuery.of(context).size.width < 1100;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            isNarrow ? 12 : 16,
            8,
            isNarrow ? 12 : 16,
            16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildIntroCard(context, readings, compatibilityResult),
              const SizedBox(height: 16),
              if (isNarrow) ...[
                _buildSystemValuesCard(context, readings),
                const SizedBox(height: 16),
                _buildSelectionCard(context),
                const SizedBox(height: 16),
                _buildStockingFeedingCard(
                  context,
                  feedingResult,
                  compatibilityResult,
                ),
                const SizedBox(height: 16),
                _buildResultCard(context, compatibilityResult),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Column(
                        children: [
                          _buildSystemValuesCard(context, readings),
                          const SizedBox(height: 16),
                          _buildResultCard(context, compatibilityResult),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: [
                          _buildSelectionCard(context),
                          const SizedBox(height: 16),
                          _buildStockingFeedingCard(
                            context,
                            feedingResult,
                            compatibilityResult,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  FeedingStockingResult _buildFeedingResult(SystemReadings readings) {
    final fishCount = _parseInt(_fishCountController.text) ?? 80;
    final tankSize = _parseDouble(_tankSizeController.text) ?? 1000;
    final averageWeight = _parseDouble(_averageWeightController.text);

    final baseCompatibility = _compatibilityService.evaluate(
      fishId: _selectedFishId,
      plantId: _selectedPlantId,
      readings: readings,
    );

    return _feedingService.evaluate(
      fishId: _selectedFishId,
      fishCount: fishCount < 1 ? 1 : fishCount,
      tankVolumeLiters: tankSize <= 0 ? 1000 : tankSize,
      averageWeightGrams: averageWeight,
      selectedGrowthStageId: _selectedGrowthStageId,
      feedingsPerDay: _feedingsPerDay,
      compatibility: baseCompatibility,
      readings: readings,
    );
  }

  SystemReadings _resolveSystemReadings(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    double? bestScore;
    SystemReadings? best;
    for (final doc in docs) {
      final data = doc.data();
      final reading = SystemReadings(
        systemName: _readName(data, doc.id),
        ph: _readDouble(data, ['ph', 'pH', 'avg_ph', 'average_ph']),
        waterTemperature: _readDouble(data, [
          'temp',
          'temperature',
          'water_temp',
          'waterTemperature',
          'avg_temp',
        ]),
        dissolvedOxygen: _readDouble(data, [
          'do',
          'dissolved_oxygen',
          'avg_do',
        ]),
        ammonia: _readDouble(data, ['ammonia', 'avg_ammonia']),
        lastUpdated: _readDateTime(data, [
          'updated_at',
          'last_updated',
          'timestamp',
          'created_at',
        ]),
      );
      final score = [
        reading.ph,
        reading.waterTemperature,
        reading.dissolvedOxygen,
        reading.ammonia,
      ].whereType<double>().length.toDouble();
      if (score == 0) continue;
      if (best == null || score > (bestScore ?? -1)) {
        best = reading;
        bestScore = score;
      }
    }

    return best ??
        const SystemReadings(
          systemName: 'Mock tropical system',
          ph: 7.4,
          waterTemperature: 29.0,
          dissolvedOxygen: 4.8,
          ammonia: 0.7,
          isMock: true,
        );
  }

  String _readName(Map<String, dynamic> data, String fallback) {
    final candidates = [
      data['system_name'],
      data['name'],
      data['system_label'],
      data['label'],
    ];
    for (final value in candidates) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  double? _readDouble(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is num) return value.toDouble();
      final parsed = double.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return null;
  }

  DateTime? _readDateTime(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  Widget _buildIntroCard(
    BuildContext context,
    SystemReadings readings,
    CompatibilityResult result,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: isDark
            ? const LinearGradient(
                colors: [Color(0xFF0D2430), Color(0xFF1B4C46)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFF1E5D5A), Color(0xFF3D7A57)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 560,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aquaponics Compatibility Assistant',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Evaluate fish-plant fit, then extend the same decision with feeding and stocking guidance for day-to-day operations.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.88),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  result.summary,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.82),
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _heroPill(
                label: 'Source',
                value: readings.isMock ? 'Mock data' : 'Firebase',
              ),
              _heroPill(
                label: 'System',
                value: readings.systemName ?? 'Unknown',
              ),
              _heroPill(
                label: 'Score',
                value: '${result.score}/100',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroPill({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.white),
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

  Widget _buildSystemValuesCard(BuildContext context, SystemReadings readings) {
    final lastUpdated = readings.lastUpdated == null
        ? (readings.isMock
              ? 'Using fallback data until live sensor values are available.'
              : 'Live system selected from Firebase.')
        : 'Last updated ${DateFormat('MMM d, y - h:mm a').format(readings.lastUpdated!.toLocal())}';
    return _surfaceCard(
      context,
      title: 'Current system values',
      subtitle: lastUpdated,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _readingChip(context, 'pH', _formatReading(readings.ph)),
          _readingChip(
            context,
            'Water Temp',
            readings.waterTemperature == null
                ? 'No data'
                : '${readings.waterTemperature!.toStringAsFixed(1)} C',
          ),
          _readingChip(
            context,
            'Dissolved Oxygen',
            readings.dissolvedOxygen == null
                ? 'No data'
                : '${readings.dissolvedOxygen!.toStringAsFixed(1)} mg/L',
          ),
          _readingChip(
            context,
            'Ammonia',
            readings.ammonia == null
                ? 'No data'
                : '${readings.ammonia!.toStringAsFixed(2)} mg/L',
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionCard(BuildContext context) {
    final fish = fishProfiles[_selectedFishId]!;
    return _surfaceCard(
      context,
      title: 'Species selection',
      subtitle:
          'Choose a fish and plant pair to evaluate against current water conditions.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fish',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selectedFishId,
            decoration: _dropdownDecoration(context),
            items: fishProfiles.values
                .map(
                  (profile) => DropdownMenuItem<String>(
                    value: profile.id,
                    child: Text(profile.name),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              final selectedFish = fishProfiles[value]!;
              setState(() {
                _selectedFishId = value;
                _selectedGrowthStageId = selectedFish.growthStages[1].id;
                _feedingsPerDay = selectedFish.defaultFeedingsPerDay;
              });
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Plant',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selectedPlantId,
            decoration: _dropdownDecoration(context),
            items: plantProfiles.values
                .map(
                  (profile) => DropdownMenuItem<String>(
                    value: profile.id,
                    child: Text(profile.name),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _selectedPlantId = value);
            },
          ),
          const SizedBox(height: 20),
          _profileFact(
            context,
            icon: Icons.set_meal_rounded,
            label: fish.name,
            value: fish.notes,
          ),
          const SizedBox(height: 12),
          _profileFact(
            context,
            icon: Icons.eco_rounded,
            label: plantProfiles[_selectedPlantId]!.name,
            value: plantProfiles[_selectedPlantId]!.notes,
          ),
        ],
      ),
    );
  }

  Widget _buildStockingFeedingCard(
    BuildContext context,
    FeedingStockingResult result,
    CompatibilityResult compatibility,
  ) {
    final fish = fishProfiles[_selectedFishId]!;
    final statusColor = _stockingStatusColor(result.stockingStatus);
    return _surfaceCard(
      context,
      title: 'Stocking & Feeding Assistant',
      subtitle:
          'Estimate growth stage, daily feed, and safe stocking for the selected fish and tank volume.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoBanner(
            context,
            icon: Icons.info_outline_rounded,
            color: AquaponicsColors.adminInfo,
            title: 'How this section works',
            text:
                'Growth stage guides the feeding percentage. Feeding is calculated as a percent of total fish body weight per day, and stocking range is estimated from fish biomass per 1000 liters of water.',
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth >= 520;
              final fields = [
                _numericField(
                  controller: _fishCountController,
                  label: 'Number of fish',
                  hint: '80',
                ),
                _numericField(
                  controller: _tankSizeController,
                  label: 'Tank size (L)',
                  hint: '1000',
                ),
                _numericField(
                  controller: _averageWeightController,
                  label: 'Average weight (g)',
                  hint: 'Optional',
                  helper:
                      'If left blank, the selected growth stage will supply a default weight.',
                ),
              ];
              if (!twoColumns) {
                return Column(
                  children: [
                    ...fields.map(
                      (field) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: field,
                      ),
                    ),
                    _growthStageSelector(context, fish),
                    const SizedBox(height: 12),
                    _feedingSessionsSelector(context),
                  ],
                );
              }
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(width: 220, child: fields[0]),
                  SizedBox(width: 220, child: fields[1]),
                  SizedBox(width: 220, child: fields[2]),
                  SizedBox(width: 220, child: _growthStageSelector(context, fish)),
                  SizedBox(width: 220, child: _feedingSessionsSelector(context)),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          _sectionLabel(
            context,
            title: 'Stage guide',
            help:
                'Small, Medium, and Large map to weight ranges and recommended feeding percentages.',
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: fish.growthStages
                .map((stage) => _stageGuideChip(context, stage))
                .toList(),
          ),
          const SizedBox(height: 18),
          _sectionLabel(
            context,
            title: 'Key outputs',
            help:
                'Feed per day is the main number to plan around. Feed per session simply splits that total across the selected daily feedings.',
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _readingChip(
                context,
                'Growth Stage',
                '${result.growthStage.name} (${result.growthStage.weightLabel})',
              ),
              _highlightChip(
                context,
                label: 'Feed / day',
                value: '${result.totalFeedGramsPerDay.toStringAsFixed(1)} g',
                subtitle:
                    '${result.fishCount} fish x ${result.averageWeightGrams.toStringAsFixed(1)} g x ${(result.growthStage.feedingPercentage * 100).toStringAsFixed(1)}%',
                accent: AquaponicsColors.mossGreen,
              ),
              _highlightChip(
                context,
                label: 'Feed / session',
                value: '${result.feedGramsPerSession.toStringAsFixed(1)} g',
                subtitle:
                    '${result.feedingsPerDay} feeding session${result.feedingsPerDay == 1 ? '' : 's'} per day',
                accent: AquaponicsColors.deepTeal,
              ),
              _highlightChip(
                context,
                label: 'Suggested stocking range',
                value:
                    '${result.recommendedFishCountMin}-${result.recommendedFishCountMax} fish',
                subtitle:
                    'Based on ${result.tankVolumeLiters.toStringAsFixed(0)} L and safe biomass guidance',
                accent: statusColor,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _infoBanner(
            context,
            icon: Icons.calculate_rounded,
            color: AquaponicsColors.mossGreen,
            title: 'Feeding calculation',
            text:
                'Daily feed uses this formula: number of fish x average weight x feeding percentage. Smaller fish need a higher percentage of body weight per day than larger fish.',
          ),
          const SizedBox(height: 12),
          _infoBanner(
            context,
            icon: Icons.water_drop_outlined,
            color: statusColor,
            title: 'Why a stocking range is suggested',
            text:
                'The range shows how many fish usually fit the current tank volume while staying inside the target biomass per 1000 liters. Going above the range increases pressure on oxygen, filtration, and waste control.',
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              result.stockingStatus,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _sectionLabel(
            context,
            title: 'Warnings',
            help:
                'Green means no immediate concern, yellow flags caution, and red indicates higher operational risk.',
          ),
          const SizedBox(height: 10),
          if (result.warnings.isEmpty)
            _messageRow(
              context,
              icon: Icons.check_circle_rounded,
              color: AquaponicsColors.statusSafe,
              text:
                  'No stocking or feeding warnings were triggered for the current inputs.',
            )
          else
            ...result.warnings.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _messageRow(
                  context,
                  icon: Icons.warning_amber_rounded,
                  color: AquaponicsColors.statusWarning,
                  text: item,
                ),
              ),
            ),
          const SizedBox(height: 16),
          _sectionLabel(
            context,
            title: 'Stocking Advice',
            help:
                'Use this as the practical interpretation of the stocking range and warning state.',
          ),
          const SizedBox(height: 10),
          ...result.stockingAdvice.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _messageRow(
                context,
                icon: Icons.waterfall_chart_rounded,
                color: AquaponicsColors.deepTeal,
                text: item,
              ),
            ),
          ),
          if (compatibility.status != 'Good') ...[
            const SizedBox(height: 16),
            _messageRow(
              context,
              icon: Icons.sync_alt_rounded,
              color: AquaponicsColors.mossGreen,
              text:
                  'Compatibility is ${compatibility.status}, so use feeding changes gradually and watch water quality after each adjustment.',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultCard(BuildContext context, CompatibilityResult result) {
    final statusColor = _statusColor(result.status);
    return _surfaceCard(
      context,
      title: 'Compatibility result',
      subtitle:
          'Rule-based output structured for future AI-assisted explanations.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor.withValues(alpha: 0.12),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.28),
                  ),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${result.score}',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                          ),
                    ),
                    Text(
                      'Score',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  result.status,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _sectionLabel(
            context,
            title: 'Issues',
            help:
                'These are the conditions currently reducing the compatibility score for the selected fish and plant pair.',
          ),
          const SizedBox(height: 10),
          if (result.issues.isEmpty)
            _messageRow(
              context,
              icon: Icons.check_circle_rounded,
              color: AquaponicsColors.statusSafe,
              text:
                  'No compatibility issues were detected for the selected pair.',
            )
          else
            ...result.issues.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _messageRow(
                  context,
                  icon: Icons.warning_amber_rounded,
                  color: AquaponicsColors.statusWarning,
                  text: item,
                ),
              ),
            ),
          const SizedBox(height: 16),
          _sectionLabel(
            context,
            title: 'Recommendations',
            help:
                'These suggestions explain what to adjust next to improve compatibility and operating stability.',
          ),
          const SizedBox(height: 10),
          ...result.recommendations.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _messageRow(
                context,
                icon: Icons.tips_and_updates_rounded,
                color: AquaponicsColors.mossGreen,
                text: item,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SelectableText(
              '{ compatibility_score: ${result.score}, compatibility_status: "${result.status}", issues: ${result.issues}, recommendations: ${result.recommendations}, feeding_grams_per_day: ${result.feedingGramsPerDay?.toStringAsFixed(1)}, stocking_advice: ${result.stockingAdvice} }',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(
    BuildContext context, {
    required String title,
    required String help,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Tooltip(
          message: help,
          child: Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _surfaceCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF101A26) : Colors.white,
        borderRadius: BorderRadius.circular(22),
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
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _readingChip(BuildContext context, String label, String value) {
    return Container(
      constraints: const BoxConstraints(minWidth: 160),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _highlightChip(
    BuildContext context, {
    required String label,
    required String value,
    required String subtitle,
    required Color accent,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 190),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: accent,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stageGuideChip(BuildContext context, GrowthStageProfile stage) {
    final helper = stage.lengthGuide == null ? '' : ' • ${stage.lengthGuide}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stage.name,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${stage.weightLabel}$helper',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Feeds at about ${(stage.feedingPercentage * 100).toStringAsFixed(1)}% of body weight/day',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoBanner(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    height: 1.45,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileFact(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AquaponicsColors.mossGreen.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AquaponicsColors.mossGreen, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _messageRow(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _numericField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? helper,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _growthStageSelector(BuildContext context, FishProfile fish) {
    return DropdownButtonFormField<String>(
      initialValue: _selectedGrowthStageId,
      decoration: _dropdownDecoration(context).copyWith(
        labelText: 'Growth stage',
      ),
      items: fish.growthStages
          .map(
            (stage) => DropdownMenuItem<String>(
              value: stage.id,
              child: Text(
                stage.lengthGuide == null
                    ? '${stage.name} (${stage.weightLabel})'
                    : '${stage.name} (${stage.weightLabel}, ${stage.lengthGuide})',
              ),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value == null) return;
        setState(() => _selectedGrowthStageId = value);
      },
    );
  }

  Widget _feedingSessionsSelector(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: _feedingsPerDay,
      decoration: _dropdownDecoration(context).copyWith(
        labelText: 'Feedings / day',
      ),
      items: const [1, 2, 3, 4]
          .map(
            (count) => DropdownMenuItem<int>(
              value: count,
              child: Text('$count session${count == 1 ? '' : 's'}'),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value == null) return;
        setState(() => _feedingsPerDay = value);
      },
    );
  }

  InputDecoration _dropdownDecoration(BuildContext context) {
    return InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Good':
        return AquaponicsColors.statusSafe;
      case 'Warning':
        return AquaponicsColors.statusWarning;
      default:
        return AquaponicsColors.statusDanger;
    }
  }

  Color _stockingStatusColor(String status) {
    switch (status) {
      case 'Balanced':
        return AquaponicsColors.statusSafe;
      case 'Understocked':
        return AquaponicsColors.adminInfo;
      default:
        return AquaponicsColors.statusDanger;
    }
  }

  String _formatReading(double? value) {
    if (value == null) return 'No data';
    return value.toStringAsFixed(1);
  }

  int? _parseInt(String value) => int.tryParse(value.trim());

  double? _parseDouble(String value) => double.tryParse(value.trim());
}
