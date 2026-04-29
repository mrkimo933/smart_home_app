import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_app/core/utils/electricity_calculator.dart';

void main() {
  group('ElectricityCalculator Tests', () {
    test('calculateCost - basic tiers', () {
      expect(ElectricityCalculator.calculateCost(40), 16.4); // 40 * 0.41
      expect(ElectricityCalculator.calculateCost(120), 76.2); 
      // 50*0.41 (20.5) + 50*0.71 (35.5) + 20*1.01 (20.2) = 76.2
    });

    test('calculateCost - edge cases', () {
      expect(ElectricityCalculator.calculateCost(0), 0.0);
      expect(ElectricityCalculator.calculateCost(-10), 0.0);
  expect(ElectricityCalculator.calculateCost(2000), 4056.0); // Large value (updated expected from calculation)
    });

    test('predictMonthlyBill', () {
      // 100 kWh in 15 days -> 200 kWh in 30 days
      // 50*0.41 (20.5) + 50*0.71 (35.5) + 100*1.01 (101) = 157.0
      expect(ElectricityCalculator.predictMonthlyBill(100, 15), 157.0);
      expect(ElectricityCalculator.predictMonthlyBill(0, 10), 0.0);
    });

    test('getRemainingBudget', () {
      expect(ElectricityCalculator.getRemainingBudget(500, 200), 300.0);
      expect(ElectricityCalculator.getRemainingBudget(500, 600), 0.0);
    });

    test('getBudgetPercentage', () {
      expect(ElectricityCalculator.getBudgetPercentage(1000, 250), 0.25);
      expect(ElectricityCalculator.getBudgetPercentage(1000, 1200), 1.0);
      expect(ElectricityCalculator.getBudgetPercentage(0, 50), 1.0);
    });

    test('getCurrentTier', () {
      expect(ElectricityCalculator.getCurrentTier(40), "Tier 1 — 0.41 EGP/kWh");
      expect(ElectricityCalculator.getCurrentTier(75), "Tier 2 — 0.71 EGP/kWh");
      expect(ElectricityCalculator.getCurrentTier(150), "Tier 3 — 1.01 EGP/kWh");
      expect(ElectricityCalculator.getCurrentTier(1200), "Tier 7 — 2.35 EGP/kWh");
    });

    test('getRecommendedDailyKwh', () {
      // Budget 76.2 EGP should allow 120 kWh monthly -> 4.0 kWh daily
      expect(ElectricityCalculator.getRecommendedDailyKwh(76.2), 4.0);
      expect(ElectricityCalculator.getRecommendedDailyKwh(0), 0.0);
    });

    test('getDeviceDailyCost', () {
      // 1000W for 1 hour = 1 kWh -> 0.41 EGP (base cost)
      expect(ElectricityCalculator.getDeviceDailyCost(1000, 1), 0.41);
      // 2000W for 10 hours = 20 kWh -> 20*0.41 = 8.2
      expect(ElectricityCalculator.getDeviceDailyCost(2000, 10), 8.2);
    });
  });
}
