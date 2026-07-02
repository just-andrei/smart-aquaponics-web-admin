import 'compatibility_models.dart';
import 'fish_profiles.dart';

class FeedingService {
  const FeedingService();

  FeedingStockingResult evaluate({
    required String fishId,
    required int fishCount,
    required double tankVolumeLiters,
    double? averageWeightGrams,
    String? selectedGrowthStageId,
    int? feedingsPerDay,
    CompatibilityResult? compatibility,
    SystemReadings? readings,
  }) {
    final fish = fishProfiles[fishId];
    if (fish == null) {
      throw ArgumentError('Unknown fish profile: $fishId');
    }

    final stage =
        _resolveGrowthStage(fish, averageWeightGrams, selectedGrowthStageId) ??
        fish.growthStages.first;
    final resolvedWeight =
        averageWeightGrams != null && averageWeightGrams > 0
        ? averageWeightGrams
        : stage.representativeWeightGrams;
    final sessions =
        (feedingsPerDay ?? fish.defaultFeedingsPerDay).clamp(1, 6) as int;
    final feedGramsPerDay =
        fishCount * resolvedWeight * stage.feedingPercentage;
    final feedPerSession = feedGramsPerDay / sessions;

    final minKgCapacity =
        tankVolumeLiters / 1000 * fish.stockingKgPer1000LRange.min;
    final maxKgCapacity =
        tankVolumeLiters / 1000 * fish.stockingKgPer1000LRange.max;
    final fishWeightKg = resolvedWeight / 1000;
    final recommendedMin = fishWeightKg == 0
        ? 0
        : (minKgCapacity / fishWeightKg).floor();
    final recommendedMax = fishWeightKg == 0
        ? 0
        : (maxKgCapacity / fishWeightKg).floor();
    final totalBiomassKg = fishCount * fishWeightKg;

    final warnings = <String>[];
    final advice = <String>[];
    String stockingStatus = 'Balanced';

    if (tankVolumeLiters < 250) {
      warnings.add(
        'Tank volume is small, so waste buildup and oxygen swings can happen faster.',
      );
    }

    if (fishCount > recommendedMax && recommendedMax > 0) {
      stockingStatus = 'Overstocked';
      warnings.add(
        'Current stocking is above the safe guideline for ${fish.name} in ${tankVolumeLiters.toStringAsFixed(0)} L.',
      );
      advice.add(
        'Reduce fish count or increase tank volume to stay near $recommendedMin-$recommendedMax fish.',
      );
    } else if (fishCount < recommendedMin && recommendedMin > 0) {
      stockingStatus = 'Understocked';
      advice.add(
        'Stocking is below the typical production range, which is safer but may reduce nutrient output for plants.',
      );
    } else {
      advice.add(
        'Current stocking sits within the typical ${fish.stockingKgPer1000LRange.min.toStringAsFixed(0)}-${fish.stockingKgPer1000LRange.max.toStringAsFixed(0)} kg per 1000 L guideline.',
      );
    }

    if (compatibility != null && compatibility.status == 'Bad') {
      warnings.add(
        'Compatibility conditions are poor, so avoid increasing feed until water conditions recover.',
      );
      advice.add(
        'Feed conservatively and recheck pH and temperature before scaling biomass.',
      );
    } else if (compatibility != null && compatibility.status == 'Warning') {
      advice.add(
        'Because the system is in Warning status, split feed into smaller sessions and monitor uneaten feed.',
      );
    }

    if (readings?.ammonia != null &&
        fish.maxAmmonia != null &&
        readings!.ammonia! > fish.maxAmmonia!) {
      warnings.add(
        'Ammonia is elevated, so overfeeding risk is higher than normal.',
      );
      advice.add(
        'Temporarily reduce feed volume and confirm filtration performance.',
      );
    }

    if (readings?.dissolvedOxygen != null &&
        fish.minDissolvedOxygen != null &&
        readings!.dissolvedOxygen! < fish.minDissolvedOxygen!) {
      warnings.add(
        'Low dissolved oxygen can reduce feeding efficiency and stress the stock.',
      );
      advice.add(
        'Improve aeration before pushing feed volume upward.',
      );
    }

    if (stage.id == 'small' && sessions < 3) {
      warnings.add(
        'Small fish usually perform better when feed is split across about 3 sessions daily.',
      );
    }

    return FeedingStockingResult(
      growthStage: stage,
      averageWeightGrams: resolvedWeight,
      fishCount: fishCount,
      tankVolumeLiters: tankVolumeLiters,
      feedingsPerDay: sessions,
      totalFeedGramsPerDay: feedGramsPerDay,
      feedGramsPerSession: feedPerSession,
      recommendedFishCountMin: recommendedMin,
      recommendedFishCountMax: recommendedMax,
      stockingStatus: stockingStatus,
      warnings: warnings,
      stockingAdvice: advice,
      metadata: <String, Object?>{
        'fishId': fish.id,
        'fishName': fish.name,
        'growthStage': stage.name,
        'feedingPercentage': stage.feedingPercentage,
        'tankVolumeLiters': tankVolumeLiters,
        'fishCount': fishCount,
        'averageWeightGrams': resolvedWeight,
        'feedingsPerDay': sessions,
        'totalBiomassKg': totalBiomassKg,
        'recommendedFishCountMin': recommendedMin,
        'recommendedFishCountMax': recommendedMax,
        'stockingStatus': stockingStatus,
      },
    );
  }

  GrowthStageProfile? _resolveGrowthStage(
    FishProfile fish,
    double? averageWeightGrams,
    String? selectedGrowthStageId,
  ) {
    if (averageWeightGrams != null && averageWeightGrams > 0) {
      for (final stage in fish.growthStages) {
        if (stage.containsWeight(averageWeightGrams)) {
          return stage;
        }
      }
      return fish.growthStages.last;
    }

    if (selectedGrowthStageId != null) {
      for (final stage in fish.growthStages) {
        if (stage.id == selectedGrowthStageId) return stage;
      }
    }

    return null;
  }
}
