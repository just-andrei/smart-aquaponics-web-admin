import 'compatibility_models.dart';
import 'fish_profiles.dart';
import 'plant_profiles.dart';

class CompatibilityService {
  const CompatibilityService();

  CompatibilityResult evaluate({
    required String fishId,
    required String plantId,
    required SystemReadings readings,
    FeedingStockingResult? feedingStocking,
  }) {
    final fish = fishProfiles[fishId];
    final plant = plantProfiles[plantId];
    if (fish == null || plant == null) {
      return const CompatibilityResult(
        score: 0,
        status: 'Bad',
        issues: ['Selected fish or plant profile is unavailable.'],
        recommendations: ['Review the configured species list.'],
        summary: 'The compatibility assistant needs valid species profiles.',
        metadata: <String, Object?>{},
      );
    }

    var score = 100;
    final issues = <String>[];
    final recommendations = <String>[];

    void addIssue({
      required String issue,
      required String recommendation,
      required int penalty,
    }) {
      issues.add(issue);
      if (!recommendations.contains(recommendation)) {
        recommendations.add(recommendation);
      }
      score -= penalty;
    }

    final ph = readings.ph;
    if (ph == null) {
      addIssue(
        issue: 'Current pH is unavailable.',
        recommendation:
            'Capture a recent pH reading before trusting this match.',
        penalty: 8,
      );
    } else {
      if (!fish.phRange.contains(ph)) {
        final direction = ph < fish.phRange.min ? 'low' : 'high';
        addIssue(
          issue: 'pH is too $direction for ${fish.name}.',
          recommendation: ph < fish.phRange.min
              ? 'Raise pH gradually toward ${fish.phRange.label} for ${fish.name}.'
              : 'Lower pH slightly toward ${fish.phRange.label} for ${fish.name}.',
          penalty: 18,
        );
      }
      if (!plant.phRange.contains(ph)) {
        final direction = ph < plant.phRange.min ? 'low' : 'high';
        addIssue(
          issue: 'pH is too $direction for ${plant.name}.',
          recommendation: ph < plant.phRange.min
              ? 'Raise pH gradually so ${plant.name} stays near ${plant.phRange.label}.'
              : 'Lower pH slightly so ${plant.name} stays near ${plant.phRange.label}.',
          penalty: 15,
        );
      }
    }

    final temperature = readings.waterTemperature;
    if (temperature == null) {
      addIssue(
        issue: 'Water temperature is unavailable.',
        recommendation:
            'Capture a recent water temperature reading before planting.',
        penalty: 8,
      );
    } else {
      if (!fish.temperatureRange.contains(temperature)) {
        final direction =
            temperature < fish.temperatureRange.min ? 'low' : 'high';
        addIssue(
          issue: 'Water temperature is too $direction for ${fish.name}.',
          recommendation: temperature < fish.temperatureRange.min
              ? 'Warm the system closer to ${fish.temperatureRange.label} C for ${fish.name}.'
              : 'Cool the system closer to ${fish.temperatureRange.label} C for ${fish.name}.',
          penalty: 18,
        );
      }
      if (!plant.temperatureRange.contains(temperature)) {
        final direction =
            temperature < plant.temperatureRange.min ? 'low' : 'high';
        addIssue(
          issue: 'Water temperature is too $direction for ${plant.name}.',
          recommendation: _plantTemperatureRecommendation(
            plant: plant,
            direction: direction,
          ),
          penalty: 16,
        );
      }
    }

    final dissolvedOxygen = readings.dissolvedOxygen;
    if (fish.minDissolvedOxygen != null) {
      if (dissolvedOxygen == null) {
        addIssue(
          issue: 'Dissolved oxygen is unavailable for ${fish.name}.',
          recommendation:
              'Add or verify dissolved oxygen monitoring for fish safety.',
          penalty: 6,
        );
      } else if (dissolvedOxygen < fish.minDissolvedOxygen!) {
        addIssue(
          issue:
              'Dissolved oxygen is low for ${fish.name} at ${dissolvedOxygen.toStringAsFixed(1)} mg/L.',
          recommendation:
              'Increase aeration and circulation to stay above ${fish.minDissolvedOxygen!.toStringAsFixed(1)} mg/L.',
          penalty: 14,
        );
      }
    }

    final ammonia = readings.ammonia;
    if (fish.maxAmmonia != null) {
      if (ammonia == null) {
        addIssue(
          issue: 'Ammonia is unavailable for ${fish.name}.',
          recommendation:
              'Check ammonia regularly before increasing fish or plant load.',
          penalty: 6,
        );
      } else if (ammonia > fish.maxAmmonia!) {
        addIssue(
          issue:
              'Ammonia is elevated for ${fish.name} at ${ammonia.toStringAsFixed(2)} mg/L.',
          recommendation:
              'Reduce feeding, inspect biofiltration, and improve water exchange until ammonia drops.',
          penalty: 16,
        );
      }
    }

    if (temperature != null &&
        temperature > 28 &&
        plant.heatTolerance == 'low' &&
        !recommendations.any((item) => item.contains('heat-tolerant'))) {
      recommendations.add(
        'Switch to heat-tolerant plants like kangkong when water stays above 28 C.',
      );
    }

    if (temperature != null &&
        temperature > 28 &&
        plant.id == 'lettuce' &&
        !issues.any((item) => item.contains('lettuce'))) {
      issues.add(
        'Warm-water conditions can stress lettuce even if fish remain stable.',
      );
      score -= 10;
    }

    if (temperature != null &&
        temperature >= 24 &&
        temperature <= 32 &&
        plant.id != 'kangkong' &&
        !recommendations.any((item) => item.contains('kangkong'))) {
      recommendations.add(
        'If you want a safer tropical match, consider heat-tolerant plants like kangkong.',
      );
    }

    if (!recommendations.any(
      (item) => item.contains('Avoid fruiting plants'),
    )) {
      recommendations.add(
        'Avoid fruiting plants under unstable water conditions until pH and temperature stay in range.',
      );
    }

    if (feedingStocking != null) {
      if (feedingStocking.stockingStatus == 'Overstocked') {
        issues.add(
          'Stocking load is above the recommended range for the current tank volume.',
        );
        recommendations.add(
          'Reduce fish count or expand the water volume before pushing feed higher.',
        );
        score -= 12;
      }
      if (feedingStocking.warnings.any(
        (item) => item.contains('Ammonia') || item.contains('oxygen'),
      )) {
        recommendations.add(
          'Feed in smaller sessions while monitoring ammonia and dissolved oxygen closely.',
        );
      }
    }

    score = score.clamp(0, 100);
    final status = score >= 80
        ? 'Good'
        : score >= 55
        ? 'Warning'
        : 'Bad';

    final summary = _buildSummary(
      status: status,
      fish: fish,
      plant: plant,
      issues: issues,
      isMock: readings.isMock,
    );

    return CompatibilityResult(
      score: score,
      status: status,
      issues: issues,
      recommendations: recommendations,
      summary: summary,
      feedingGramsPerDay: feedingStocking?.totalFeedGramsPerDay,
      stockingAdvice: feedingStocking?.stockingAdvice,
      metadata: <String, Object?>{
        'fishId': fish.id,
        'fishName': fish.name,
        'plantId': plant.id,
        'plantName': plant.name,
        'dataSource': readings.isMock ? 'mock' : 'firebase',
        'systemName': readings.systemName,
        'ph': readings.ph,
        'waterTemperature': readings.waterTemperature,
        'dissolvedOxygen': readings.dissolvedOxygen,
        'ammonia': readings.ammonia,
        'lastUpdated': readings.lastUpdated?.toIso8601String(),
        'feedingGramsPerDay': feedingStocking?.totalFeedGramsPerDay,
        'stockingAdvice': feedingStocking?.stockingAdvice,
      },
    );
  }

  String _plantTemperatureRecommendation({
    required PlantProfile plant,
    required String direction,
  }) {
    if (direction == 'high' && plant.heatTolerance == 'low') {
      return 'Switch to heat-tolerant plants like kangkong or cool the water before growing ${plant.name}.';
    }
    if (direction == 'high') {
      return 'Cool the water slightly so ${plant.name} stays near ${plant.temperatureRange.label} C.';
    }
    return 'Warm the water slightly so ${plant.name} stays near ${plant.temperatureRange.label} C.';
  }

  String _buildSummary({
    required String status,
    required FishProfile fish,
    required PlantProfile plant,
    required List<String> issues,
    required bool isMock,
  }) {
    final sourceText = isMock
        ? 'using fallback mock readings'
        : 'using current system readings';
    if (issues.isEmpty) {
      return '${fish.name} and ${plant.name} look compatible $sourceText.';
    }
    return '${fish.name} and ${plant.name} are rated $status $sourceText, '
        'with ${issues.length} item${issues.length == 1 ? '' : 's'} to address.';
  }
}
