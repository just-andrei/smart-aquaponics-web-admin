import 'compatibility_models.dart';

const plantProfiles = <String, PlantProfile>{
  'lettuce': PlantProfile(
    id: 'lettuce',
    name: 'Lettuce',
    phRange: NumericRange(min: 5.8, max: 6.8),
    temperatureRange: NumericRange(min: 16.0, max: 24.0),
    heatTolerance: 'low',
    notes: 'Cooler leafy crop that struggles in sustained warm-water systems.',
  ),
  'kangkong': PlantProfile(
    id: 'kangkong',
    name: 'Kangkong',
    phRange: NumericRange(min: 5.5, max: 7.5),
    temperatureRange: NumericRange(min: 24.0, max: 32.0),
    heatTolerance: 'high',
    notes: 'Heat-tolerant leafy crop that fits tropical aquaponics setups well.',
  ),
  'basil': PlantProfile(
    id: 'basil',
    name: 'Basil',
    phRange: NumericRange(min: 5.8, max: 7.0),
    temperatureRange: NumericRange(min: 20.0, max: 30.0),
    heatTolerance: 'medium',
    notes: 'Flexible herb that handles warmer systems better than lettuce.',
  ),
};
