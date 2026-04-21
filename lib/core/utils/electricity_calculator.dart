import 'dart:math';

class ElectricityCalculator {
  // Pricing tiers: [max_kwh, price_per_kwh]
  static const List<List<double>> _tiers = [
    [50, 0.41],
    [100, 0.71],
    [200, 1.01],
    [350, 1.61],
    [650, 1.85],
    [1000, 2.15],
    [double.infinity, 2.35],
  ];

  /// 1. Calculate cumulative cost across tiers
  static double calculateCost(double kwh) {
    if (kwh <= 0) return 0.0;
    
    double totalCost = 0.0;
    double remainingKwh = kwh;
    double lowerBound = 0.0;

    for (var tier in _tiers) {
      double upperBound = tier[0];
      double price = tier[1];
      
      double kwhInThisTier = min(remainingKwh, upperBound - lowerBound);
      if (kwhInThisTier <= 0) break;

      totalCost += kwhInThisTier * price;
      remainingKwh -= kwhInThisTier;
      lowerBound = upperBound;

      if (remainingKwh <= 0) break;
    }

    return double.parse(totalCost.toStringAsFixed(2));
  }

  /// 2. Predict end of month total cost
  static double predictMonthlyBill(double currentKwh, int currentDay) {
    if (currentDay <= 0) return 0.0;
    double predictedKwh = (currentKwh / currentDay) * 30;
    return calculateCost(predictedKwh);
  }

  /// 3. Get remaining budget in EGP
  static double getRemainingBudget(double budgetEGP, double spentEGP) {
    return max(0.0, budgetEGP - spentEGP);
  }

  /// 4. Get budget usage percentage (0.0 to 1.0)
  static double getBudgetPercentage(double budgetEGP, double spentEGP) {
    if (budgetEGP <= 0) return spentEGP > 0 ? 1.0 : 0.0;
    return (spentEGP / budgetEGP).clamp(0.0, 1.0);
  }

  /// 5. Get descriptive string for current usage tier
  static String getCurrentTier(double kwh) {
    if (kwh < 0) return "Unknown";
    
    int tierIndex = 1;
    for (var tier in _tiers) {
      if (kwh <= tier[0]) {
        return "Tier $tierIndex — ${tier[1]} EGP/kWh";
      }
      tierIndex++;
    }
    return "Tier 7 — 2.35 EGP/kWh";
  }

  /// 6. Reverse calculate max daily kWh for a given budget
  static double getRecommendedDailyKwh(double budgetEGP) {
    if (budgetEGP <= 0) return 0.0;

    // Binary search for total monthly kWh target
    double low = 0.0;
    double high = 10000.0; // Assume 10k kWh is a reasonable upper limit for residential
    double epsilon = 0.1;

    while (high - low > epsilon) {
      double mid = (low + high) / 2;
      if (calculateCost(mid) <= budgetEGP) {
        low = mid;
      } else {
        high = mid;
      }
    }

    return double.parse((low / 30).toStringAsFixed(2));
  }

  /// 7. Calculate daily cost for a single device
  static double getDeviceDailyCost(double wattage, double hoursPerDay) {
    double dailyKwh = (wattage * hoursPerDay) / 1000;
    // Note: Cost is calculated based on current tier usually, 
    // but here we calculate it as if it's the only usage (baseline)
    // or we could assume a standard rate. 
    // As per request, we convert and use calculateCost logic.
    return calculateCost(dailyKwh); 
  }
}
