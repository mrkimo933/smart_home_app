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

  String _getDeviceNature(String deviceName) {
    final name = deviceName.toLowerCase();
    if (name.contains('fridge') || name.contains('refrigerator') || name.contains('ثلاجة')) {
      return 'Must run 24h/day, cannot be turned off';
    }
    if (name.contains('ac') || name.contains('air') || name.contains('تكييف')) {
      return 'Cooling device, best used at night (10pm-6am) to save cost';
    }
    if (name.contains('heater') || name.contains('سخان')) {
      return 'Use max 1-2 hours/day, prefer morning';
    }
    if (name.contains('wash') || name.contains('غسالة')) {
      return 'Use every 2-3 days, 1 hour per use, prefer off-peak';
    }
    if (name.contains('tv') || name.contains('تلفزيون')) {
      return 'Evening use 6pm-11pm, ~4 hours/day';
    }
    if (name.contains('lamp') || name.contains('light') || name.contains('نور') || name.contains('إضاءة')) {
      return 'Evening lighting, 6-8 hours/day';
    }
    if (name.contains('computer') || name.contains('laptop') || name.contains('كمبيوتر')) {
      return 'Work/study device, 4-8 hours/day';
    }
    return 'General device, estimate based on $deviceName wattage and typical usage';
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

    final deviceContext = devices.map((d) {
      final nature = _getDeviceNature(d.name);
      return '- ${d.name}: ${d.wattage}W | طبيعة الجهاز: $nature';
    }).join('\n');

    final userContent = '''
أنت مستشار طاقة ذكي متخصص في المنازل المصرية.

ميزانية المستخدم الشهرية: $budgetEGP جنيه
اليوم الحالي من الشهر: $currentDay
الاستهلاك الحالي هذا الشهر: ${currentKwh.toStringAsFixed(2)} كيلوواط/ساعة
التكلفة الحالية: ${currentCostEGP.toStringAsFixed(2)} جنيه

الأجهزة المتاحة:
$deviceContext

تعليمات مهمة جداً:
1. افهم طبيعة كل جهاز (الثلاجة تشتغل 24 ساعة، التكييف أفضل ليلاً، السخان ساعة يومياً)
2. الميزانية ($budgetEGP جنيه) هي الحد الأقصى للصرف - اعمل خططاً تستغل الميزانية بشكل ذكي
3. اعمل 3 خطط:
   - توفير أقصى: استخدام الضروريات فقط (50-70% من الميزانية)
   - توازن: راحة معقولة (75-90% من الميزانية)
   - راحة: استخدام مريح (90-100% من الميزانية)
4. احسب التكلفة باستخدام شرائح الكهرباء المصرية:
   0-50 كيلوواط = 0.41 جنيه/كيلوواط
   51-100 = 0.71 جنيه/كيلوواط
   101-200 = 1.01 جنيه/كيلوواط
   201-350 = 1.61 جنيه/كيلوواط
   351-650 = 1.85 جنيه/كيلوواط
   651-1000 = 2.15 جنيه/كيلوواط
   أكثر من 1000 = 2.35 جنيه/كيلوواط
5. لكل جهاز: حدد ساعات تشغيل يومية منطقية وأفضل وقت تشغيل
6. النصائح يجب أن تكون عملية ومحددة

أجب فقط بـ JSON array بالتنسيق التالي بالضبط، بدون أي نص إضافي أو markdown:
[
  {
    "name": "توفير أقصى",
    "emoji": "💰",
    "description": "وصف مختصر",
    "predictedMonthlyCost": 650.0,
    "savingsEGP": 350.0,
    "withinBudget": true,
    "tips": "نصيحة عملية",
    "devices": [
      {
        "deviceName": "اسم الجهاز",
        "hoursPerDay": 4.0,
        "bestTimeSlot": "10م - 2ص",
        "monthlyCost": 180.0
      }
    ]
  },
  {
    "name": "توازن",
    "emoji": "⚖️",
    "description": "...",
    "predictedMonthlyCost": 750.0,
    "savingsEGP": 250.0,
    "withinBudget": true,
    "tips": "...",
    "devices": []
  },
  {
    "name": "راحة",
    "emoji": "😊",
    "description": "...",
    "predictedMonthlyCost": 950.0,
    "savingsEGP": 50.0,
    "withinBudget": true,
    "tips": "...",
    "devices": []
  }
]
''';

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
