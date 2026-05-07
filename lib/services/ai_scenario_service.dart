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
      return 'تشتغل 24 ساعة دايماً - ما تتوقفش أبداً - hoursPerDay يكون 24';
    }
    if (name.contains('ac') || name.contains('air') || name.contains('condition') || name.contains('تكييف')) {
      return 'تكييف - يحتاج 6-10 ساعات يومياً في الصيف المصري - مش ساعة واحدة - أكفأ وقت الليل';
    }
    if (name.contains('heater') || name.contains('سخان') || name.contains('water heater')) {
      return 'سخان مياه - يكفيه 45 دقيقة (0.75 ساعة) يومياً قبل الاستحمام - مش ساعتين';
    }
    if (name.contains('wash') || name.contains('غسالة')) {
      return 'غسالة - 3-4 مرات أسبوعياً، كل مرة 1.5 ساعة، معدل يومي = 0.64 ساعة';
    }
    if (name.contains('tv') || name.contains('تلفزيون') || name.contains('شاشة')) {
      return 'تلفزيون - 3-5 ساعات يومياً مساءً';
    }
    if (name.contains('lamp') || name.contains('light') || name.contains('نور') || name.contains('إضاءة') || name.contains('لمبة')) {
      return 'إضاءة - 5-8 ساعات يومياً من 6م لحد 12م';
    }
    if (name.contains('computer') || name.contains('laptop') || name.contains('كمبيوتر') || name.contains('لابتوب')) {
      return 'كمبيوتر أو لابتوب - 4-8 ساعات يومياً';
    }
    if (name.contains('microwave') || name.contains('ميكرويف')) {
      return 'ميكرويف - استخدام قصير 15-20 دقيقة يومياً';
    }
    if (name.contains('iron') || name.contains('مكواة')) {
      return 'مكواة - مرة أو مرتين أسبوعياً، 30-45 دقيقة';
    }
    return 'جهاز عام - قدّر ساعات الاستخدام بناءً على الواتية المذكورة';
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
      return '- ${d.name} | ${d.wattage}W | أولوية: ${d.priority.name} | طبيعة: $nature';
    }).join('\n');

    final userContent = '''
أنت مستشار طاقة خبير للمنازل المصرية. فكّر كأنك إنسان بيخطط ميزانية كهرباء شهرية لأسرة مصرية.

معلومات المستخدم:
- الميزانية الشهرية: $budgetEGP جنيه
- اليوم الحالي من الشهر: $currentDay
- الاستهلاك الحالي هذا الشهر: ${currentKwh.toStringAsFixed(2)} كيلوواط/ساعة
- التكلفة المصروفة حتى الآن: ${currentCostEGP.toStringAsFixed(2)} جنيه

الأجهزة الموجودة في البيت:
$deviceContext

مهمتك: اعمل 3 خطط تشغيل مختلفة.

⚠️ قاعدة أساسية لا تنكسر: كل خطة لازم تكلف بين 90% و100% من الميزانية ($budgetEGP جنيه).
الفرق بين الخطط هو أسلوب التشغيل (إمتى وإزاي) — مش السعر.

الخطة 1 - "جدول الليل" 🌙
  شغّل الأجهزة الثقيلة بالليل (تكييف من 10م لـ6ص، غسالة 11م، سخان 5:30ص).
  استغل الجو البارد بالليل لتشغيل أكفأ.

الخطة 2 - "جدول الصبح" ☀️
  خلّص الأعمال الثقيلة الصبح بدري (تكييف من 6ص لـ2م، غسالة 9ص، سخان 6ص).
  ارتاح بالليل.

الخطة 3 - "جدول حر" 🕐
  استخدم الأجهزة وقت ما تحب، بس احسب أقصى ساعات ممكنة لكل جهاز عشان ميتعداش الميزانية.

قواعد الحساب:
1. الثلاجة دايماً 24 ساعة في اليوم — لا تتغير أبداً
2. التكييف في الصيف المصري يحتاج 6-10 ساعات يومياً — مش ساعة
3. السخان يكفيه 45 دقيقة (0.75 ساعة) يومياً — مش ساعتين
4. الغسالة 3-4 مرات أسبوعياً × 1.5 ساعة = معدل 0.64 ساعة يومياً
5. لو التكلفة الحسابية أقل من 90% من الميزانية، زيد ساعات الأجهزة غير الأساسية لحد ما تكمل
6. احسب التكلفة بشرائح الكهرباء المصرية:
   0-50 كيلوواط = 0.41 جنيه/كيلوواط
   51-100 = 0.71
   101-200 = 1.01
   201-350 = 1.61
   351-650 = 1.85
   651-1000 = 2.15
   أكثر من 1000 = 2.35
7. لكل جهاز اكتب وقت تشغيل محدد (مثال: "10م - 6ص" مش بس "ليلاً")

أجب فقط بـ JSON array بالتنسيق ده، بدون أي كلام تاني:
[
  {
    "name": "جدول الليل",
    "emoji": "🌙",
    "description": "وصف أسلوب الخطة وليه هي مناسبة",
    "predictedMonthlyCost": 960.0,
    "savingsEGP": 40.0,
    "withinBudget": true,
    "tips": "نصيحة عملية ومحددة",
    "devices": [
      {
        "deviceName": "اسم الجهاز زي ما هو مكتوب فوق",
        "hoursPerDay": 8.0,
        "bestTimeSlot": "10م - 6ص",
        "monthlyCost": 320.0
      }
    ]
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
