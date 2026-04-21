import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/consumption_provider.dart';

class BudgetInputCard extends ConsumerStatefulWidget {
  const BudgetInputCard({super.key});

  @override
  ConsumerState<BudgetInputCard> createState() => _BudgetInputCardState();
}

class _BudgetInputCardState extends ConsumerState<BudgetInputCard> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final budget = ref.watch(budgetProvider);
    final spentAsync = ref.watch(monthlyCostProvider);

    return Card(
      color: AppColors.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'ميزانية الكهرباء الشهرية',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () {
                    final value = double.tryParse(_controller.text);
                    if (value != null && value > 0) {
                      ref.read(budgetProvider.notifier).setBudget(value);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم تحديث الميزانية بنجاح')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('حفظ'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: budget.toStringAsFixed(0),
                      hintStyle: const TextStyle(color: AppColors.textSecondary),
                      enabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.cardColor),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.primaryBlue),
                      ),
                      fillColor: AppColors.background,
                      filled: true,
                      suffixText: 'ج.م',
                      suffixStyle: const TextStyle(color: AppColors.textSecondary),
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            spentAsync.when(
              data: (spent) {
                final percent = (spent / budget).clamp(0.0, 1.0);
                Color progressColor = AppColors.accentGreen;
                if (percent > 0.9) {
                  progressColor = AppColors.errorRed;
                } else if (percent > 0.7) {
                  progressColor = Colors.orange;
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    LinearProgressIndicator(
                      value: percent,
                      backgroundColor: AppColors.background,
                      color: progressColor,
                      minHeight: 12,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'لقد استهلكت ${spent.toStringAsFixed(2)} ج.م من أصل ${budget.toStringAsFixed(0)} ج.م هذا الشهر',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ],
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('خطأ: $e'),
            ),
          ],
        ),
      ),
    );
  }
}
