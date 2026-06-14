// lib/features/dashboard/widgets/bill_prediction_card.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/electricity_calculator.dart';
import '../../../providers/consumption_provider.dart';
import '../../../core/widgets/modern_card.dart';

class BillPredictionCard extends ConsumerWidget {
  final double monthlyBudget;

  const BillPredictionCard({
    super.key,
    this.monthlyBudget = 500.0, // Default budget in EGP
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthlyKwhAsync = ref.watch(monthlyKwhProvider);

    return monthlyKwhAsync.when(
      data: (monthlyKwh) => _buildCard(monthlyKwh),
      loading: () => _buildCard(0.0, isLoading: true),
      error: (_, __) => _buildCard(0.0),
    );
  }

  Widget _buildCard(double currentKwh, {bool isLoading = false}) {
    final currentDay = DateTime.now().day;
    final currentCost = ElectricityCalculator.calculateCost(currentKwh);
    final predictedBill = ElectricityCalculator.predictMonthlyBill(currentKwh, currentDay);
    final budgetProgress = (currentCost / monthlyBudget).clamp(0.0, 1.0);
    final isOverBudget = currentCost > monthlyBudget;

    return ModernCard(
      borderRadius: 24,
      backgroundColor: isOverBudget 
          ? AppColors.cardColor 
          : AppColors.cardColor,
      border: isOverBudget
          ? Border.all(
              color: AppColors.errorRed.withOpacity(0.3),
              width: 2,
            )
          : null,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Monthly Bill Prediction',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isOverBudget ? 'Over Budget ⚠️' : 'On Track ✓',
                    style: TextStyle(
                      color: isOverBudget ? AppColors.errorRed : AppColors.successGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isOverBudget 
                      ? AppColors.errorRed.withOpacity(0.15)
                      : AppColors.primaryBlue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  color: isOverBudget ? AppColors.errorRed : AppColors.primaryBlue,
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Row(
                      children: [
                        _buildInfoItem('Current', '${currentCost.toStringAsFixed(1)} EGP', AppColors.accentOrange),
                        const SizedBox(width: 12),
                        _buildInfoItem('Predicted', '${predictedBill.toStringAsFixed(1)} EGP', AppColors.accentMagenta),
                        const SizedBox(width: 12),
                        _buildInfoItem('Usage', '${currentKwh.toStringAsFixed(1)} kWh', AppColors.primaryBlue),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Budget Progress',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${(budgetProgress * 100).toInt()}%',
                              style: TextStyle(
                                color: budgetProgress > 0.8 ? AppColors.errorRed : AppColors.accentTeal,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: LinearProgressIndicator(
                            value: budgetProgress,
                            minHeight: 10,
                            backgroundColor: Colors.white.withOpacity(0.08),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              budgetProgress > 0.8 
                                  ? AppColors.errorRed 
                                  : AppColors.accentTeal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, Color accentColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: accentColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: accentColor.withOpacity(0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: accentColor.withOpacity(0.8),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
