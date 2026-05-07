import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/device.dart';
import '../models/energy_scenario.dart';

class AiScenarioService {
  static const String _apiKeyPref = 'groq_api_key';
  static const String _apiUrl =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'llama-3.3-70b-versatile';

  Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyPref);
  }

  Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyPref, key);
  }

  Future<bool> testApiKey(String key) async {
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Authorization': 'Bearer $key',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {'role': 'user', 'content': 'Say OK'}
          ],
          'max_tokens': 5,
        }),
      ).timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<List<EnergyScenario>> generateScenarios({
    required double budgetEGP,
    required int currentDay,
    required double currentKwh,
    required double currentCostEGP,
    required List<Device> devices,
  }) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('NO_API_KEY');
    }

    final deviceList = devices
        .map((d) => '- ${d.name}: ${d.wattage}W, أولوية: ${d.priority.name}')
        .join('\n');

    final userContent = '''المستخدم لديه ميزانية شهرية: $budgetEGP جنيه مصري

اليوم: $currentDay من الشهر
الاستهلاك حتى الآن: ${currentKwh.toStringAsFixed(2)} كيلوواط/ساعة
التكلفة حتى الآن: ${currentCostEGP.toStringAsFixed(2)} جنيه

أجهزته:
$deviceList

شرائح أسعار الكهرباء المصرية 2024:
- 0 إلى 50 كيلوواط = 0.41 جنيه/كيلوواط
- 51 إلى 100 كيلوواط = 0.71 جنيه/كيلوواط
- 101 إلى 200 كيلوواط = 1.01 جنيه/كيلوواط
- 201 إلى 350 كيلوواط = 1.61 جنيه/كيلوواط
- 351 إلى 650 كيلوواط = 1.85 جنيه/كيلوواط
- 651 إلى 1000 كيلوواط = 2.15 جنيه/كيلوواط
- أكثر من 1000 كيلوواط = 2.35 جنيه/كيلوواط

بناءً على هذه البيانات الحقيقية، اقترح 3 خطط:
1. توفير أقصى - أقل تكلفة ممكنة
2. توازن - راحة مع توفير
3. راحة - أقصى راحة في حدود الميزانية

أعد JSON فقط بهذا الشكل بالضبط:
[
  {
    "name": "توفير أقصى",
    "emoji": "💰",
    "description": "وصف مختصر للخطة",
    "predictedMonthlyCost": 450.0,
    "savingsEGP": 150.0,
    "withinBudget": true,
    "devices": [
      {
        "deviceName": "AC",
        "hoursPerDay": 4.0,
        "bestTimeSlot": "10م - 2ص",
        "monthlyCost": 280.0
      }
    ],
    "tips": "نصيحة مختصرة للمستخدم"
  },
  {
    "name": "توازن",
    "emoji": "⚖️",
    "description": "...",
    "predictedMonthlyCost": 500.0,
    "savingsEGP": 100.0,
    "withinBudget": true,
    "devices": [],
    "tips": "..."
  },
  {
    "name": "راحة",
    "emoji": "😊",
    "description": "...",
    "predictedMonthlyCost": 600.0,
    "savingsEGP": 0.0,
    "withinBudget": false,
    "devices": [],
    "tips": "..."
  }
]''';

    return await _callApi(apiKey, userContent);
  }

  Future<List<EnergyScenario>> _callApi(
    String apiKey,
    String userContent, {
    int retryCount = 0,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {
              'role': 'system',
              'content':
                  'أنت مساعد ذكي متخصص في ترشيد استهلاك الكهرباء في مصر. تعرف جيداً شرائح أسعار الكهرباء المصرية وعادات المستهلك المصري. دائماً ترد بـ JSON فقط بدون أي نص إضافي.',
            },
            {
              'role': 'user',
              'content': userContent,
            },
          ],
          'temperature': 0.7,
          'max_tokens': 2000,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('API_ERROR_${response.statusCode}');
      }

      final responseJson =
          jsonDecode(response.body) as Map<String, dynamic>;
      final content = (responseJson['choices'] as List)
          .first['message']['content'] as String;

      // Clean response — remove possible markdown code fences
      final cleaned = content
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();

      try {
        final list = jsonDecode(cleaned) as List<dynamic>;
        return list
            .map((e) =>
                EnergyScenario.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        // Invalid JSON — retry once
        if (retryCount < 1) {
          return await _callApi(apiKey, userContent,
              retryCount: retryCount + 1);
        }
        throw Exception('INVALID_JSON');
      }
    } on Exception {
      rethrow;
    } catch (_) {
      throw Exception('NO_INTERNET');
    }
  }
}

final aiScenarioService = AiScenarioService();
