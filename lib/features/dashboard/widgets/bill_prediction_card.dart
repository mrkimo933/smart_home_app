// lib/features/dashboard/widgets/bill_prediction_card.dart

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/electricity_calculator.dart';

class BillPredictionCard extends StatelessWidget {
  final double currentKwh;
  final double monthlyBudget;

  const BillPredictionCard({
    super.key,
    required this.currentKwh,
    this.monthlyBudget = 500.0, // Default budget in EGP
  });

  @override
  Widget build(BuildContext context) {
    final currentDay = DateTime.now().day;
    final currentCost = ElectricityCalculator.calculateCost(currentKwh);
    final predictedBill = ElectricityCalculator.predictMonthlyBill(currentKwh, currentDay);
    final budgetProgress = (currentCost / monthlyBudget).clamp(0.0, 1.0);
    final isOverBudget = currentCost > monthlyBudget;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isOverBudget ? AppColors.errorRed.withAlpha((0.3 * 255).toInt()) : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Monthly Bill Prediction',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(
                Icons.account_balance_wallet_rounded,
                color: isOverBudget ? AppColors.errorRed : AppColors.primaryBlue,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildInfoItem('Current', '${currentCost.toStringAsFixed(1)} EGP'),
              _buildDivider(),
              _buildInfoItem('Predicted', '${predictedBill.toStringAsFixed(1)} EGP'),
              _buildDivider(),
              _buildInfoItem('Usage', '${currentKwh.toStringAsFixed(1)} kWh'),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: budgetProgress,
              minHeight: 8,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(
                budgetProgress > 0.8 ? AppColors.errorRed : AppColors.accentGreen,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Budget: ${monthlyBudget.toInt()} EGP',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              Text(
                '${(budgetProgress * 100).toInt()}% Used',
                style: TextStyle(
                  color: budgetProgress > 0.8 ? AppColors.errorRed : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 30,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: Colors.white10,
    );
  }
}
