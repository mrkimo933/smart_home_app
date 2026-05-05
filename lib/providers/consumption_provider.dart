import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/consumption_record.dart';
import '../services/database_service.dart';
import 'devices_provider.dart';
import '../services/notification_service.dart';

// Monthly kWh Provider
final monthlyKwhProvider = FutureProvider<double>((ref) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getTotalKwhThisMonth();
});

// Monthly Cost Provider
final monthlyCostProvider = FutureProvider<double>((ref) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getTotalCostThisMonth();
});

// Budget alert at 50%, 75%, 90%, 100%
final houseBudgetAlertProvider = Provider<void>((ref) {
  final notificationService = NotificationService();
  ref.listen<AsyncValue<double>>(monthlyCostProvider, (prev, next) {
    next.whenData((cost) {
      final budget = ref.read(budgetProvider);
      if (budget <= 0) return;
      final ratio = cost / budget;
      if (ratio >= 1.0) {
        notificationService.sendHouseBudgetAlert(100, cost, budget);
      } else if (ratio >= 0.9) {
        notificationService.sendHouseBudgetAlert(90, cost, budget);
      } else if (ratio >= 0.75) {
        notificationService.sendHouseBudgetAlert(75, cost, budget);
      } else if (ratio >= 0.5) {
        notificationService.sendHouseBudgetAlert(50, cost, budget);
      }
    });
  });
  return;
});

// Consumption History Notifier
class ConsumptionHistoryNotifier
    extends StateNotifier<AsyncValue<List<ConsumptionRecord>>> {
  final DatabaseService _dbService;
  DateTime _from;
  DateTime _to;

  ConsumptionHistoryNotifier(this._dbService)
      : _from = DateTime.now().subtract(const Duration(days: 7)),
        _to = DateTime.now(),
        super(const AsyncLoading()) {
    loadHistory();
  }

  Future<void> loadHistory() async {
    state = const AsyncLoading();
    try {
      final records = await _dbService.getConsumptionByRange(_from, _to);
      state = AsyncData(records);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  void setFilter(DateTime from, DateTime to) {
    _from = from;
    _to = to;
    loadHistory();
  }
}

final consumptionHistoryProvider = StateNotifierProvider<
    ConsumptionHistoryNotifier, AsyncValue<List<ConsumptionRecord>>>((ref) {
  return ConsumptionHistoryNotifier(ref.watch(databaseServiceProvider));
});

// Legacy budget provider (kept for backward compatibility with energy_saving_screen)
class BudgetNotifier extends StateNotifier<double> {
  static const _key = 'house_budget';

  BudgetNotifier() : super(500.0) {
    _loadBudget();
  }

  Future<void> _loadBudget() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getDouble(_key) ?? 500.0;
  }

  Future<void> setBudget(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_key, value);
    state = value;
  }
}

final budgetProvider = StateNotifierProvider<BudgetNotifier, double>((ref) {
  return BudgetNotifier();
});
