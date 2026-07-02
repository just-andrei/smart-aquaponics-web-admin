class NumericRange {
  const NumericRange({required this.min, required this.max});

  final double min;
  final double max;

  bool contains(double value) => value >= min && value <= max;

  double clampDistance(double value) {
    if (contains(value)) return 0;
    if (value < min) return min - value;
    return value - max;
  }

  String get label => '${min.toStringAsFixed(1)}-${max.toStringAsFixed(1)}';
}

class GrowthStageProfile {
  const GrowthStageProfile({
    required this.id,
    required this.name,
    required this.minWeightGrams,
    this.maxWeightGrams,
    this.lengthGuide,
    required this.feedingPercentage,
  });

  final String id;
  final String name;
  final double minWeightGrams;
  final double? maxWeightGrams;
  final String? lengthGuide;
  final double feedingPercentage;

  bool containsWeight(double weightGrams) {
    final meetsMin = weightGrams >= minWeightGrams;
    final meetsMax = maxWeightGrams == null || weightGrams < maxWeightGrams!;
    return meetsMin && meetsMax;
  }

  double get representativeWeightGrams {
    if (maxWeightGrams == null) {
      return minWeightGrams + 50;
    }
    return (minWeightGrams + maxWeightGrams!) / 2;
  }

  String get weightLabel {
    if (maxWeightGrams == null) {
      return '${minWeightGrams.toStringAsFixed(0)}g+';
    }
    return '${minWeightGrams.toStringAsFixed(0)}-${maxWeightGrams!.toStringAsFixed(0)}g';
  }
}

class FishProfile {
  const FishProfile({
    required this.id,
    required this.name,
    required this.phRange,
    required this.temperatureRange,
    this.minDissolvedOxygen,
    this.maxAmmonia,
    required this.notes,
    required this.growthStages,
    required this.defaultFeedingsPerDay,
    required this.stockingKgPer1000LRange,
  });

  final String id;
  final String name;
  final NumericRange phRange;
  final NumericRange temperatureRange;
  final double? minDissolvedOxygen;
  final double? maxAmmonia;
  final String notes;
  final List<GrowthStageProfile> growthStages;
  final int defaultFeedingsPerDay;
  final NumericRange stockingKgPer1000LRange;
}

class PlantProfile {
  const PlantProfile({
    required this.id,
    required this.name,
    required this.phRange,
    required this.temperatureRange,
    required this.heatTolerance,
    required this.notes,
  });

  final String id;
  final String name;
  final NumericRange phRange;
  final NumericRange temperatureRange;
  final String heatTolerance;
  final String notes;
}

class SystemReadings {
  const SystemReadings({
    this.systemName,
    this.ph,
    this.waterTemperature,
    this.dissolvedOxygen,
    this.ammonia,
    this.lastUpdated,
    this.isMock = false,
  });

  final String? systemName;
  final double? ph;
  final double? waterTemperature;
  final double? dissolvedOxygen;
  final double? ammonia;
  final DateTime? lastUpdated;
  final bool isMock;
}

class FeedingStockingResult {
  const FeedingStockingResult({
    required this.growthStage,
    required this.averageWeightGrams,
    required this.fishCount,
    required this.tankVolumeLiters,
    required this.feedingsPerDay,
    required this.totalFeedGramsPerDay,
    required this.feedGramsPerSession,
    required this.recommendedFishCountMin,
    required this.recommendedFishCountMax,
    required this.stockingStatus,
    required this.warnings,
    required this.stockingAdvice,
    required this.metadata,
  });

  final GrowthStageProfile growthStage;
  final double averageWeightGrams;
  final int fishCount;
  final double tankVolumeLiters;
  final int feedingsPerDay;
  final double totalFeedGramsPerDay;
  final double feedGramsPerSession;
  final int recommendedFishCountMin;
  final int recommendedFishCountMax;
  final String stockingStatus;
  final List<String> warnings;
  final List<String> stockingAdvice;
  final Map<String, Object?> metadata;
}

class CompatibilityResult {
  const CompatibilityResult({
    required this.score,
    required this.status,
    required this.issues,
    required this.recommendations,
    required this.summary,
    required this.metadata,
    this.feedingGramsPerDay,
    this.stockingAdvice,
  });

  final int score;
  final String status;
  final List<String> issues;
  final List<String> recommendations;
  final String summary;
  final Map<String, Object?> metadata;
  final double? feedingGramsPerDay;
  final List<String>? stockingAdvice;
}
