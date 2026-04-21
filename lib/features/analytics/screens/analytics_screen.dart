import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/consumption_provider.dart';
import '../../../providers/devices_provider.dart';
import '../widgets/consumption_chart.dart';
import '../widgets/device_pie_chart.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) return;
    
    final now = DateTime.now();
    DateTime from;
    DateTime to = now;

    switch (_tabController.index) {
      case 0: // Daily
        from = DateTime(now.year, now.month, now.day);
        break;
      case 1: // Weekly
        from = now.subtract(const Duration(days: 7));
        break;
      case 2: // Monthly
        from = DateTime(now.year, now.month, 1);
        break;
      default:
        from = now.subtract(const Duration(days: 1));
    }

    ref.read(consumptionHistoryProvider.notifier).setFilter(from, to);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(consumptionHistoryProvider);
    final totalKwhAsync = ref.watch(monthlyKwhProvider);
    final totalCostAsync = ref.watch(monthlyCostProvider);
    final devices = ref.watch(devicesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('الإحصائيات', style: TextStyle(color: AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryBlue,
          labelColor: AppColors.primaryBlue,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: 'يومي'),
            Tab(text: 'أسبوعي'),
            Tab(text: 'شهري'),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'استهلاك الطاقة',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 16),
            Card(
              color: AppColors.cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: historyAsync.when(
                  data: (history) => ConsumptionChart(
                    data: history,
                    isDaily: _tabController.index == 0,
                  ),
                  loading: () => const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Center(child: Text('خطأ: $e')),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    title: 'التكلفة (ج.م)',
                    value: totalCostAsync.maybeWhen(
                      data: (v) => v.toStringAsFixed(2),
                      orElse: () => '...',
                    ),
                    icon: Icons.account_balance_wallet,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    title: 'إجمالي (kWh)',
                    value: totalKwhAsync.maybeWhen(
                      data: (v) => v.toStringAsFixed(1),
                      orElse: () => '...',
                    ),
                    icon: Icons.bolt,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SummaryCard(
              title: 'المعدل اليومي',
              value: totalKwhAsync.maybeWhen(
                data: (v) => (v / DateTime.now().day).toStringAsFixed(1),
                orElse: () => '...',
              ),
              icon: Icons.trending_up,
              isWide: true,
            ),
            const SizedBox(height: 32),
            const Text(
              'توزيع استهلاك الأجهزة',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 16),
            Card(
              color: AppColors.cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: DevicePieChart(devices: devices),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final bool isWide;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    this.isWide = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: isWide ? MainAxisAlignment.spaceBetween : MainAxisAlignment.start,
          children: [
            if (isWide) ...[
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.primaryBlue,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(icon, color: AppColors.primaryBlue, size: 16),
                  ],
                ),
                if (!isWide) ...[
                  const SizedBox(height: 8),
                  Text(
                    value,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
