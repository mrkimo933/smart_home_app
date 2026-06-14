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

  // ── Egyptian electricity pricing tiers ──────────────────────────────────

  double _calculateMonthlyCost(double kwh) {
    double cost = 0;
    double remaining = kwh;

    const tiers = [
      (50.0, 0.41),
      (50.0, 0.71),
      (100.0, 1.01),
      (150.0, 1.61),
      (300.0, 1.85),
      (350.0, 2.15),
      (double.infinity, 2.35),
    ];

    for (final (limit, rate) in tiers) {
      final used = remaining <= limit ? remaining : limit;
      cost += used * rate;
      remaining -= used;
      if (remaining <= 0) break;
    }
    return cost;
  }

  double _costPerHour(Device device) {
    return (device.wattage / 1000) * 1.61;
  }




  // ── Device schedule constraints ──────────────────────────────────────────

  double _getMaxReasonableHours(String name) {
    final n = name.toLowerCase();
    if (n.contains('fridge') || n.contains('ثلاجة') || n.contains('refrigerator')) return 24;
    if (n.contains('ac') || n.contains('air') || n.contains('تكييف')) return 10;
    if (n.contains('heater') || n.contains('سخان')) return 1;
    if (n.contains('wash') || n.contains('غسالة')) return 1.5;
    if (n.contains('tv') || n.contains('تلفزيون')) return 6;
    if (n.contains('lamp') || n.contains('light') || n.contains('نور') || n.contains('إضاءة')) return 8;
    if (n.contains('computer') || n.contains('laptop') || n.contains('كمبيوتر')) return 8;
    if (n.contains('microwave') || n.contains('ميكرويف')) return 0.5;
    if (n.contains('iron') || n.contains('مكواة')) return 0.5;
    if (n.contains('coffee') || n.contains('قهوة')) return 0.5;
    return 6;
  }

  double _getMinRequiredHours(String name) {
    final n = name.toLowerCase();
    if (n.contains('fridge') || n.contains('ثلاجة') || n.contains('refrigerator')) return 24;
    if (n.contains('ac') || n.contains('air') || n.contains('تكييف')) return 4;
    if (n.contains('heater') || n.contains('سخان')) return 0.5;
    if (n.contains('wash') || n.contains('غسالة')) return 0.4;
    if (n.contains('tv') || n.contains('تلفزيون')) return 2;
    if (n.contains('lamp') || n.contains('نور') || n.contains('إضاءة')) return 4;
    return 1;
  }

  String _getDeviceNature(String deviceName) {
    final n = deviceName.toLowerCase();
    if (n.contains('fridge') || n.contains('refrigerator') || n.contains('ثلاجة')) {
      return 'تشتغل 24 ساعة دايماً — hoursPerDay يكون 24 دايماً';
    }
    if (n.contains('ac') || n.contains('air') || n.contains('تكييف')) {
      return 'تكييف — في الصيف المصري يحتاج 6-10 ساعات — أكفأ وقت الليل (10م-6ص)';
    }
    if (n.contains('heater') || n.contains('سخان')) {
      return 'سخان — يكفيه 45 دقيقة (0.75 ساعة) قبل الاستحمام مباشرة';
    }
    if (n.contains('wash') || n.contains('غسالة')) {
      return 'غسالة — 3-4 مرات أسبوعياً × 1.5 ساعة = معدل يومي 0.6 ساعة';
    }
    if (n.contains('tv') || n.contains('تلفزيون')) {
      return 'تلفزيون — 3-5 ساعات مساءً';
    }
    if (n.contains('lamp') || n.contains('نور') || n.contains('إضاءة')) {
      return 'إضاءة — 5-8 ساعات مساءً من 6م لـ 12م';
    }
    if (n.contains('computer') || n.contains('laptop') || n.contains('كمبيوتر')) {
      return 'كمبيوتر — 4-8 ساعات للعمل أو الدراسة';
    }
    if (n.contains('microwave') || n.contains('ميكرويف')) {
      return 'ميكرويف — استخدامات قصيرة 15-20 دقيقة يومياً';
    }
    if (n.contains('coffee') || n.contains('قهوة')) {
      return 'ماكينة قهوة — 15-30 دقيقة صباحاً';
    }
    if (n.contains('iron') || n.contains('مكواة')) {
      return 'مكواة — مرة أو مرتين أسبوعياً 30 دقيقة';
    }
    return 'جهاز عام — قدّر ساعات منطقية بناءً على الواتية';
  }

  String _buildDeviceContext(List<Device> devices) {
    final sb = StringBuffer();
    for (final d in devices) {
      final costPerHour = _costPerHour(d);
      final nature = _getDeviceNature(d.name);
      final maxH = _getMaxReasonableHours(d.name);
      final minH = _getMinRequiredHours(d.name);
      sb.writeln(
        '- ${d.name} | ${d.wattage}W | '
        'تكلفة الساعة الواحدة: ${costPerHour.toStringAsFixed(2)} جنيه | '
        'أقل ساعات: $minH س/يوم | '
        'أقصى ساعات معقولة: $maxH س/يوم | '
        'طبيعة: $nature',
      );
    }
    return sb.toString();
  }

  // ── Public entry point ───────────────────────────────────────────────────

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

    final deviceContext = _buildDeviceContext(devices);

    // Pre-calculate baseline cost (minimum usage scenario)
    double baselineKwh = 0;
    for (final d in devices) {
      baselineKwh += (d.wattage / 1000) * _getMinRequiredHours(d.name) * 30;
    }
    final baselineCost = _calculateMonthlyCost(baselineKwh);

    final userContent = '''
أنت مخطط جداول كهرباء للمنازل المصرية. مهمتك فقط: قرر كل جهاز يشتغل كام ساعة في اليوم وامتى.

⚠️ مهم جداً: أنت لا تحسب التكاليف — التكاليف محسوبة ليك بالفعل. فقط اقرر الجداول.

معلومات المنزل:
- الميزانية الشهرية: $budgetEGP جنيه
- اليوم الحالي: $currentDay من الشهر
- الاستهلاك الحالي: ${currentKwh.toStringAsFixed(2)} كيلوواط/ساعة
- المصروف حتى الآن: ${currentCostEGP.toStringAsFixed(2)} جنيه
- الحد الأدنى لتكلفة كل الأجهزة (بأقل استخدام): ${baselineCost.toStringAsFixed(0)} جنيه/شهر

الأجهزة مع تكلفة كل ساعة تشغيل:
$deviceContext
مهمتك: اعمل 3 خطط — نفس الميزانية ($budgetEGP جنيه) في كل خطة، بس أسلوب تشغيل مختلف:

خطة 1 - "جدول الليل" 🌙
  الأجهزة الثقيلة تشتغل بالليل (10م-6ص)
  فكرة: استغل برودة الليل للتكييف، اعمل الغسيل بالليل

خطة 2 - "جدول الصبح" ☀️
  الأجهزة الثقيلة تشتغل الصبح (6ص-2م)
  فكرة: خلّص كل حاجة قبل السخونة، ارتاح بالليل

خطة 3 - "جدول حر" 🕐
  كل جهاز له حد أقصى من الساعات اليومية يضمن الميزانية
  فكرة: استخدم وقت ما تحب بس في الحدود المكتوبة

قواعد اختيار الساعات:
1. الثلاجة دايماً 24 ساعة — ثابتة في كل خطة
2. كل جهاز له "أقل ساعات" و"أقصى ساعات معقولة" مكتوبين فوق — اختر بينهم
3. بعد ما تحدد الساعات، اضرب: (الواتية/1000) × الساعات × 30 = kWh الجهاز
4. اجمع كل الـ kWh وتأكد إن التكلفة الإجمالية قريبة من $budgetEGP جنيه
5. لو التكلفة أقل من ${(budgetEGP * 0.88).toStringAsFixed(0)} جنيه → زيد ساعات الأجهزة غير الأساسية
6. لو التكلفة أكبر من $budgetEGP جنيه → قلل ساعات الأجهزة غير الأساسية

للتذكير: تكلفة kWh حسب الشرائح:
0-50 kWh = 0.41 جنيه/kWh | 51-100 = 0.71 | 101-200 = 1.01 | 201-350 = 1.61 | 351-650 = 1.85 | 651-1000 = 2.15 | +1000 = 2.35

أجب فقط بـ JSON array، بدون أي كلام تاني:
[
  {
    "name": "جدول الليل",
    "emoji": "🌙",
    "description": "جملة وصف قصيرة لأسلوب الخطة",
    "predictedMonthlyCost": 950.0,
    "savingsEGP": 50.0,
    "withinBudget": true,
    "tips": "نصيحة عملية ومحددة",
    "devices": [
      {
        "deviceName": "اسم الجهاز كما هو مكتوب بالضبط فوق",
        "hoursPerDay": 8.0,
        "bestTimeSlot": "10م - 6ص",
        "monthlyCost": 320.0
      }
    ]
  }
]
''';

    final rawScenarios = await _callApi(apiKey, userContent);

    // Flutter recalculates real costs from AI's hours + real wattage
    return rawScenarios.map((scenario) {
      double totalKwh = 0;

      // First pass: compute each device's kWh from real wattage
      final deviceKwhMap = <int, double>{};
      for (int i = 0; i < scenario.devices.length; i++) {
        final sd = scenario.devices[i];
        final realDevice = devices.firstWhere(
          (d) => d.name == sd.deviceName,
          orElse: () => devices.first,
        );
        final monthlyKwh = (realDevice.wattage / 1000) * sd.hoursPerDay * 30;
        deviceKwhMap[i] = monthlyKwh;
        totalKwh += monthlyKwh;
      }

      final totalCost = _calculateMonthlyCost(totalKwh);

      // Second pass: assign per-device cost proportionally
      final correctedDevices = <ScenarioDevice>[];
      for (int i = 0; i < scenario.devices.length; i++) {
        final sd = scenario.devices[i];
        final deviceKwh = deviceKwhMap[i] ?? 0.0;
        final deviceCost =
            totalKwh > 0 ? (deviceKwh / totalKwh) * totalCost : 0.0;
        correctedDevices.add(ScenarioDevice(
          deviceName: sd.deviceName,
          hoursPerDay: sd.hoursPerDay,
          bestTimeSlot: sd.bestTimeSlot,
          monthlyCost: deviceCost,
        ));
      }

      return scenario.copyWith(
        predictedMonthlyCost: totalCost,
        savingsEGP: budgetEGP - totalCost,
        withinBudget: totalCost <= budgetEGP,
        devices: correctedDevices,
      );
    }).toList();
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
                  'أنت مساعد ذكي متخصص في جدولة استهلاك الكهرباء في مصر. مهمتك فقط هي تحديد ساعات تشغيل الأجهزة — لا تحسب التكاليف بنفسك. دائماً ترد بـ JSON فقط بدون أي نص إضافي.',
            },
            {
              'role': 'user',
              'content': userContent,
            },
          ],
          'temperature': 0.4,
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

      final cleaned = content
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();

      try {
        final list = jsonDecode(cleaned) as List<dynamic>;
        return list
            .map((e) => EnergyScenario.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        if (retryCount < 1) {
          return await _callApi(apiKey, userContent, retryCount: retryCount + 1);
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
